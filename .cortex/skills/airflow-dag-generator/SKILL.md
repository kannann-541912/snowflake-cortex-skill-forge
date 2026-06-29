---
name: airflow-dag-generator
description: Generate a production-ready Apache Airflow DAG that orchestrates dbt models against Snowflake. Introspects Snowflake table metadata and, if present, the dbt manifest.json to determine model layer topology (staging → intermediate → marts), then emits a fully configured DAG using Astronomer Cosmos (preferred) or BashOperator, including a SnowflakeSensor for data arrival detection and Slack failure alerting.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Read
  - Write
  - Bash
---

# Client Context
Read `references/client-context.md` at the start of every invocation. Apply any values it
defines as overrides: DAG variant (cosmos vs bash), schedule cron, Snowflake connection ID,
dbt project path and target, SnowflakeSensor settings, failure alerting config, and retry
policy. If the file is absent or a value is unset (`~`), use the built-in defaults. Never
fail if the file is missing.

# Airflow DAG Generator for dbt Models

## Domain Context
You are an Airflow and dbt integration specialist. You generate production-grade Airflow DAGs
using Astronomer Cosmos (preferred) or BashOperator, with proper dependency ordering derived
from the dbt manifest, SnowflakeSensor for data arrival detection, and Slack failure alerting.

## When to Use
- User wants an Airflow DAG to orchestrate their dbt models against Snowflake
- "generate a DAG", "create Airflow pipeline for dbt", "schedule my dbt models"
- User has a dbt project with Snowflake and wants a production orchestration layer

## When NOT to Use
- User doesn't have dbt models yet → set up dbt first with `de-transform-setup`
- User only wants to run dbt locally → just use `dbt run`
- User wants Snowflake-native scheduling → use Dynamic Tables or Snowflake Tasks instead
- User has Prefect/Dagster → this skill generates Airflow only

## Gotchas
- The `airflow-dag-generator-claude` name was a reserved word bug — this skill is now correctly named `airflow-dag-generator`.
- Cosmos DAGs require the `astronomer-cosmos` package — always add it to `requirements.txt`.
- SnowflakeSensor requires the `apache-airflow-providers-snowflake` package.
- `profile_name` in Cosmos must match exactly the profile name in `profiles.yml`.
- Task IDs in Airflow must be unique within the DAG — use `{model_layer}__{model_name}` format.
- Slack alerting requires a `slack_conn_id` Airflow connection — note this in the generated DAG comment.

## Core Rule
**Introspect Snowflake and the local project first. Topology, sensor thresholds, and schedule are derived from real metadata — never hardcoded defaults.**

---

## Step 0 — Load client context
Read `references/client-context.md`. If present, apply:
- `dag_variant` → cosmos | bash (skip Step 4 prompt if already set)
- `schedule.cron` → override "0 4 * * *" default
- `snowflake.conn_id` → Airflow Snowflake connection ID
- `dbt.project_path` / `dbt.profile_name` / `dbt.target` → dbt configuration
- `alerting.email` / `alerting.slack.conn_id` → alerting setup
- `sensor.enabled` → whether to include SnowflakeSensor

## Step 1 — Check for dbt manifest
```bash
find . -name "manifest.json" -path "*/target/*" | head -5
```

If found, parse it to get exact model dependencies:
```bash
cat ./target/manifest.json | python3 -c "
import json, sys
m = json.load(sys.stdin)
nodes = {k: v for k, v in m['nodes'].items() if v['resource_type'] == 'model'}
for k, v in nodes.items():
    print(v['name'], '|', v['config']['materialized'], '|', list(v['depends_on']['nodes']))
"
```

If **no manifest**, fall back to Snowflake naming-convention discovery:

```sql
SELECT table_schema, table_name, table_type, comment, last_altered
FROM <database>.information_schema.tables
WHERE table_catalog = '<DATABASE>'
  AND (
      comment    ILIKE '%dbt%'
      OR table_name ILIKE 'stg_%'
      OR table_name ILIKE 'int_%'
      OR table_name ILIKE 'fct_%'
      OR table_name ILIKE 'dim_%'
      OR table_name ILIKE 'mart_%'
  )
ORDER BY table_schema, table_name;
```

