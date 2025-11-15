"""Airflow DAG to build only the silver (cleansed) layer dbt models.

Assumes bronze views already exist. Trigger `dbt_bronze` first if not.
Manual trigger only; adjust schedule_interval if you want automation.
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
    dag_id="dbt_silver",
    default_args=DEFAULT_ARGS,
    description="Build silver layer dbt models",
    schedule_interval=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "silver"],
)

# Only silver layer. If upstream bronze not present, this may fail; alternatively use +path:models/silver to include parents.
dbt_run_silver = BashOperator(
    task_id="dbt_run_silver",
    bash_command="docker exec dbt_airflow_project-dbt-1 dbt run --select path:models/silver",
    dag=dag,
)

dbt_test_silver = BashOperator(
    task_id="dbt_test_silver",
    bash_command="docker exec dbt_airflow_project-dbt-1 dbt test --select path:models/silver",
    dag=dag,
)

dbt_run_silver >> dbt_test_silver
