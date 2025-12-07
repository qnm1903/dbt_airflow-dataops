# Deployment Runbook

## Overview
This document describes the deployment procedures for the DBT data pipeline.

## Environments

| Environment | Branch | URL | Auto-Deploy |
|-------------|--------|-----|-------------|
| Development | develop | localhost:8080 | Yes |
| Production | main | prod-server:8080 | Yes (with approval) |

## Deployment Steps

### Automatic Deployment (CI/CD)
1. Create feature branch from `develop`
2. Make changes and commit
3. Create Pull Request to `develop`
4. CI checks run automatically
5. On merge, deploy-dev workflow triggers
6. Create PR from `develop` to `main` for production

### Manual Deployment
```bash
# Connect to server
ssh deploy@server

# Navigate to project
cd /opt/dbt_airflow_project

# Pull latest changes
git pull origin main

# Run DBT
docker exec dbt_airflow_project-dbt-1 dbt deps
docker exec dbt_airflow_project-dbt-1 dbt run
docker exec dbt_airflow_project-dbt-1 dbt test
```

## Monitoring
- Airflow UI: http://localhost:8080
- GitHub Actions: https://github.com/ORG/REPO/actions
- Slack Channel: #data-pipeline-alerts

## Contacts
- On-call: data-team@company.com
- Escalation: engineering-lead@company.com
