# dbt Model Scaffolding Reference

## 2.8 — Staging Model → `dbt/models/staging/stg_<lowercase_table_name>.sql`

```sql
{{ config(materialized='view', tags=['staging']) }}

WITH source AS (
    SELECT * FROM {{ source('<project_name_underscore>', '<TABLE_NAME>') }}
),

renamed AS (
    SELECT
        <col1>    AS <alias1>,
        <col2>    AS <alias2>,
        -- Audit
        <TABLE_NAME>_ID                               AS <table_name_lower>_id,
        CURRENT_TIMESTAMP()                           AS _LOADED_AT,
        '<DATABASE>.<SCHEMA>.<TABLE_NAME>'            AS _SOURCE_SYSTEM
    FROM source
)

SELECT * FROM renamed
```

**Column aliasing conventions:**
- PK column: `<TABLE_NAME>_ID` → alias `<table_name_lower>_id`
- FK columns: `<TABLE_NAME>_FK` → alias `<ref_table_lower>_id` (drop `_FK`, add `_id`)
- Preserve original name for non-relational columns
- Cast TPCH FLOAT prices to `NUMBER(15,2)`: `CAST(<col> AS NUMBER(15,2)) AS <col_lower>`
- Cast TPCH dates to DATE: `TRY_TO_DATE(<col>) AS <col_lower>`

## 2.9 — Mart Model → `dbt/models/marts/`

Naming: `fct_` for event/transactional data, `dim_` for dimension tables.

```sql
{{ config(
    materialized = 'table',
    tags         = ['mart'],
    cluster_by   = ['<primary_key_column>']
) }}

WITH base AS (
    SELECT * FROM {{ ref('stg_<table_name_lower>') }}
),

-- Join dimensions if applicable
-- enriched AS (
--   SELECT b.*, d.<dim_col>
--   FROM base b
--   LEFT JOIN {{ ref('dim_<dimension>') }} d ON b.<fk> = d.<pk>
-- )

SELECT * FROM base
```

## Sources YAML Update — `dbt/models/staging/_sources.yml`

Append to existing file (or create if missing):

```yaml
version: 2

sources:
  - name: <project_name_underscore>
    database: <DATABASE>
    schema: <SCHEMA>
    tables:
      - name: <TABLE_NAME>
        description: 'Raw <TABLE_NAME> landing table'
        loaded_at_field: _LOADED_AT
        freshness:
          warn_after: {count: 30, period: minute}
          error_after: {count: 60, period: minute}
        columns:
          - name: <pk_column>
            description: 'Primary key'
            tests:
              - not_null
              - unique
```

## Staging Schema YAML — `dbt/models/staging/_staging.yml`

```yaml
version: 2

models:
  - name: stg_<table_name_lower>
    description: 'Staged view over <TABLE_NAME>'
    columns:
      - name: <table_name_lower>_id
        description: 'Primary key'
        tests:
          - not_null
          - unique
      # Add column-level tests based on profile report
```

## Conventions for Model Materialization

| Layer | Materialization | Notes |
|---|---|---|
| Staging | view | Always a view — thin rename layer |
| Intermediate | ephemeral | Complex join/transform logic |
| Marts (fact) | table | Cluster by PK or most-filtered column |
| Marts (dimension) | table | Cluster by PK |
| High-churn marts | incremental | Use `unique_key` + `merge` strategy |
