"""Airflow DAG to build only the bronze (raw) layer dbt models.

This pipeline limits dbt run/test to models located under `models/bronze`.
Trigger manually from the Airflow UI or CLI:
    airflow dags trigger dbt_bronze

If you need upstream sources refreshed first, ensure your source data is loaded
before triggering this DAG.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

DEFAULT_ARGS = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

dag = DAG(
    dag_id="dbt_bronze",
    default_args=DEFAULT_ARGS,
    description="Build bronze layer dbt models",
    schedule_interval=None,  # manual trigger only
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "bronze"],
)

# Run only bronze layer models (folder selection). We run inside the Airflow container.
dbt_run_bronze = BashOperator(
    task_id="dbt_run_bronze",
    bash_command="docker exec dbt_airflow_project-dbt-1 dbt run --select path:models/bronze",
    dag=dag,
)

dbt_test_bronze = BashOperator(
    task_id="dbt_test_bronze",
    bash_command="docker exec dbt_airflow_project-dbt-1 dbt test --select path:models/bronze",
    dag=dag,
)

dbt_run_bronze >> dbt_test_bronze
