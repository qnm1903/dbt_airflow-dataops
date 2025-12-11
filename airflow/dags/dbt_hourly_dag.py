"""
DBT Transformation Pipeline DAG - Hourly

This DAG orchestrates the DBT data transformation pipeline with:
- Bronze → Silver → Gold layer execution
- Data quality testing
- Source freshness checks
- Error handling and notifications

Schedule: Hourly
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.utils.trigger_rule import TriggerRule

# Configuration
DBT_PROJECT_DIR = "/usr/app/dbt"
DBT_PROFILES_DIR = "/usr/app/dbt"
DBT_CONTAINER = "dbt_airflow-dataops-dbt-1"

default_args = {
    "owner": "data_engineering",
    "depends_on_past": False,
    "email": ["ngocle266tqt@gmail.com"],
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=1),
    "retry_exponential_backoff": True,
    "max_retry_delay": timedelta(minutes=30),
    "execution_timeout": timedelta(hours=1),
}

dag = DAG(
    "dbt_transform_hourly",
    default_args=default_args,
    description="DBT transformation pipeline - Hourly",
    schedule_interval="@hourly",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "data-pipeline", "etl", "hourly"],
    doc_md=__doc__,
    max_active_runs=1,
)

# Task Definitions
start = EmptyOperator(
    task_id="start",
    dag=dag,
)

# Source Freshness Check
# Note: Using || true to prevent pipeline failure on stale data
# The freshness check will still log warnings/errors but won't block the DAG
check_source_freshness = BashOperator(
    task_id="check_source_freshness",
    bash_command=f"docker exec {DBT_CONTAINER} dbt source freshness --profiles-dir {DBT_PROFILES_DIR} || true",
    dag=dag,
)

# DBT Dependencies
dbt_deps = BashOperator(
    task_id="dbt_deps",
    bash_command=f"docker exec {DBT_CONTAINER} dbt deps --profiles-dir {DBT_PROFILES_DIR}",
    dag=dag,
)

# Bronze Layer
run_bronze = BashOperator(
    task_id="run_bronze_models",
    bash_command=f"docker exec {DBT_CONTAINER} dbt run --select bronze --profiles-dir {DBT_PROFILES_DIR}",
    dag=dag,
)

test_bronze = BashOperator(
    task_id="test_bronze_models",
    bash_command=f"docker exec {DBT_CONTAINER} dbt test --select bronze --profiles-dir {DBT_PROFILES_DIR}",
    dag=dag,
)

# Silver Layer
run_silver = BashOperator(
    task_id="run_silver_models",
    bash_command=f"docker exec {DBT_CONTAINER} dbt run --select silver --profiles-dir {DBT_PROFILES_DIR}",
    dag=dag,
)

test_silver = BashOperator(
    task_id="test_silver_models",
    bash_command=f"docker exec {DBT_CONTAINER} dbt test --select silver --profiles-dir {DBT_PROFILES_DIR}",
    dag=dag,
)

# Gold Layer
run_gold = BashOperator(
    task_id="run_gold_models",
    bash_command=f"docker exec {DBT_CONTAINER} dbt run --select gold --profiles-dir {DBT_PROFILES_DIR}",
    dag=dag,
)

test_gold = BashOperator(
    task_id="test_gold_models",
    bash_command=f"docker exec {DBT_CONTAINER} dbt test --select gold --profiles-dir {DBT_PROFILES_DIR}",
    dag=dag,
)

# Generate Documentation
generate_docs = BashOperator(
    task_id="generate_dbt_docs",
    bash_command=f"docker exec {DBT_CONTAINER} dbt docs generate --profiles-dir {DBT_PROFILES_DIR}",
    dag=dag,
)

end_success = EmptyOperator(
    task_id="end_success",
    dag=dag,
)


# Failure Notification with detailed context
def build_failure_message(context):
    """Build detailed failure notification message with debugging context."""
    from datetime import datetime, timezone

    task_instance = context.get("task_instance")
    dag_run = context.get("dag_run")
    execution_date = context.get("execution_date")
    exception = context.get("exception")

    # Get task details
    dag_id = dag_run.dag_id if dag_run else "unknown"
    task_id = task_instance.task_id if task_instance else "unknown"
    try_number = task_instance.try_number if task_instance else 0
    max_tries = task_instance.max_tries if task_instance else 0

    # Calculate duration if available
    start_time = dag_run.start_date if dag_run else None
    end_time = datetime.now(timezone.utc)
    duration = f"{(end_time - start_time).total_seconds() / 60:.2f} minutes" if start_time else "Unknown"

    # Get log URL
    log_url = task_instance.log_url if task_instance else "N/A"

    # Determine failure stage
    failure_stage = "Unknown"
    if task_id:
        if "bronze" in task_id.lower():
            failure_stage = "Bronze Layer (Raw Data Ingestion)"
        elif "silver" in task_id.lower():
            failure_stage = "Silver Layer (Data Transformation)"
        elif "gold" in task_id.lower():
            failure_stage = "Gold Layer (Business Analytics)"
        elif "test" in task_id.lower():
            failure_stage = "Data Quality Testing"
        elif "freshness" in task_id.lower():
            failure_stage = "Source Freshness Check"
        elif "deps" in task_id.lower():
            failure_stage = "DBT Dependencies"
        elif "docs" in task_id.lower():
            failure_stage = "Documentation Generation"

    # Build retry status
    retry_status = f"Attempt {try_number} of {max_tries}"
    will_retry = try_number < max_tries

    message = f"""
