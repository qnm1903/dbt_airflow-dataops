# DBT + Airflow + SQL Server DataOps Project

## Pipeline Status

| Workflow | Status |
|----------|--------|
| CI Pipeline | ![CI](https://github.com/NgocLe-101/dbt-airflow-dataops/workflows/CI%20Pipeline/badge.svg) |
| Deploy Dev | ![Deploy Dev](https://github.com/NgocLe-101/dbt-airflow-dataops/workflows/Deploy%20to%20Development/badge.svg?branch=develop) |
| Deploy Prod | ![Deploy Prod](https://github.com/NgocLe-101/dbt-airflow-dataops/workflows/Deploy%20to%20Production/badge.svg?branch=main) |

# DBT and Airflow Data Pipeline Project

## Project Overview
This project implements an automated data transformation pipeline using DBT (Data Build Tool) and Apache Airflow. The pipeline extracts data from SQL Server, transforms it using DBT models, and loads it into a target database, following modern data engineering best practices.

### Architecture Overview
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  SQL Server │ ──► │    DBT     │ ──► │  Target DB  │
└─────────────┘     └─────────────┘     └─────────────┘
        ▲                  ▲                   ▲
        └──────────┬──────┴───────────┬───────┘
                   │                   │
            ┌──────┴───────┐    ┌─────┴──────┐
            │   Airflow    │    │  Docker    │
            └──────────────┘    └────────────┘
```

## Prerequisites
- Docker and Docker Compose
- Git
- Basic understanding of SQL, DBT, and Airflow
- Access to source SQL Server database

## Project Structure and Components

```
dbt_airflow_project/
├── airflow/
│   ├── dags/                  # Contains Airflow DAG definitions
│   │   └── dbt_dag.py        # DAG that orchestrates DBT transformations
│   └── logs/                  # Airflow execution logs
├── dbt/
│   ├── models/               # Contains all DBT data models
│   │   ├── staging/         # First layer: Raw data cleaning and standardization
│   │   │   ├── stg_sales_orders.sql    # Example staging model
│   │   │   └── schema.yml              # Model tests and documentation
│   │   └── marts/           # Final layer: Business-level transformations
│   ├── dbt_project.yml      # DBT project configurations
│   ├── packages.yml         # External DBT package dependencies
│   └── profiles.yml         # Database connection profiles
└── docker-compose.yml       # Container orchestration configuration
```

### Component Details

#### 1. Airflow Components
- **dags/**:
  - Purpose: Stores Airflow DAG (Directed Acyclic Graph) definitions
  - Usage: Schedules and monitors DBT model runs and tests

- **logs/**:
  - Purpose: Contains Airflow execution logs
  - Retention: Typically keeps logs for last 30 days

#### 2. DBT Components
- **models/staging/**:
  - Purpose: First layer of transformation
  - Materialization: Usually materialized as views for flexibility

- **models/marts/**:
  - Purpose: Final transformation layer
  - Usage: Direct connection to BI tools

- **dbt_project.yml**:
  - Purpose: DBT project configuration

- **packages.yml**:
  - Purpose: Manages external DBT packages
  - Usage: Install packages using `dbt deps`

- **profiles.yml**:
  - Purpose: Database connection configuration

#### 3. Docker Components
- **docker-compose.yml**:
  - Purpose: Container orchestration

### Removed Components
The following components from the original structure were removed as they weren't essential:
- `dbt/tests/` - Tests are now included in schema.yml files
- `dbt/macros/` - Using standard macros from dbt_utils package
- `dbt/intermediate/` - Using two-layer (staging/marts) architecture
- `docker/airflow/` and `docker/dbt/` - Docker configurations included in main docker-compose.yml

## Container Workflow
1. **Data Flow**:
   ```
   SQL Server → DBT → Target Database
   ```

2. **Process Flow**:
   ```
   Extract → Transform → Load
   ```

3. **Monitoring Flow**:
   ```
   Airflow DAGs → Logs → Alerts
   ```

## Step-by-Step Implementation Guide

### 1. Initial Setup

1.1. Clone the repository:
```bash
git clone <repository-url>
cd dbt_airflow_project
```

1.2. Create necessary directories:
```bash
mkdir -p airflow/dags airflow/logs dbt/models/{staging,intermediate,marts}
```

### 2. Docker Configuration

2.1. Create `docker-compose.yml` with the following services:
- Airflow Webserver
- Airflow Scheduler
- PostgreSQL (Airflow metadata database)
- SQL Server (Source database)
- DBT container

2.2. Build custom Docker images:
```bash
docker-compose build
```

### 3. DBT Configuration

3.1. Configure DBT project (`dbt_project.yml`):
```yaml
name: 'dbt_sqlserver_project'
version: '1.0.0'
config-version: 2
profile: 'default'

model-paths: ["models"]
test-paths: ["tests"]
macro-paths: ["macros"]

target-path: "target"
clean-targets:
    - "target"
    - "logs"

models:
  dbt_sqlserver_project:
```

3.2. Configure DBT profiles (`profiles.yml`):
```yaml
default:
  target: dev
```

3.3. Install DBT packages (`packages.yml`):
```yaml
packages:
  - package: dbt-labs/dbt_utils
```

### 4. Model Development

4.1. Create staging models:
- Create models under `dbt/models/staging/`
- Example: `stg_sales_orders.sql`
```sql
with source_sales_order_header as (
    select * from {{ source('adventure_works', 'SalesOrderHeader') }}
),
source_sales_order_detail as (
    select * from {{ source('adventure_works', 'SalesOrderDetail') }}
)

select
    soh.SalesOrderID,
    soh.OrderDate,
    sod.LineTotal
from source_sales_order_header soh
left join source_sales_order_detail sod
    on soh.SalesOrderID = sod.SalesOrderID
```

4.2. Add tests in `schema.yml`:
```yaml
version: 2

models:
  - name: stg_sales_orders
```

### 5. Airflow DAG Configuration

5.1. Create DBT DAG (`airflow/dags/dbt_dag.py`):
```python
from airflow import DAG
from airflow.providers.docker.operators.docker import DockerOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}

dag = DAG(
    'dbt_transform',
    default_args=default_args,
    description='Run DBT models',
    schedule_interval=timedelta(days=1)
)

dbt_run = DockerOperator(
    task_id='dbt_run',
    image='dbt_image',
    command='dbt run',
    dag=dag
)

dbt_test = DockerOperator(
    task_id='dbt_test',
    image='dbt_image',
    command='dbt test',
    dag=dag
)

dbt_run >> dbt_test
```

### 6. Starting the Project

6.1. Initialize the containers:
```bash
docker-compose up -d
```

6.2. Install DBT dependencies:
```bash
docker-compose exec dbt dbt deps
```

6.3. Run DBT models:
```bash
docker-compose exec dbt dbt run
```

6.4. Test DBT models:
```bash
docker-compose exec dbt dbt test
```

### 7. Accessing Services

- Airflow UI: http://localhost:8080
  - Username: airflow
  - Password: airflow
- SQL Server:
  - Host: localhost
  - User: sa
  - Password: YourStrong@Passw0rd

## Why Containers?

We use containers for several important reasons:

1. **Isolation**: Each service runs in its own container, preventing conflicts between dependencies and ensuring consistent environments.

2. **Reproducibility**: Docker ensures that the development, testing, and production environments are identical.

3. **Scalability**: Containers can be easily scaled up or down based on workload requirements.

4. **Version Control**: Container configurations are version-controlled, making it easy to track changes and roll back if needed.

5. **Portability**: The project can run on any system that supports Docker, regardless of the underlying OS or infrastructure.

## Best Practices

1. **Version Control**
   - Keep all code in version control
   - Use meaningful commit messages
   - Create branches for new features

2. **Testing**
   - Write tests for all DBT models
   - Test data quality and business logic
   - Run tests before deploying changes

3. **Documentation**
   - Document all models and transformations
   - Keep README up to date
   - Use clear naming conventions

4. **Security**
   - Never commit sensitive credentials
   - Use environment variables for secrets
   - Regularly update dependencies

## Troubleshooting

Common issues and solutions:

1. **Container Connection Issues**
   - Check if all containers are running: `docker-compose ps`
   - Verify network connectivity: `docker network ls`

2. **DBT Errors**
   - Check profiles.yml configuration
   - Verify database credentials
   - Run `dbt debug` for diagnostics

3. **Airflow DAG Issues**
   - Check DAG syntax
   - Verify task dependencies
   - Check Airflow logs

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

For additional support:
- Check the project issues
- Contact the development team
- Refer to DBT and Airflow documentation
