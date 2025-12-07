# Rollback Procedures

## When to Rollback
- Data quality tests failing in production
- Pipeline errors affecting downstream systems
- Performance degradation after deployment

## Rollback Steps

### Option 1: Git Revert (Recommended)
```bash
# Identify the commit to revert
git log --oneline -10

# Revert the problematic commit
git revert <commit-hash>

# Push to trigger re-deployment
git push origin main
```

### Option 2: Manual Model Rollback
```bash
# Connect to DBT container
docker exec -it dbt_airflow_project-dbt-1 bash

# Run specific previous version
dbt run --select model_name --full-refresh
```

### Option 3: Database Snapshot Restore
```sql
-- Restore from backup (coordinate with DBA)
RESTORE DATABASE AdventureWorks2014 
FROM DISK = '/backup/AdventureWorks2014_YYYYMMDD.bak'
WITH REPLACE;
```

## Post-Rollback Checklist
- [ ] Verify data integrity
- [ ] Run DBT tests
- [ ] Check Airflow DAG status
- [ ] Notify stakeholders
- [ ] Create incident report
