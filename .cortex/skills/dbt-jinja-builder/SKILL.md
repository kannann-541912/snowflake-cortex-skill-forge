---
name: dbt-jinja-builder
description: Scaffold a complete dbt model layer for any Snowflake table or view. Introspects column metadata, primary keys, and data distributions directly from Snowflake, then generates a Jinja-templated dbt model SQL file, reusable macro library, schema.yml with auto-inferred tests, and sources.yml — all ready to drop into a dbt project.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Write
  - Read
  - Bash
---

# Client Context
Read `references/client-context.md` at the start of every invocation. Apply any values it
defines as overrides: dbt project path and layer schema names, materialization defaults per
layer, surrogate key method, schema YAML file naming conventions, macro generation flags,
and type cast overrides. If the file is absent or a value is unset (`~`), use the built-in
defaults. Never fail if the file is missing.

# dbt Jinja Builder

## Domain Context
You are a dbt model scaffolding specialist who generates idiomatic Jinja-templated dbt SQL.
You introspect the live Snowflake table before writing any code to ensure column names, types,
and PK relationships are accurate. You produce ready-to-run models, not templates with TODOs.

## When to Use
- User wants a dbt staging or mart model for a Snowflake table
- "scaffold a dbt model", "create a staging model for X", "generate dbt Jinja for this table"
- User has a Snowflake table and needs it modeled in dbt immediately

## When NOT to Use
- User wants to generate quality tests for an existing model → use `dbt-expectations-generator`
- User wants to convert an Informatica mapping → use `informatica-to-dbt`
- User wants a DMF for data quality monitoring → use `dmf-generator`
- User needs a complete dbt project scaffold → use `de-transform-setup` within the DE workflow

## Gotchas
- Never assume column types — always run `DESCRIBE TABLE` or query `information_schema.columns` first.
- dbt staging models must use `{{ source('...', '...') }}`, not direct table FQNs.
- `{{ ref() }}` must be used for cross-model references — never hardcode schema.table paths.
- Schema YAML file names must match the convention in the existing project (`_staging.yml`, `_marts.yml`).
- If the table has TPCH FLOAT prices, cast them to NUMBER(15,2) in the staging model.

## Core Rule
**Always introspect Snowflake before generating any dbt code. Column names, types, PKs, cardinality, and null rates must come from live metadata queries — never assumed.**

---

## Step 0 — Load client context
Read `references/client-context.md`. If present, apply:
- `dbt.staging_schema` / `dbt.mart_schema` / `dbt.schema_files` → layer and file naming
- `materialization.staging` / `materialization.mart` → override incremental/view/table
- `materialization.incremental_strategy` → merge | delete+insert | append
- `surrogate_key.method` → dbt_utils | native_hash | none
- `type_cast_overrides` → additional column-name-pattern → type cast rules
- `contract.enforced` → add contract block to all generated models

## Step 1 — Resolve the source table
```sql
SELECT table_catalog, table_schema, table_name, table_type
FROM <database>.information_schema.tables
WHERE table_name ILIKE '<table>'
LIMIT 5;
```

---

## Step 2 — Introspect column metadata
```sql
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length,
    numeric_precision,
    ordinal_position
FROM <database>.information_schema.columns
WHERE table_schema = '<SCHEMA>'
  AND table_name   = '<TABLE>'
ORDER BY ordinal_position;
```

Detect primary key columns:
```sql
SELECT kcu.column_name
FROM <database>.information_schema.table_constraints tc
JOIN <database>.information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name      = '<TABLE>'
  AND tc.constraint_type = 'PRIMARY KEY';
```

---

## Step 3 — Profile for test thresholds
```sql
SELECT
    COUNT(*)                          AS total_rows,
    COUNT_IF(<col> IS NULL)           AS null_count,
    COUNT(DISTINCT <col>)             AS distinct_count,
    MIN(CAST(<col> AS VARCHAR))       AS min_val,
    MAX(CAST(<col> AS VARCHAR))       AS max_val
FROM <database>.<schema>.<table>;
-- Batch as UNION ALL for all columns
```

For low-cardinality VARCHAR columns (distinct_count ≤ 30), also fetch the value set:
```sql
SELECT DISTINCT <col>, COUNT(*) AS freq
FROM <database>.<schema>.<table>
GROUP BY 1 ORDER BY freq DESC LIMIT 30;
```

---

## Step 4 — Generate the dbt model SQL

Save as `models/<model_name>/<model_name>.sql`.

- If a timestamp column exists (name contains `_at`, `_time`, `_date`, `_ts`): use `incremental` materialization
- If no timestamp column: use `table` materialization