:red_circle: *DBT Data Pipeline - FAILURE ALERT*

*Critical Information:*
• DAG: `{dag_id}`
• Failed Task: `{task_id}`
• Failure Stage: *{failure_stage}*
• Execution Date: {execution_date.strftime('%Y-%m-%d %H:%M:%S UTC') if execution_date else 'Unknown'}
• Duration Before Failure: {duration}
• Run ID: `{dag_run.run_id if dag_run else 'unknown'}`

*Retry Information:*
• Status: {retry_status}
• {'🔄 Will retry automatically' if will_retry else '❌ Max retries reached - manual intervention required'}

*Error Details:*
```
{str(exception)[:500] if exception else 'No exception details available'}
```

*Troubleshooting Steps:*
1. Check the Airflow logs: {log_url}
2. Verify source data availability and quality
3. Check database connectivity and permissions
4. Review recent schema or data changes
5. Validate DBT model SQL for errors

*Immediate Actions Required:*
• Review logs and identify root cause
• Fix underlying issue (data, schema, or code)
• {'Monitor retry attempts' if will_retry else 'Manually trigger DAG after fix'}
• Update stakeholders on ETA for data availability

    """
    return message


def send_failure_notification(**context):
    """Send detailed failure notification to Slack."""
    import os
    import requests

    webhook_url = os.getenv("AIRFLOW_CONN_SLACK_WEBHOOK", "")

    # Parse JSON format if needed
    if webhook_url.startswith("{"):
        import json

        try:
            conn_data = json.loads(webhook_url)
            webhook_url = conn_data.get("password", "")
        except Exception:
            pass

    if webhook_url and webhook_url.startswith("http"):
        message = build_failure_message(context)
        try:
            response = requests.post(webhook_url, json={"text": message})
            return f"Failure notification sent - Status: {response.status_code}"
        except Exception as e:
            return f"Failed to send notification: {e}"
    return "No webhook URL configured"


notify_failure = PythonOperator(
    task_id="notify_failure",
    python_callable=send_failure_notification,
    trigger_rule=TriggerRule.ONE_FAILED,
    dag=dag,
)


# Success Notification with detailed summary
def build_success_message(context):
    """Build detailed success notification message with pipeline metrics."""
    from datetime import datetime, timezone

    dag_run = context["dag_run"]
    execution_date = context["execution_date"]

    # Calculate pipeline duration (handle timezone-aware datetimes)
    start_time = dag_run.start_date
    end_time = datetime.now(timezone.utc)
    duration = (end_time - start_time).total_seconds() / 60

    message = f"""
:white_check_mark: *DBT Data Pipeline - Successfully Completed*

*Pipeline Information:*
• DAG: `{dag_run.dag_id}`
• Started At: {start_time.strftime('%Y-%m-%d %H:%M:%S UTC')}
• Ended At: {end_time.strftime('%Y-%m-%d %H:%M:%S UTC')}
• Execution Date: {execution_date.strftime('%Y-%m-%d %H:%M:%S UTC')}
• Duration: {duration:.2f} minutes
• Run ID: `{dag_run.run_id}`

    """
    return message


def send_success_notification(**context):
    """Send detailed success notification to Slack."""
    import os
    import requests

    webhook_url = os.getenv("AIRFLOW_CONN_SLACK_WEBHOOK", "")

    # Parse JSON format if needed
    if webhook_url.startswith("{"):
        import json

        try:
            conn_data = json.loads(webhook_url)
            webhook_url = conn_data.get("password", "")
        except Exception:
            pass

    if webhook_url and webhook_url.startswith("http"):
        message = build_success_message(context)
        try:
            response = requests.post(webhook_url, json={"text": message})
            return f"Notification sent - Status: {response.status_code}"
        except Exception as e:
            return f"Failed to send notification: {e}"
    return "No webhook URL configured"


notify_success = PythonOperator(
    task_id="notify_success",
    python_callable=send_success_notification,
    trigger_rule=TriggerRule.ALL_SUCCESS,
    dag=dag,
)

# Task Dependencies (DAG Flow)
start >> check_source_freshness >> dbt_deps

dbt_deps >> run_bronze >> test_bronze
test_bronze >> run_silver >> test_silver
test_silver >> run_gold >> test_gold

test_gold >> generate_docs >> end_success

# Add to DAG flow
[test_bronze, test_silver, test_gold] >> notify_failure
end_success >> notify_success
