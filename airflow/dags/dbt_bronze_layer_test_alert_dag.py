from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from utils.logging_utils import DataOpsLogger
from utils.alerting import AlertManager

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

dag = DAG(
    "dbt_bronze_test_alert_layer",
    default_args=default_args,
    description="Run dbt bronze layer models",
    schedule_interval=timedelta(minutes=30),
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "bronze", "sqlserver"],
)


def log_pipeline_start(**context):
    """Log the start of the pipeline"""
    logger = DataOpsLogger("dbt_bronze_pipeline", "pipeline_start")
    logger.log_event("pipeline_start", "Starting DBT bronze layer execution")
    return {"start_time": datetime.now().isoformat()}


def log_pipeline_complete(**context):
    """Log the completion of the pipeline"""
    logger = DataOpsLogger("dbt_bronze_pipeline", "pipeline_complete")
    ti = context["ti"]
    start_data = ti.xcom_pull(task_ids="log_start")

    if start_data:
        start_time = datetime.fromisoformat(start_data["start_time"])
        execution_time = (datetime.now() - start_time).total_seconds()
        logger.log_metric("execution_time_seconds", execution_time, "seconds")
        logger.log_event("pipeline_complete", f"Completed in {execution_time:.2f}s")
    else:
        logger.log_event("pipeline_complete", "Pipeline completed successfully")


def test_alert_failure(**context):
    """Intentionally fail to test alert system - REMOVE AFTER TESTING"""
    alert_manager = AlertManager()
    alert_manager.alert_pipeline_failure(
        dag_id="dbt_bronze_layer",
        task_id="test_alert_failure",
        error_message="This is a test failure to verify alert system is working",
    )
    raise Exception("TEST FAILURE: This task intentionally fails to test alerts")


# Log pipeline start
log_start = PythonOperator(
    task_id="log_start",
    python_callable=log_pipeline_start,
    dag=dag,
)

# Run bronze models only
dbt_run_bronze = BashOperator(
    task_id="dbt_run_bronze",
    bash_command="docker exec dbt_airflow_project-dbt-1 dbt run --select bronze",
    dag=dag,
)

# Test bronze models
dbt_test_bronze = BashOperator(
    task_id="dbt_test_bronze",
    bash_command="docker exec dbt_airflow_project-dbt-1 dbt test --select bronze",
    dag=dag,
)

# Log pipeline completion
log_complete = PythonOperator(
    task_id="log_complete",
    python_callable=log_pipeline_complete,
    dag=dag,
)

test_failure = PythonOperator(
    task_id="test_alert_failure",
    python_callable=test_alert_failure,
    retries=0,  # No retries for test task
    dag=dag,
)

# Set task dependencies
# Test failure runs independently so it doesn't block the pipeline
log_start >> [test_failure, dbt_run_bronze]
dbt_run_bronze >> dbt_test_bronze >> log_complete
