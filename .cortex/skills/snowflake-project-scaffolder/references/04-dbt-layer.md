# dbt Transform Layer Reference

## dbt/dbt_project.yml

```yaml
# dbt/dbt_project.yml
name: '{project_name_underscore}'
version: '1.0.0'
config-version: 2

profile: 'default'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"

models:
  '{project_name_underscore}':
    staging:
      +schema: '{SCHEMA}'
      +materialized: view
      +tags: ['staging']
    intermediate:
      +schema: '{SCHEMA}'
      +materialized: ephemeral
    marts:
      +schema: '{SCHEMA}'
      +materialized: table
      +tags: ['mart']
```

## dbt/profiles.yml.example

```yaml
# dbt/profiles.yml.example
# Copy to profiles.yml (or ~/.dbt/profiles.yml) — NEVER COMMIT profiles.yml
default:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: '{ACCOUNT}'
      user: '{SERVICE_USER}'
      authenticator: 'PROGRAMMATIC_ACCESS_TOKEN'
      token: ''           # Set via environment variable DBT_SNOWFLAKE_PAT
      role: '{DEFAULT_ROLE}'
      database: '{DATABASE}'
      warehouse: '{WAREHOUSE}'
      schema: '{SCHEMA}'
      threads: 4
      client_session_keep_alive: false

    prod:
      type: snowflake
      account: '{ACCOUNT}'
      user: '{SERVICE_USER}'
      authenticator: 'PROGRAMMATIC_ACCESS_TOKEN'
      token: ''
      role: '{DEFAULT_ROLE}'
      database: '{DATABASE}'
      warehouse: '{WAREHOUSE}'
      schema: '{SCHEMA}'
      threads: 8
```

## dbt/packages.yml

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
  - package: calogica/dbt_expectations
    version: [">=0.10.0", "<1.0.0"]
```

## dbt/models/staging/stg_{table_name_lower}.sql

```sql
-- dbt/models/staging/stg_{table_name_lower}.sql
{{{{ config(materialized='view', tags=['staging']) }}}}

WITH source AS (
    SELECT * FROM {{{{ source('{project_name_underscore}', '{TABLE_NAME}') }}}}
),

renamed AS (
    SELECT
        id                                    AS {table_name_lower}_id,
        -- TODO: add column renames
        CURRENT_TIMESTAMP()                   AS _LOADED_AT,
        '{DATABASE}.{SCHEMA}.{TABLE_NAME}'    AS _SOURCE_SYSTEM
    FROM source
)

SELECT * FROM renamed
```

## dbt/models/marts/mart_{table_name_lower}_enriched.sql

```sql
-- dbt/models/marts/mart_{table_name_lower}_enriched.sql
{{{{ config(
    materialized = 'table',
    tags         = ['mart'],
    cluster_by   = ['{table_name_lower}_id']
) }}}}

WITH base AS (
    SELECT * FROM {{{{ ref('stg_{table_name_lower}') }}}}
),

enriched AS (
    SELECT
        b.*
        -- TODO: joins and business logic here
    FROM base b
)

SELECT * FROM enriched
```

## dbt/models/staging/sources.yml

```yaml
# dbt/models/staging/sources.yml
version: 2

sources:
  - name: '{project_name_underscore}'
    database: '{DATABASE}'
    schema: '{SCHEMA}'
    tables:
      - name: '{TABLE_NAME}'
        description: 'Raw {TABLE_NAME} landing table'
        columns:
          - name: id
            description: 'Primary key'
            tests:
              - not_null
              - unique

models:
  - name: stg_{table_name_lower}
    description: 'Staged view over {TABLE_NAME}'
    columns:
      - name: {table_name_lower}_id
        tests:
          - not_null
          - unique
```
