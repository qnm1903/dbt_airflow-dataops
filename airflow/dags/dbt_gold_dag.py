"""Airflow DAG to build only the gold (analytics) layer dbt models.

Assumes silver layer tables (and implicitly bronze views) already exist.
Trigger ordering recommendation:
    1. dbt_bronze
    2. dbt_silver
    3. dbt_gold
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
    dag_id="dbt_gold",
    default_args=DEFAULT_ARGS,
    description="Build gold layer dbt models",
    schedule_interval=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "gold"],
)

dbt_run_gold = BashOperator(
    task_id="dbt_run_gold",
    bash_command="docker exec dbt_airflow_project-dbt-1 dbt run --select path:models/gold",
    dag=dag,
)

dbt_test_gold = BashOperator(
    task_id="dbt_test_gold",
    bash_command="docker exec dbt_airflow_project-dbt-1 dbt test --select path:models/gold",
    dag=dag,
)

dbt_run_gold >> dbt_test_gold
