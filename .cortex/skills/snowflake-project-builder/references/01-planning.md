# Planning Phase Reference

## Step 1.1 — Gather Object List

Accept any of: FQNs (`DATABASE.SCHEMA.OBJECT_NAME`), partial names (assume `SANDBOX.TPCH`),
wildcards ("all tables in SANDBOX.TPCH" → run `SHOW TABLES IN SCHEMA SANDBOX.TPCH`),
or categories ("all streams", "all tasks", "the warehouse").

If unsure, discover objects:

```sql
SHOW TABLES IN SCHEMA SANDBOX.TPCH;
SHOW VIEWS IN SCHEMA SANDBOX.TPCH;
SHOW STAGES IN SCHEMA SANDBOX.TPCH_LANDING;
SHOW STREAMS IN SCHEMA SANDBOX.TPCH;
SHOW STREAMS IN SCHEMA SANDBOX.TPCH_LANDING;
SHOW TASKS IN SCHEMA SANDBOX.TPCH;
SHOW WAREHOUSES;
SHOW ROLES;
SHOW FILE FORMATS IN SCHEMA SANDBOX.TPCH_LANDING;
SHOW DYNAMIC TABLES IN SCHEMA SANDBOX.TPCH;
SHOW AGENTS IN SCHEMA SANDBOX.TPCH;
SHOW MODELS IN SCHEMA ML_STAGING.MLOPS;
SHOW MODELS IN SCHEMA ML_PROD.MLOPS;
SHOW PROCEDURES IN SCHEMA SANDBOX.TPCH;
SHOW USER FUNCTIONS IN SCHEMA SANDBOX.TPCH;
SHOW DATA METRIC FUNCTIONS IN SCHEMA SANDBOX.TPCH;
SHOW PIPES IN SCHEMA SANDBOX.TPCH_LANDING;
SHOW ALERTS IN SCHEMA SANDBOX.TPCH;
SHOW MASKING POLICIES IN SCHEMA SANDBOX.TPCH;
SHOW ROW ACCESS POLICIES IN SCHEMA SANDBOX.TPCH;
SHOW TAGS IN SCHEMA SANDBOX.TPCH;
SHOW SEQUENCES IN SCHEMA SANDBOX.TPCH;
SHOW SECRETS IN SCHEMA SANDBOX.TPCH_LANDING;
SHOW NETWORK RULES;
SHOW INTEGRATIONS;
```

Present results in a table and let the user pick.

## Step 1.2 — Introspection Commands per Object Type

| Object Type | Introspection Commands |
|---|---|
| TABLE | `DESCRIBE TABLE <fqn>; SELECT GET_DDL('TABLE', '<fqn>');` |
| VIEW | `DESCRIBE VIEW <fqn>; SELECT GET_DDL('VIEW', '<fqn>');` |
| STAGE | `DESCRIBE STAGE <fqn>; SELECT GET_DDL('STAGE', '<fqn>');` |
| STREAM | `SHOW STREAMS LIKE '<name>' IN SCHEMA <db.schema>;` |
| TASK | `SELECT GET_DDL('TASK', '<fqn>'); DESCRIBE TASK <fqn>;` |
| WAREHOUSE | `SHOW WAREHOUSES LIKE '<name>';` |
| FILE FORMAT | `DESCRIBE FILE FORMAT <fqn>; SELECT GET_DDL('FILE_FORMAT', '<fqn>');` |
| ROLE | `SHOW ROLES LIKE '<name>'; SHOW GRANTS TO ROLE <name>;` |
| DYNAMIC TABLE | `DESCRIBE DYNAMIC TABLE <fqn>; SELECT GET_DDL('DYNAMIC_TABLE', '<fqn>');` |
| SCHEMA | `SHOW SCHEMAS LIKE '<name>' IN DATABASE <db>;` |
| AGENT (Cortex Agent) | `SHOW AGENTS IN SCHEMA <db.schema>; DESCRIBE AGENT <fqn>;` |
| ML MODEL | `SHOW MODELS IN SCHEMA <db.schema>; SHOW VERSIONS IN MODEL <fqn>;` |
| STORED PROCEDURE | `SELECT GET_DDL('PROCEDURE', '<fqn>(<arg_types>)'); SHOW PROCEDURES LIKE '<name>' IN SCHEMA <db.schema>;` |
| FUNCTION (UDF) | `SELECT GET_DDL('FUNCTION', '<fqn>(<arg_types>)'); SHOW USER FUNCTIONS LIKE '<name>' IN SCHEMA <db.schema>;` |
| DATA METRIC FUNCTION | `SELECT GET_DDL('FUNCTION', '<fqn>(<arg_types>)'); SHOW DATA METRIC FUNCTIONS IN SCHEMA <db.schema>;` |
| PIPE | `DESCRIBE PIPE <fqn>; SELECT GET_DDL('PIPE', '<fqn>');` |
| ALERT | `DESCRIBE ALERT <fqn>; SHOW ALERTS LIKE '<name>' IN SCHEMA <db.schema>;` |
| MASKING POLICY | `DESCRIBE MASKING POLICY <fqn>; SELECT GET_DDL('POLICY', '<fqn>');` |
| ROW ACCESS POLICY | `DESCRIBE ROW ACCESS POLICY <fqn>; SELECT GET_DDL('POLICY', '<fqn>');` |
| TAG | `SHOW TAGS LIKE '<name>' IN SCHEMA <db.schema>; SELECT TAG_NAME, ALLOWED_VALUES FROM SNOWFLAKE.ACCOUNT_USAGE.TAGS WHERE TAG_NAME = '<name>';` |
| SEQUENCE | `SHOW SEQUENCES LIKE '<name>' IN SCHEMA <db.schema>;` |
| NETWORK RULE | `DESCRIBE NETWORK RULE <name>; SHOW NETWORK RULES;` |
| EXTERNAL ACCESS INTEGRATION | `SHOW EXTERNAL ACCESS INTEGRATIONS LIKE '<name>';` |
| STORAGE INTEGRATION | `DESCRIBE INTEGRATION <name>; SHOW INTEGRATIONS LIKE '<name>';` |
| SECRET | `DESCRIBE SECRET <fqn>; SHOW SECRETS IN SCHEMA <db.schema>;` |