---

## Step 2 — Detect timestamp column for sensor
```sql
SELECT column_name, data_type
FROM <database>.information_schema.columns
WHERE table_schema = '<SCHEMA>'
  AND table_name   = '<TABLE>'
  AND (
      data_type ILIKE '%timestamp%'
      OR data_type ILIKE '%date%'
  )
  AND (
      column_name ILIKE '%_at'
      OR column_name ILIKE '%_time'
      OR column_name ILIKE '%_date'
      OR column_name ILIKE '%_ts'
  )
ORDER BY ordinal_position
LIMIT 1;
```

Also get row count baseline for sensor freshness threshold:
```sql
SELECT
    MAX(<timestamp_col>)                                           AS latest_record,
    DATEDIFF('hour', MAX(<timestamp_col>), CURRENT_TIMESTAMP())    AS hours_stale,
    COUNT(*)                                                       AS row_count
FROM <database>.<schema>.<table>;
```

---

## Step 3 — Determine DAG layer topology

Map models to layers:
| Layer | Naming Pattern | dbt Tag |
|---|---|---|
| 0 — Source freshness | raw tables / source check | n/a |
| 1 — Staging | `stg_*` | `tag:staging` |
| 2 — Intermediate | `int_*` | `tag:intermediate` |
| 3 — Marts | `fct_*`, `dim_*`, `mart_*` | `tag:marts` |

Insert a dbt test gate between every layer.

---

## Step 4 — Ask the user which variant they want

Ask: **"Should I use Astronomer Cosmos (Option A — recommended) or plain BashOperator (Option B)?"**

---

## Step 5a — Generate DAG: Astronomer Cosmos

Save as `dags/dbt_<project_name>_dag.py`.

```python
# dags/dbt_<project_name>_dag.py
# Auto-generated by CoCo CLI — airflow-dag-generator skill

from __future__ import annotations
from datetime import datetime, timedelta
from pathlib import Path

from airflow.decorators import dag
from airflow.operators.empty import EmptyOperator
from airflow.providers.snowflake.sensors.snowflake import SnowflakeSensor
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping

DBT_PROJECT_PATH = Path("/usr/local/airflow/dbt/<project_name>")
SNOWFLAKE_CONN_ID = "snowflake_default"
DBT_DATABASE      = "<database>"
DBT_SCHEMA        = "<schema>"

profile_config = ProfileConfig(
    profile_name  = "<project_name>",
    target_name   = "prod",
    profile_mapping = SnowflakeUserPasswordProfileMapping(
        conn_id      = SNOWFLAKE_CONN_ID,
        profile_args = {"database": DBT_DATABASE, "schema": DBT_SCHEMA},
    )
)

default_args = {
    "owner":            "data-engineering",
    "retries":          2,
    "retry_delay":      timedelta(minutes=5),
    "email_on_failure": True,
    "email":            ["data-alerts@<your-org>.com"],
}

@dag(
    dag_id       = "dbt_<project_name>_pipeline",
    schedule     = "0 4 * * *",
    start_date   = datetime(2026, 1, 1),
    catchup      = False,
    default_args = default_args,
    tags         = ["dbt", "snowflake", "<project_name>"],
)
def dbt_pipeline():

    start = EmptyOperator(task_id="start")
    end   = EmptyOperator(task_id="end")

    # ── Data arrival sensor (only if timestamp col found in Step 2) ───────
    wait_for_data = SnowflakeSensor(
        task_id           = "wait_for_<table>_loaded",
        snowflake_conn_id = SNOWFLAKE_CONN_ID,
        sql               = """
            SELECT COUNT(*) FROM <database>.<schema>.<table>
            WHERE <timestamp_col> >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
        """,
        mode          = "poke",
        poke_interval = 300,
        timeout       = 3600,
    )

    def task_group(group_id: str, select: str | None = None, commands: list | None = None):
        kwargs = {"commands": commands} if commands else {"select": select, "full_refresh": False}
        return DbtTaskGroup(
            group_id         = group_id,
            project_config   = ProjectConfig(DBT_PROJECT_PATH),
            profile_config   = profile_config,
            execution_config = ExecutionConfig(dbt_executable_path="/usr/local/bin/dbt"),
            operator_args    = kwargs,
        )

    source_freshness  = task_group("source_freshness",  commands=["dbt source freshness"])
    staging           = task_group("staging",            select="tag:staging")
    staging_tests     = task_group("staging_tests",      commands=["dbt test --select tag:staging"])
    intermediate      = task_group("intermediate",       select="tag:intermediate")
    inter_tests       = task_group("intermediate_tests", commands=["dbt test --select tag:intermediate"])
    marts             = task_group("marts",              select="tag:marts")
    mart_tests        = task_group("mart_tests",         commands=["dbt test --select tag:marts"])

    (
        start >> wait_for_data >> source_freshness
        >> staging >> staging_tests
        >> intermediate >> inter_tests
        >> marts >> mart_tests
        >> end
    )

dbt_pipeline()
```

