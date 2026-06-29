# Conventions Reference

## Naming Conventions

| Object | Convention | Example |
|---|---|---|
| Tables / Views / Streams | UPPER_SNAKE_CASE | `STG_ORDERS`, `MART_ORDERS_ENRICHED` |
| Staging | `STG_<source_table>` | `STG_LINEITEM` |
| Mart (fact) | `MART_FCT_<name>` | `MART_FCT_ORDERS` |
| Mart (dim) | `MART_DIM_<name>` | `MART_DIM_CUSTOMER` |
| Quarantine | `<TABLE>_QUARANTINE` | `STG_ORDERS_QUARANTINE` |
| Policies | `MASK_<type>`, `RAP_<desc>` | `MASK_EMAIL`, `RAP_REGION` |
| DMFs | `DMF_<check>_<column>` | `DMF_NULL_COUNT_EMAIL` |
| Sequences | `<TABLE>_SEQ` | `ORDERS_SEQ` |
| Streams | `<TABLE>_STREAM` | `ORDERS_STREAM` |
| Tasks | `<TABLE>_TRANSFORM_TASK` | `ORDERS_TRANSFORM_TASK` |
| Alerts | `<TABLE>_QUALITY_ALERT` | `STG_ORDERS_QUALITY_ALERT` |
| Warehouses | `<NAME>_WH{{env_suffix}}` | `ANALYTICS_WH_DEV` |
| Roles | `<NAME>_ROLE{{env_suffix}}` | `DE_CONSUMER_ROLE_DEV` |
| dbt models | `stg_<table>`, `fct_<name>`, `dim_<name>` | `stg_orders`, `fct_revenue` |

## DCM Templating Variables

| Variable | Applied To | Dev Value | Prod Value |
|---|---|---|---|
| `{{env_suffix}}` | Warehouses, Roles | `_DEV` | `` (empty) |
| `{{wh_size}}` | Warehouses | `XSMALL` | `MEDIUM` |

**NEVER** apply `{{env_suffix}}` to data tables, schemas, or any object that holds production data.

## File Organization

```
sources/
  definitions/
    tables.sql         ← DEFINE TABLE blocks (DCM)
    views.sql          ← DEFINE VIEW blocks (DCM)
    infrastructure.sql ← DEFINE WAREHOUSE/SCHEMA (DCM)
    access.sql         ← DEFINE ROLE + GRANT blocks (DCM)
    procedures.sql     ← CREATE OR REPLACE PROCEDURE
    functions.sql      ← CREATE OR REPLACE FUNCTION
    data_quality.sql   ← CREATE OR REPLACE DATA METRIC FUNCTION
    dynamic_tables.sql ← CREATE OR REPLACE DYNAMIC TABLE
    alerts.sql         ← CREATE OR REPLACE ALERT
    policies.sql       ← CREATE OR REPLACE MASKING/ROW ACCESS POLICY
    tags.sql           ← CREATE OR REPLACE TAG
    sequences.sql      ← CREATE OR REPLACE SEQUENCE
    network.sql        ← Network Rules + EAIs
    integrations.sql   ← Storage + Notification Integrations
    secrets.sql        ← CREATE OR REPLACE SECRET (empty placeholders only)

ingestion/
  snowflake/
    stages.sql         ← DEFINE STAGE + FILE FORMAT (DCM)
    streams.sql        ← DEFINE STREAM blocks (DCM)
    tasks.sql          ← CREATE OR REPLACE TASK (imperative)
    pipes.sql          ← CREATE OR REPLACE PIPE (imperative)
  snowpark/
    transforms.py      ← Python stored procs
  openflow/
    setup/             ← Openflow connector SQL

dbt/models/
  staging/             ← stg_*.sql + _sources.yml + _staging.yml
  intermediate/        ← int_*.sql (ephemeral)
  marts/               ← fct_*.sql + dim_*.sql + _marts.yml

agent/agents/<name>/   ← agent.yml + system_prompt.md + evals/ + monitoring/
custom-ml-models/<n>/  ← spec.yml + model_card.md + snowflake/ + lifecycle/ + runbooks/
```

## dbt Conventions

| Setting | Value |
|---|---|
| Staging materialization | `view` |
| Intermediate materialization | `ephemeral` |
| Mart materialization | `table` with `cluster_by` |
| Incremental strategy | `merge` with `unique_key` |
| Source refs | Always `{{ source('...', '...') }}` in staging, `{{ ref('...') }}` elsewhere |
| Alias for PK | `<table_lower>_id` |
| Alias for FK | `<ref_table_lower>_id` |

## AgentOps Conventions

- One directory per agent under `agent/agents/<agent_name>/`
- `agent.yml` is the single source of truth for the agent spec
- Evals in `evals/*.json`, results (gitignored) in `evals/results/`
- System prompts in `system_prompt.md` — never inline in `agent.yml`
- Monitoring alerts in `monitoring/alerts.yml`

## MLOps Conventions

- Model artifacts stored in `@<MODEL_NAME>_STAGE` (internal stage per model)
- Model version bump required for any change affecting predictions
- Model card (`model_card.md`) required for every production model
- Dual-control approval required for high-risk models (`dual_control_required: true`)
