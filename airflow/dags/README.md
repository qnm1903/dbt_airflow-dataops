# Airflow DAGs Documentation

## dbt_transform_pipeline

### Overview
This DAG orchestrates the complete DBT transformation pipeline.

### Schedule
- **Frequency:** Daily
- **Time:** 6:00 AM UTC
- **Catchup:** Disabled

### Task Flow
```
start
  └── check_source_freshness
        └── dbt_deps
              └── run_bronze_models
                    └── test_bronze_models
                          └── run_silver_models
                                └── test_silver_models
                                      └── run_gold_models
                                            └── test_gold_models
                                                  └── generate_dbt_docs
                                                        └── end_success
```

### Error Handling
- Retries: 2 attempts with exponential backoff
- Notifications: Slack alerts on failure
- Timeout: 2 hours maximum

### Monitoring
- Airflow UI: http://localhost:8080
- Slack Channel: #airflow-notifications