Store the results for use in Phase 2.

## Step 1.3 — Object Classification → Target File

| Classification | Target Location |
|---|---|
| Infrastructure (WAREHOUSE, SCHEMA) | `sources/definitions/infrastructure.sql` |
| Data Tables (TABLE in TPCH schema) | `sources/definitions/tables.sql` |
| Views (VIEW) | `sources/definitions/views.sql` |
| Access Control (ROLE, GRANT) | `sources/definitions/access.sql` |
| Landing Tables (TABLE in TPCH_LANDING) | `ingestion/snowflake/streams.sql` |
| Stages & File Formats | `ingestion/snowflake/stages.sql` |
| Streams | `ingestion/snowflake/streams.sql` |
| Tasks | `ingestion/snowflake/tasks.sql` |
| Stored Procedure (SQL) | `sources/definitions/procedures.sql` |
| Stored Procedure (Snowpark/Python) | `ingestion/snowpark/transforms.py` |
| UDF / UDTF | `sources/definitions/functions.sql` |
| Data Metric Function (DMF) | `sources/definitions/data_quality.sql` |
| Dynamic Table | `sources/definitions/dynamic_tables.sql` |
| Alert | `sources/definitions/alerts.sql` |
| Masking / Row Access Policy | `sources/definitions/policies.sql` |
| Tag | `sources/definitions/tags.sql` |
| Pipe (Snowpipe) | `ingestion/snowflake/pipes.sql` |
| Sequence | `sources/definitions/sequences.sql` |
| Network Rule / EAI | `sources/definitions/network.sql` |
| Storage / Notification Integration | `sources/definitions/integrations.sql` |
| Secret | `sources/definitions/secrets.sql` |
| dbt Source Table | `dbt/models/staging/stg_<name>.sql` + `_sources.yml` |
| dbt Mart | `dbt/models/marts/fct_<name>.sql` or `dim_<name>.sql` |
| Cortex Agent | `agent/agents/<name>/` |
| ML Model | `custom-ml-models/<model_name>-<version>/` |

## Step 1.4 — Dependency Analysis

```sql
-- Streams on a table
SHOW STREAMS IN SCHEMA SANDBOX.TPCH;
-- Tasks referencing a stream
SELECT GET_DDL('TASK', 'SANDBOX.TPCH.<task_name>');
-- View dependencies
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES
WHERE REFERENCED_OBJECT_NAME = '<table_name>'
  AND REFERENCED_OBJECT_DOMAIN = 'TABLE';
```

Build a dependency graph: `TABLE → STREAM → TASK`, `TABLE → VIEW`, `TABLE → dbt staging → mart`

## Step 1.5 — Conflict Detection

```bash
grep -r "DEFINE TABLE.*<OBJECT_NAME>" sources/definitions/
grep -r "DEFINE VIEW.*<OBJECT_NAME>" sources/definitions/
grep -r "DEFINE STREAM.*<OBJECT_NAME>" ingestion/snowflake/
grep -r "<OBJECT_NAME>" dbt/models/
```

If found: ask user — skip (already managed), update (replace with live state), or add alongside.

## Step 1.6 — Plan Presentation

```
┌─────────────────────────────────────────────────────────────────────┐
│ SCAFFOLD PLAN                                                       │
├──────────────────────┬───────────────┬──────────────────────────────┤
│ Object               │ Type          │ Target File                  │
├──────────────────────┼───────────────┼──────────────────────────────┤
│ SANDBOX.TPCH.FOO     │ TABLE         │ sources/definitions/tables.sql│
│ SANDBOX.TPCH.BAR_V   │ VIEW          │ sources/definitions/views.sql │
└──────────────────────┴───────────────┴──────────────────────────────┘

Dependencies detected: FOO → BAR_V (referenced in view)

Files to be MODIFIED (append): sources/definitions/tables.sql
Files to be CREATED (new): dbt/models/staging/stg_foo.sql
```

**⚠️ STOP: Get explicit confirmation before generating. Ask: "Does this plan look correct? Should I also generate dbt models? Any objects to exclude?"**