```sql
{{
    config(
        materialized     = 'incremental',   -- or 'table' if no timestamp col
        unique_key       = '<pk_column>',
        on_schema_change = 'sync_all_columns',
        tags             = ['<schema_name>', 'generated']
    )
}}

with source as (

    select * from {{ source('<source_name>', '<table_name>') }}

    {% if is_incremental() %}
    where <updated_at_col> > (select max(<updated_at_col>) from {{ this }})
    {% endif %}

),

renamed as (

    select
        {%- for col in [<comma_separated_col_list_from_step2>] %}
        {{ col }}{% if not loop.last %},{% endif %}
        {%- endfor %}
    from source

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['<pk_col>']) }} as surrogate_key,
        *,
        CURRENT_TIMESTAMP() as dbt_loaded_at
    from renamed

)

select * from final
```

---

## Step 5 — Generate macros

Save as `macros/<model_name>_macros.sql`.

### 5a — Column list macro
```jinja
{% macro <model_name>_columns() %}
    {{ ['<col1>', '<col2>', '...'] | join(', ') }}
{% endmacro %}
```

### 5b — Null-safe cast
```jinja
{% macro safe_cast(col_name, target_type, null_val='NULL') %}
    CASE
        WHEN {{ col_name }} IS NULL THEN {{ null_val }}::{{ target_type }}
        ELSE TRY_CAST({{ col_name }} AS {{ target_type }})
    END
{% endmacro %}
```

### 5c — Deduplication (only when distinct_count < total_rows for PK column)
```jinja
{% macro deduplicate(relation, partition_by, order_by='_loaded_at DESC') %}
    with deduped as (
        select *, ROW_NUMBER() OVER (
            PARTITION BY {{ partition_by }} ORDER BY {{ order_by }}
        ) as _row_num
        from {{ relation }}
    )
    select * exclude (_row_num) from deduped where _row_num = 1
{% endmacro %}
```

### 5d — Timestamp standardisation (for every timestamp/date column found)
```jinja
{% macro standardize_ts(col) %}
    CONVERT_TIMEZONE('UTC', {{ col }})::TIMESTAMP_NTZ
{% endmacro %}
```

### 5e — Enum value mapper (for VARCHAR columns with distinct_count ≤ 20)
```jinja
{% macro map_<col_name>(col) %}
    CASE {{ col }}
        WHEN '<raw_val_1>' THEN '<clean_label_1>'
        WHEN '<raw_val_2>' THEN '<clean_label_2>'
        ELSE {{ col }}
    END
{% endmacro %}
```
Populate values from the Step 3 distinct value query.

### 5f — Referential integrity test
```jinja
{% macro test_referential_integrity(model, child_col, parent_relation, parent_col) %}
    select {{ child_col }} from {{ model }}
    where {{ child_col }} is not null
      and {{ child_col }} not in (select {{ parent_col }} from {{ parent_relation }})
{% endmacro %}
```

---

## Step 6 — Generate schema.yml

Save as `models/<model_name>/schema.yml`.

```yaml
version: 2

models:
  - name: <model_name>
    description: >
      Auto-generated dbt model for <database>.<schema>.<table>.
    config:
      contract:
        enforced: true
    columns:
      - name: <col_name>
        description: "<data_type> column"
        data_type: <dbt_type>
        constraints:
          - type: not_null    # only if is_nullable = 'NO'
        tests:
          - not_null          # if is_nullable = 'NO'
          - unique            # if PK column
          - accepted_values:  # if distinct_count ≤ 30
              values: [<value_list_from_step3>]
          - dbt_utils.expression_is_true:  # for numeric columns
              expression: "<col> >= 0"
```

---

## Step 7 — Generate sources.yml

Save as `models/<source_name>/sources.yml`.

```yaml
version: 2

sources:
  - name: <source_name>
    database: <database>
    schema: <schema>
    tables:
      - name: <table_name>
        description: "Raw source: <database>.<schema>.<table>"
        loaded_at_field: <timestamp_col_or_omit>
        freshness:
          warn_after:  {count: 24, period: hour}
          error_after: {count: 48, period: hour}
```

---

## Output Format
Emit each file in its own fenced code block, labelled with the filename:
1. `models/<model_name>/<model_name>.sql`
2. `macros/<model_name>_macros.sql`
3. `models/<model_name>/schema.yml`
4. `models/<source_name>/sources.yml`

Then print a short summary: materialization chosen and why, macros generated, and any `<PLACEHOLDER>` values the user must fill in manually.

## Edge Cases
- **No timestamp column**: Use `materialized='table'`, remove incremental block and freshness tests.
- **No PK detected**: Use all columns as `unique_key`, add a warning note.
- **Wide tables (>50 cols)**: Generate `select *` model; still produce full schema.yml.
- **Special characters in column names**: Wrap in double quotes in SQL; use snake_case in YAML.