---

## Step 5b — Generate DAG: BashOperator (fallback)

Save as `dags/dbt_<project_name>_bash_dag.py`.

```python
from __future__ import annotations
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

DBT_DIR  = "/usr/local/airflow/dbt/<project_name>"
DBT_PROF = "prod"

default_args = {"owner": "data-engineering", "retries": 2, "retry_delay": timedelta(minutes=5)}

def dbt_task(dag, task_id, command):
    return BashOperator(
        task_id      = task_id,
        bash_command = f"cd {DBT_DIR} && dbt {command} --target {DBT_PROF}",
        dag          = dag,
    )

with DAG("dbt_<project_name>_bash", schedule="0 4 * * *",
         start_date=datetime(2026,1,1), catchup=False,
         default_args=default_args, tags=["dbt","snowflake"]) as dag:

    tasks = [
        dbt_task(dag, "source_freshness",  "source freshness"),
        dbt_task(dag, "run_staging",       "run --select tag:staging"),
        dbt_task(dag, "test_staging",      "test --select tag:staging"),
        dbt_task(dag, "run_intermediate",  "run --select tag:intermediate"),
        dbt_task(dag, "test_intermediate", "test --select tag:intermediate"),
        dbt_task(dag, "run_marts",         "run --select tag:marts"),
        dbt_task(dag, "test_marts",        "test --select tag:marts"),
    ]
    for i in range(len(tasks) - 1):
        tasks[i] >> tasks[i + 1]
```

---

## Step 6 — Emit requirements.txt additions
```text
apache-airflow-providers-snowflake>=4.0.0
astronomer-cosmos>=1.3.0      # Option A only
dbt-snowflake>=1.7.0
```

---

## Output Format
1. DAG Python file (chosen variant) in a fenced code block labelled with the filename
2. SnowflakeSensor snippet (if timestamp column found), separately labelled as optional
3. `requirements.txt` additions
4. One-paragraph summary: schedule used, layer structure, Airflow connection ID to configure, and all `<PLACEHOLDER>` values to fill in

## Key Automatic Decisions
| Snowflake Signal | DAG Decision |
|---|---|
| Timestamp column found | Include SnowflakeSensor + source freshness gate |
| No manifest.json | Infer layers from stg_/int_/fct_/dim_/mart_ naming |
| manifest.json found | Use exact dependency graph from manifest |
| Row count > 10M | Set `full_refresh: False` on all tasks |

## Edge Cases
- **No dbt project at all**: Generate a DAG using `SnowflakeOperator` with raw SQL tasks instead.
- **Existing DAG found**: Run `ls dags/ | grep <project>` first and warn before overwriting.
- **No timestamp column**: Remove SnowflakeSensor; use `schedule='@daily'` with no arrival check.
