---
name: snowflake-project-builder
description: "Introspect Snowflake objects (tables, views, stages, streams, tasks, warehouses, roles, Cortex Agents, ML models) from the live account and scaffold them into the snowflake-project repository structure following DCM, dbt, AgentOps, and MLOps conventions. Triggers: build object, scaffold table, add to project, import from snowflake, onboard object, reverse-engineer DDL, add table to DCM, add stream, add task, scaffold dbt model, scaffold agent, new agent, add ML model, onboard model, register model, create agent spec."
tools:
  - snowflake_sql_execute
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Snowflake Project Builder

Reverse-engineers live Snowflake objects and scaffolds them into the `snowflake-project` repository following all existing conventions: DCM `DEFINE` syntax, dbt model patterns, ingestion config, and naming standards.

---

## When to Use

- User wants to add an existing Snowflake object to the project as code
- User says "add this table to the project", "scaffold a dbt model for X", "import this stream"
- User provides Snowflake FQNs (e.g., `SANDBOX.TPCH.MY_TABLE`) and wants them managed in the repo
- User wants to reverse-engineer DDL into DCM definitions
- User wants to onboard new objects discovered in Snowflake into version control

---

## Project Root

The target project is located at: `/Users/kannannvelmurugiah/Desktop/snowflake-project`

All file paths below are relative to this root unless otherwise stated.

---

## PHASE 1: Planning (Mandatory — Do Not Skip)

### Step 1.1 — Gather Object List

Ask the user which Snowflake objects to scaffold. Accept any of:

- Fully qualified names: `DATABASE.SCHEMA.OBJECT_NAME`
- Partial names: `OBJECT_NAME` (assume `SANDBOX.TPCH` unless told otherwise)
- Wildcards: "all tables in SANDBOX.TPCH" → run `SHOW TABLES IN SCHEMA SANDBOX.TPCH`
- Categories: "all streams", "all tasks", "the warehouse"

If the user is unsure, offer to discover objects:

```sql
-- Tables
SHOW TABLES IN SCHEMA SANDBOX.TPCH;
-- Views
SHOW VIEWS IN SCHEMA SANDBOX.TPCH;
-- Stages
SHOW STAGES IN SCHEMA SANDBOX.TPCH_LANDING;
-- Streams
SHOW STREAMS IN SCHEMA SANDBOX.TPCH;
SHOW STREAMS IN SCHEMA SANDBOX.TPCH_LANDING;
-- Tasks
SHOW TASKS IN SCHEMA SANDBOX.TPCH;
-- Warehouses
SHOW WAREHOUSES;
-- Roles
SHOW ROLES;
-- File Formats
SHOW FILE FORMATS IN SCHEMA SANDBOX.TPCH_LANDING;
-- Dynamic Tables
SHOW DYNAMIC TABLES IN SCHEMA SANDBOX.TPCH;
-- Cortex Agents
SHOW AGENTS IN SCHEMA SANDBOX.TPCH;
-- ML Models (Snowflake Model Registry)
SHOW MODELS IN SCHEMA ML_STAGING.MLOPS;
SHOW MODELS IN SCHEMA ML_PROD.MLOPS;
-- Stored Procedures
SHOW PROCEDURES IN SCHEMA SANDBOX.TPCH;
-- User-Defined Functions
SHOW USER FUNCTIONS IN SCHEMA SANDBOX.TPCH;
-- Data Metric Functions
SHOW DATA METRIC FUNCTIONS IN SCHEMA SANDBOX.TPCH;
-- Pipes
SHOW PIPES IN SCHEMA SANDBOX.TPCH_LANDING;
-- Alerts
SHOW ALERTS IN SCHEMA SANDBOX.TPCH;
-- Masking Policies
SHOW MASKING POLICIES IN SCHEMA SANDBOX.TPCH;
-- Row Access Policies
SHOW ROW ACCESS POLICIES IN SCHEMA SANDBOX.TPCH;
-- Tags
SHOW TAGS IN SCHEMA SANDBOX.TPCH;
-- Sequences
SHOW SEQUENCES IN SCHEMA SANDBOX.TPCH;
-- Secrets
SHOW SECRETS IN SCHEMA SANDBOX.TPCH_LANDING;
-- Network Rules
SHOW NETWORK RULES;
-- Integrations
SHOW INTEGRATIONS;
```

Present the results in a table and let the user pick.

### Step 1.2 — Introspect Each Object

For each selected object, run the appropriate introspection commands:

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
| ML MODEL (Snowflake Model Registry) | `SHOW MODELS IN SCHEMA <db.schema>; SHOW VERSIONS IN MODEL <fqn>;` |
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

Store the results for use in generation.

### Step 1.3 — Classify Objects

Assign each object to a project pillar and target file:

| Classification | Target Location |
|---|---|
| Infrastructure (WAREHOUSE, SCHEMA) | `sources/definitions/infrastructure.sql` |
| Data Tables (TABLE in TPCH schema) | `sources/definitions/tables.sql` |
| Views (VIEW) | `sources/definitions/views.sql` |
| Access Control (ROLE, GRANT) | `sources/definitions/access.sql` |
| Landing Tables (TABLE in TPCH_LANDING) | `ingestion/snowflake/streams.sql` (alongside stream DEFINEs) |
| Stages & File Formats | `ingestion/snowflake/stages.sql` |
| Streams | `ingestion/snowflake/streams.sql` |
| Tasks | `ingestion/snowflake/tasks.sql` |
| Stored Procedure (SQL) | `sources/definitions/procedures.sql` |
| Stored Procedure (Snowpark) | `ingestion/snowpark/transforms.py` |
| UDF / UDTF | `sources/definitions/functions.sql` |
| Data Metric Function (DMF) | `sources/definitions/data_quality.sql` |
| Dynamic Table | `sources/definitions/dynamic_tables.sql` |
| Alert | `sources/definitions/alerts.sql` |
| Masking / Row Access Policy | `sources/definitions/policies.sql` |
| Tag | `sources/definitions/tags.sql` |
| Pipe (Snowpipe) | `ingestion/snowflake/pipes.sql` |
| Sequence | `sources/definitions/sequences.sql` |
| Network Rule / EAI | `sources/definitions/network.sql` or `ingestion/openflow/setup/` |
| Storage / Notification Integration | `sources/definitions/integrations.sql` |
| Secret | `sources/definitions/secrets.sql` |
| dbt Source Table | `dbt/models/staging/stg_<name>.sql` + `_sources.yml` + `_staging.yml` |
| dbt Mart | `dbt/models/marts/fct_<name>.sql` or `dim_<name>.sql` + `_marts.yml` |
| Cortex Agent | `agent/agents/<name>/` (agent.yml + specs + prompts + evals + monitoring) |
| ML Model | `custom-ml-models/<model_name>-<version>/` (spec + card + SQL + release notes) |

### Step 1.4 — Dependency Analysis

Trace relationships between objects:

```sql
-- Find streams on a table
SHOW STREAMS IN SCHEMA SANDBOX.TPCH;
-- Check which tasks reference a stream
SELECT GET_DDL('TASK', 'SANDBOX.TPCH.<task_name>');
-- Check view dependencies
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES
WHERE REFERENCED_OBJECT_NAME = '<table_name>'
  AND REFERENCED_OBJECT_DOMAIN = 'TABLE';
```

Build a dependency graph:
```
TABLE → STREAM → TASK
TABLE → VIEW
TABLE → dbt staging model → intermediate → mart
```

### Step 1.5 — Conflict Check

Before generating, check if the object already exists in the project:

```bash
grep -r "DEFINE TABLE.*<OBJECT_NAME>" sources/definitions/
grep -r "DEFINE VIEW.*<OBJECT_NAME>" sources/definitions/
grep -r "DEFINE STREAM.*<OBJECT_NAME>" ingestion/snowflake/
grep -r "<OBJECT_NAME>" dbt/models/
```

If found, inform the user and ask whether to:
1. Skip (object already managed)
2. Update (replace existing definition with live state)
3. Add alongside (create a new version)

### Step 1.6 — Present Plan

Show a summary table:

```
┌─────────────────────────────────────────────────────────────────────┐
│ SCAFFOLD PLAN                                                       │
├──────────────────────┬───────────────┬──────────────────────────────┤
│ Object               │ Type          │ Target File                  │
├──────────────────────┼───────────────┼──────────────────────────────┤
│ SANDBOX.TPCH.FOO     │ TABLE         │ sources/definitions/tables.sql│
│ SANDBOX.TPCH.BAR_V   │ VIEW          │ sources/definitions/views.sql │
│ SANDBOX.TPCH.CDC_STR │ STREAM        │ ingestion/snowflake/streams.sql│
│ (dbt) FOO            │ staging model │ dbt/models/staging/stg_foo.sql│
└──────────────────────┴───────────────┴──────────────────────────────┘

Dependencies detected:
  FOO → CDC_STR (stream on table)
  FOO → BAR_V  (referenced in view)

Files to be MODIFIED (append):
  - sources/definitions/tables.sql
  - sources/definitions/views.sql
  - ingestion/snowflake/streams.sql

Files to be CREATED (new):
  - dbt/models/staging/stg_foo.sql
  - dbt/models/staging/_sources.yml (update)
```

**STOP**: Get explicit user confirmation before proceeding to Phase 2.

Ask: "Does this plan look correct? Should I also generate dbt models for any of the tables? Any objects to exclude?"

---

## PHASE 2: Generation

### 2.1 — DCM Table Definition

For each TABLE, generate a `DEFINE TABLE` block and APPEND to `sources/definitions/tables.sql`:

```sql
DEFINE TABLE <DATABASE>.<SCHEMA>.<TABLE_NAME> (
    <COLUMN_NAME> <DATA_TYPE> [NOT NULL] [DEFAULT <expr>],
    ...
)
    COMMENT = '<comment from SHOW TABLES or user-provided>'
    [CHANGE_TRACKING = TRUE]    -- if streams exist on this table
    [CLUSTER BY (<keys>)];      -- if clustering info found
```

**Rules:**
- Use UPPER_SNAKE_CASE for all identifiers
- Preserve original column order from DESCRIBE
- Include `NOT NULL` only if the column is marked NOT NULL in DESCRIBE
- Include `DEFAULT` only if a non-null default exists
- Add `CHANGE_TRACKING = TRUE` if any stream references this table
- Add `COMMENT` from the table's comment metadata
- Add `{{env_suffix}}` templating ONLY to objects that are environment-specific (roles, warehouses) — NOT to data tables

### 2.2 — DCM View Definition

For each VIEW, generate a `DEFINE VIEW` block and APPEND to `sources/definitions/views.sql`:

```sql
DEFINE VIEW <DATABASE>.<SCHEMA>.<VIEW_NAME> AS
    <full SELECT body from GET_DDL>;
```

**Rules:**
- Extract only the SELECT portion from GET_DDL (strip `CREATE OR REPLACE VIEW ... AS`)
- Preserve formatting and indentation
- Ensure all referenced tables use fully-qualified names

### 2.3 — DCM Infrastructure

For WAREHOUSE objects, APPEND to `sources/definitions/infrastructure.sql`:

```sql
DEFINE WAREHOUSE <DATABASE>.<SCHEMA>.<WH_NAME>{{env_suffix}}
    WAREHOUSE_SIZE = '{{wh_size}}'
    AUTO_SUSPEND = <seconds>
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;
```

For SCHEMA objects:
```sql
DEFINE SCHEMA <DATABASE>.<SCHEMA_NAME>
    COMMENT = '<comment>';
```

### 2.4 — DCM Access Control

For ROLE objects, APPEND to `sources/definitions/access.sql`:

```sql
DEFINE ROLE <DATABASE>.<SCHEMA>.<ROLE_NAME>{{env_suffix}};

GRANT USAGE ON WAREHOUSE <wh_fqn>{{env_suffix}}
    TO ROLE <DATABASE>.<SCHEMA>.<ROLE_NAME>{{env_suffix}};

GRANT SELECT ON TABLE <table_fqn>
    TO ROLE <DATABASE>.<SCHEMA>.<ROLE_NAME>{{env_suffix}};
```

### 2.5 — Ingestion: Stages & File Formats

For STAGE and FILE FORMAT objects, APPEND to `ingestion/snowflake/stages.sql`:

```sql
-- File format
DEFINE FILE FORMAT <DATABASE>.<SCHEMA>.<FORMAT_NAME>
    TYPE = <type>
    <properties from GET_DDL>;

-- External stage
DEFINE STAGE <DATABASE>.<SCHEMA>.<STAGE_NAME>
    URL = '<url>'
    STORAGE_INTEGRATION = <integration_name>
    FILE_FORMAT = <DATABASE>.<SCHEMA>.<FORMAT_NAME>
    COMMENT = '<comment>';
```

### 2.6 — Ingestion: Streams

For STREAM objects, APPEND to `ingestion/snowflake/streams.sql`:

```sql
DEFINE STREAM <DATABASE>.<SCHEMA>.<STREAM_NAME>
    ON TABLE <source_table_fqn>
    [APPEND_ONLY = TRUE]
    [SHOW_INITIAL_ROWS = TRUE]
    COMMENT = '<comment>';
```

**Rules:**
- Include `APPEND_ONLY = TRUE` if the stream mode is APPEND_ONLY
- Include `SHOW_INITIAL_ROWS = TRUE` if present in the source DDL
- If the source table is a landing table, also generate its `DEFINE TABLE` in this same file (following existing pattern in `streams.sql`)

### 2.7 — Ingestion: Tasks

For TASK objects, APPEND to `ingestion/snowflake/tasks.sql`:

```sql
CREATE OR REPLACE TASK <DATABASE>.<SCHEMA>.<TASK_NAME>
    WAREHOUSE = <warehouse>
    [SCHEDULE = '<schedule>']
    [AFTER <predecessor_task_fqn>]
    [WHEN <condition>]
    COMMENT = '<comment>'
AS
    <task body SQL>;
```

**Note:** Tasks use `CREATE OR REPLACE` (not `DEFINE`) because DCM does not manage tasks — they are imperative objects deployed by the CI/CD pipeline directly.

### 2.7a — Procedural Objects (Non-DCM)

The following Snowflake objects are **NOT managed by DCM** (no `DEFINE` syntax exists for them). They are deployed as imperative `CREATE OR REPLACE` SQL scripts, organized by purpose.

**Classification and placement rules:**

| Object Type | Target File/Directory | Deploy Method |
|---|---|---|
| Stored Procedure (SQL) | `sources/definitions/procedures.sql` | Imperative SQL in CI |
| Stored Procedure (Snowpark/Python) | `ingestion/snowpark/transforms.py` | `snow snowpark deploy` or Python registration |
| User-Defined Function (SQL UDF) | `sources/definitions/functions.sql` | Imperative SQL in CI |
| User-Defined Function (Python/Java UDF) | `sources/definitions/functions.sql` (SQL wrapper) or Snowpark deploy | Imperative SQL or `snow snowpark deploy` |
| Data Metric Function (DMF) | `sources/definitions/data_quality.sql` | Imperative SQL in CI |
| Dynamic Table | `sources/definitions/dynamic_tables.sql` | Imperative SQL in CI |
| Alert | `sources/definitions/alerts.sql` | Imperative SQL in CI |
| Masking Policy | `sources/definitions/policies.sql` | Imperative SQL in CI |
| Row Access Policy | `sources/definitions/policies.sql` | Imperative SQL in CI |
| Aggregation Policy | `sources/definitions/policies.sql` | Imperative SQL in CI |
| Tag | `sources/definitions/tags.sql` | Imperative SQL in CI |
| Pipe (Snowpipe) | `ingestion/snowflake/pipes.sql` | Imperative SQL in CI |
| Sequence | `sources/definitions/sequences.sql` | Imperative SQL in CI |
| Network Rule | `ingestion/openflow/setup/` or `sources/definitions/network.sql` | Imperative SQL (ACCOUNTADMIN) |
| External Access Integration | `ingestion/openflow/setup/` or `sources/definitions/network.sql` | Imperative SQL (ACCOUNTADMIN) |
| Secret | `ingestion/openflow/setup/` or `sources/definitions/secrets.sql` | Imperative SQL (ACCOUNTADMIN) |
| Notification Integration | `sources/definitions/integrations.sql` | Imperative SQL (ACCOUNTADMIN) |
| Storage Integration | `sources/definitions/integrations.sql` | Imperative SQL (ACCOUNTADMIN) |

---

#### 2.7a.1 — Stored Procedures (SQL)

**File: `sources/definitions/procedures.sql`** — APPEND

```sql
-- ============================================================
-- Stored Procedures
-- These are imperative objects deployed via CI (CREATE OR REPLACE).
-- DCM does not manage procedures.
-- ============================================================

CREATE OR REPLACE PROCEDURE <DATABASE>.<SCHEMA>.<PROCEDURE_NAME>(
    <param_name> <param_type> [DEFAULT <default>]
)
RETURNS <return_type>
LANGUAGE SQL
[EXECUTE AS CALLER | OWNER]
COMMENT = '<comment>'
AS
$$
BEGIN
    <procedure_body>;
END;
$$;
```

**Rules:**
- Use `EXECUTE AS CALLER` for read-only reporting procs, `EXECUTE AS OWNER` for privileged operations
- Always include a `COMMENT`
- Parameters use UPPER_SNAKE_CASE
- For procs that reference variables in SQL statements inside the body, use colon prefix (`:param_name`)

#### 2.7a.2 — Stored Procedures (Snowpark/Python)

**File: `ingestion/snowpark/transforms.py`** — ADD function + register call

For Snowpark stored procedures, the pattern is:
1. Write the Python function in `ingestion/snowpark/transforms.py`
2. Add a `session.sproc.register()` call in the `register_procedures()` function

```python
def <function_name>(session: Session) -> str:
    """
    Stored procedure: <description>.
    """
    df = session.table("<SOURCE_TABLE_FQN>")
    # ... transformation logic ...
    df.write.mode("overwrite").save_as_table("<TARGET_TABLE_FQN>")
    return f"Processed {df.count()} records"
```

Registration (add inside `register_procedures()`):
```python
session.sproc.register(
    func=<function_name>,
    name="<DATABASE>.<SCHEMA>.<PROCEDURE_NAME>",
    replace=True,
    is_permanent=True,
    stage_location="@SANDBOX.TPCH_LANDING.SNOWPARK_OUTPUT_STAGE",
    packages=["snowflake-snowpark-python"],
    comment="<description>",
)
```

#### 2.7a.3 — User-Defined Functions (UDFs)

**File: `sources/definitions/functions.sql`** — APPEND (create if missing)

```sql
-- ============================================================
-- User-Defined Functions
-- Imperative objects deployed via CI (CREATE OR REPLACE).
-- ============================================================

-- SQL UDF
CREATE OR REPLACE FUNCTION <DATABASE>.<SCHEMA>.<FUNCTION_NAME>(
    <param_name> <param_type>
)
RETURNS <return_type>
LANGUAGE SQL
COMMENT = '<comment>'
AS
$$
    <function_body>
$$;

-- Python UDF (inline)
CREATE OR REPLACE FUNCTION <DATABASE>.<SCHEMA>.<FUNCTION_NAME>(
    <param_name> <param_type>
)
RETURNS <return_type>
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = '<handler_function_name>'
COMMENT = '<comment>'
AS
$$
def <handler_function_name>(<param>):
    <python_body>
    return <result>
$$;
```

#### 2.7a.4 — Data Metric Functions (DMFs)

**File: `sources/definitions/data_quality.sql`** — APPEND (create if missing)

```sql
-- ============================================================
-- Data Metric Functions (DMFs)
-- Attached to tables for automated data quality monitoring.
-- Imperative objects deployed via CI.
-- ============================================================

CREATE OR REPLACE DATA METRIC FUNCTION <DATABASE>.<SCHEMA>.<DMF_NAME>(
    ARG_T TABLE(
        <column_name> <column_type>
    )
)
RETURNS NUMBER
COMMENT = '<comment>'
AS
$$
    SELECT COUNT_IF(<column_name> IS NULL) FROM ARG_T
$$;

-- Attach to table (run separately after table exists):
-- ALTER TABLE <TABLE_FQN>
--   SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES'
--   ADD DATA METRIC FUNCTION <DATABASE>.<SCHEMA>.<DMF_NAME>
--     ON (<column_name>);
```

**DMF patterns to generate based on column type:**

| Column Pattern | DMF Type | Template |
|---|---|---|
| NOT NULL column | null_count | `COUNT_IF(col IS NULL)` |
| Unique/PK column | duplicate_count | `COUNT(*) - COUNT(DISTINCT col)` |
| Email column | invalid_email_count | `COUNT_IF(NOT RLIKE(col, '^[a-zA-Z0-9._%+-]+@...'))` |
| Numeric column | out_of_range_count | `COUNT_IF(col < min OR col > max)` |
| Date column | future_date_count | `COUNT_IF(col > CURRENT_DATE())` |
| FK column | orphan_count | `COUNT_IF(col NOT IN (SELECT pk FROM parent))` |
| Status/enum column | invalid_value_count | `COUNT_IF(col NOT IN ('VAL1', 'VAL2', ...))` |

#### 2.7a.5 — Dynamic Tables

**File: `sources/definitions/dynamic_tables.sql`** — APPEND (create if missing)

```sql
-- ============================================================
-- Dynamic Tables
-- Auto-refreshing materialized views (Snowflake-managed pipeline).
-- Imperative objects deployed via CI.
-- ============================================================

CREATE OR REPLACE DYNAMIC TABLE <DATABASE>.<SCHEMA>.<DT_NAME>
    TARGET_LAG = '<lag>'       -- e.g., '1 hour', '5 minutes', 'DOWNSTREAM'
    WAREHOUSE = <WAREHOUSE>
    COMMENT = '<comment>'
AS
    <SELECT statement>;
```

**When to use Dynamic Tables vs dbt incremental:**
- Use Dynamic Tables when: real-time/near-real-time refresh needed, no complex incremental logic, Snowflake-native pipeline preferred
- Use dbt incremental when: complex merge logic, needs dbt lineage/testing, batch cadence acceptable

#### 2.7a.6 — Alerts

**File: `sources/definitions/alerts.sql`** — APPEND (create if missing)

```sql
-- ============================================================
-- Snowflake Alerts
-- Automated monitoring and notification on conditions.
-- Imperative objects deployed via CI.
-- ============================================================

CREATE OR REPLACE ALERT <DATABASE>.<SCHEMA>.<ALERT_NAME>
    WAREHOUSE = <WAREHOUSE>
    SCHEDULE = '<schedule>'    -- e.g., '15 MINUTES', 'USING CRON ...'
    COMMENT = '<comment>'
    IF (EXISTS (
        <condition_query>
    ))
THEN
    CALL SYSTEM$SEND_EMAIL(
        '<notification_integration>',
        '<recipients>',
        '<subject>',
        '<body>'
    );

-- Resume after creation:
-- ALTER ALERT <DATABASE>.<SCHEMA>.<ALERT_NAME> RESUME;
```

#### 2.7a.7 — Policies (Masking, Row Access, Aggregation)

**File: `sources/definitions/policies.sql`** — APPEND (create if missing)

```sql
-- ============================================================
-- Security Policies
-- Masking, Row Access, and Aggregation Policies.
-- Imperative objects deployed via CI.
-- ============================================================

-- Masking Policy
CREATE OR REPLACE MASKING POLICY <DATABASE>.<SCHEMA>.<POLICY_NAME>
AS (VAL <data_type>)
RETURNS <data_type> ->
    CASE
        WHEN CURRENT_ROLE() IN ('<privileged_role>') THEN VAL
        ELSE '<masked_value>'
    END
COMMENT = '<comment>';

-- Apply: ALTER TABLE <table> ALTER COLUMN <col> SET MASKING POLICY <policy>;

-- Row Access Policy
CREATE OR REPLACE ROW ACCESS POLICY <DATABASE>.<SCHEMA>.<POLICY_NAME>
AS (<column_name> <data_type>)
RETURNS BOOLEAN ->
    <condition_expression>
COMMENT = '<comment>';

-- Apply: ALTER TABLE <table> ADD ROW ACCESS POLICY <policy> ON (<column>);
```

#### 2.7a.8 — Tags

**File: `sources/definitions/tags.sql`** — APPEND (create if missing)

```sql
-- ============================================================
-- Object Tags
-- Classification and governance tags for discovery and policy.
-- Imperative objects deployed via CI.
-- ============================================================

CREATE OR REPLACE TAG <DATABASE>.<SCHEMA>.<TAG_NAME>
    ALLOWED_VALUES = '<value1>', '<value2>'
    COMMENT = '<comment>';

-- Apply to table:
-- ALTER TABLE <table> SET TAG <DATABASE>.<SCHEMA>.<TAG_NAME> = '<value>';
-- Apply to column:
-- ALTER TABLE <table> ALTER COLUMN <col> SET TAG <DATABASE>.<SCHEMA>.<TAG_NAME> = '<value>';
```

#### 2.7a.9 — Pipes (Snowpipe)

**File: `ingestion/snowflake/pipes.sql`** — APPEND (create if missing)

```sql
-- ============================================================
-- Snowpipe — Continuous auto-ingestion
-- Imperative objects deployed via CI.
-- ============================================================

CREATE OR REPLACE PIPE <DATABASE>.<SCHEMA>.<PIPE_NAME>
    AUTO_INGEST = TRUE
    COMMENT = '<comment>'
AS
    COPY INTO <DATABASE>.<SCHEMA>.<TARGET_TABLE>
    FROM @<STAGE_FQN>
    FILE_FORMAT = <FILE_FORMAT_FQN>
    [MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE];
```

#### 2.7a.10 — Sequences

**File: `sources/definitions/sequences.sql`** — APPEND (create if missing)

```sql
-- ============================================================
-- Sequences
-- Imperative objects deployed via CI.
-- ============================================================

CREATE OR REPLACE SEQUENCE <DATABASE>.<SCHEMA>.<SEQUENCE_NAME>
    START = 1
    INCREMENT = 1
    COMMENT = '<comment>';
```

#### 2.7a.11 — Network Rules, EAIs, Integrations, Secrets

**File: `sources/definitions/network.sql`** (for account-level networking) — OR — `ingestion/openflow/setup/` if specific to Openflow.

```sql
-- ============================================================
-- Network Rules & External Access Integrations
-- Requires ACCOUNTADMIN. Deployed via CI with elevated role.
-- ============================================================

CREATE OR REPLACE NETWORK RULE <RULE_NAME>
    TYPE = HOST_PORT
    MODE = EGRESS
    VALUE_LIST = ('<host1>:<port>', '<host2>')
    COMMENT = '<comment>';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION <EAI_NAME>
    ALLOWED_NETWORK_RULES = (<RULE_NAME>)
    ENABLED = TRUE
    COMMENT = '<comment>';

GRANT USAGE ON INTEGRATION <EAI_NAME> TO ROLE <role>;
```

**File: `sources/definitions/integrations.sql`** — for storage and notification integrations:

```sql
-- Storage Integration (for external stages)
CREATE OR REPLACE STORAGE INTEGRATION <INTEGRATION_NAME>
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    STORAGE_AWS_ROLE_ARN = '<arn>'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = ('<s3_path>')
    COMMENT = '<comment>';

-- Notification Integration (for alerts, pipes)
CREATE OR REPLACE NOTIFICATION INTEGRATION <INTEGRATION_NAME>
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('<email1>', '<email2>')
    COMMENT = '<comment>';
```

**File: `sources/definitions/secrets.sql`** — for Snowflake Secrets:

```sql
-- ============================================================
-- Secrets
-- Never store actual secret values in code — use placeholders.
-- Actual values are set via Snowsight or CI secrets injection.
-- ============================================================

CREATE OR REPLACE SECRET <DATABASE>.<SCHEMA>.<SECRET_NAME>
    TYPE = GENERIC_STRING
    SECRET_STRING = ''     -- PLACEHOLDER — set actual value in Snowsight
    COMMENT = '<comment>';

GRANT USAGE ON SECRET <DATABASE>.<SCHEMA>.<SECRET_NAME> TO ROLE <role>;
```

**IMPORTANT:** NEVER include actual secret values in generated code. Always use empty placeholders with a comment directing to Snowsight.

---

### 2.8 — dbt Staging Model

If the user requests dbt models for a table:

**File: `dbt/models/staging/stg_<lowercase_table_name>.sql`**
```sql
{{
    config(
        materialized = 'view',
        tags = ['staging', '<table_name_lower>']
    )
}}

with source as (
    select * from {{ source('tpch_raw', '<TABLE_NAME>') }}
),

renamed as (
    select
        <column_name_lower>  as <cleaned_column_name>,
        ...
    from source
),

validated as (
    select *
    from renamed
    where <primary_key_column> is not null
)

select * from validated
```

**Naming rules for dbt columns:**
- Lowercase all column names
- Remove leading underscores from non-audit columns
- Trim `trim(name)` pattern for VARCHAR columns
- `lower(trim(email))` pattern for email columns
- Rename `CUSTOMER_ID` → `customer_id` (just lowercase, preserve name)

**Update `dbt/models/staging/_sources.yml`** — add new table entry under the `tpch_raw` source if not already present.

**Update or create `dbt/models/staging/_staging.yml`** — add model documentation:
```yaml
models:
  - name: stg_<table_name_lower>
    description: "Staging view for <TABLE_NAME> — 1:1 source mirror with cleaning"
    columns:
      - name: <pk_column>
        description: "Primary key"
        tests:
          - not_null
          - unique
```

### 2.9 — dbt Mart Model (if requested)

**File: `dbt/models/marts/fct_<name>.sql` or `dim_<name>.sql`**
```sql
{{
    config(
        materialized = 'incremental',
        unique_key = '<pk>',
        incremental_strategy = 'merge',
        cluster_by = ['<cluster_key>'],
        tags = ['marts', '<domain>'],
        on_schema_change = 'sync_all_columns'
    )
}}

with base as (
    select * from {{ ref('<upstream_model>') }}

    {% if is_incremental() %}
    where <timestamp_col> >= dateadd(
        hour,
        -{{ var('incremental_lookback_hours', 48) }},
        current_timestamp()
    )
    {% endif %}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['<pk>']) }} as <table>_sk,
        <columns>,
        current_timestamp() as dbt_updated_at
    from base
)

select * from final
```

### 2.10 — AgentOps: Cortex Agent Scaffold (Multi-Agent Structure)

The project supports **multiple agents** via a shared infrastructure pattern. Each agent is self-contained under `agent/agents/<agent-name>/` and is auto-discovered by the shared `deploy_all.py` and `run_evals.py` scripts.

**Discovery (if agent exists in Snowflake):**
```sql
SHOW AGENTS IN SCHEMA SANDBOX.TPCH;
DESCRIBE AGENT SANDBOX.TPCH.<AGENT_NAME>;
```

If the agent exists, extract:
- Agent spec JSON (from `DESCRIBE AGENT` output)
- Tool definitions and tool_resources
- Instruction prompts (orchestration + response)
- Semantic views or warehouses referenced

If creating from scratch, ask the user for:
```
1. Agent folder name (lowercase-kebab, e.g., sales-analyst)
2. Agent Snowflake name (UPPER_SNAKE_CASE, e.g., SALES_ANALYST)
3. Agent FQN (e.g., SANDBOX.TPCH.SALES_ANALYST)
4. Database and schema it operates in
5. Description (one line)
6. Owner team
7. Tools — what type? (cortex_analyst_text_to_sql, cortex_search, data_to_chart, code_interpreter)
8. Semantic view or table it queries
9. LLM model preference (default: "auto")
```

**Directory structure to create:**

```
agent/
├── deploy_all.py              # SHARED — do NOT create (already exists)
├── run_evals.py               # SHARED — do NOT create (already exists)
└── agents/
    └── <agent-name>/          # NEW agent folder (lowercase-kebab)
        ├── agent.yml          # Identity: name, fqn, database, schema, owner
        ├── specs/
        │   ├── README.md      # Spec versioning policy
        │   └── v1/
        │       ├── agent_spec.json   # Immutable versioned spec
        │       └── metadata.yml      # Version, status, changelog
        ├── prompts/
        │   ├── orchestration.md      # System prompt: scope, tool rules, safety
        │   └── response.md           # Output formatting rules
        ├── evals/
        │   ├── eval_config.yaml      # Judge model, thresholds, connection
        │   ├── ground_truth.json     # Q&A pairs for LLM-as-judge scoring
        │   └── results/.gitkeep      # Results output directory (gitignored)
        └── monitoring/
            ├── alert_policy.yml      # Alert thresholds and notification config
            └── usage_queries.sql     # Invocation, latency, credit, error queries
```

**IMPORTANT:** The shared scripts `agent/deploy_all.py` and `agent/run_evals.py` already exist and auto-discover agents via `agent/agents/*/agent.yml`. Do NOT recreate them. Just add the new agent folder.

---

**File: `agent/agents/<agent-name>/agent.yml`** — Agent identity (REQUIRED)
```yaml
name: <AGENT_NAME>
fqn: <DATABASE>.<SCHEMA>.<AGENT_NAME>
database: <DATABASE>
schema: <SCHEMA>
description: "<What this agent does>"
owner: <team-name>
```

This file is the discovery anchor. Without it, the agent won't be found by `deploy_all.py` or `run_evals.py`.

---

**File: `agent/agents/<agent-name>/specs/v1/agent_spec.json`**
```json
{
  "models": {
    "orchestration": "auto"
  },
  "orchestration": {
    "budget": {
      "seconds": 900,
      "tokens": 400000
    }
  },
  "instructions": {
    "orchestration": "",
    "response": ""
  },
  "tools": [
    {
      "tool_spec": {
        "type": "<tool_type>",
        "name": "<tool_name>",
        "description": "<tool_description>"
      }
    }
  ],
  "tool_resources": {
    "<tool_name>": {
      "execution_environment": {
        "query_timeout": 299,
        "type": "warehouse",
        "warehouse": ""
      },
      "semantic_view": "<SEMANTIC_VIEW_FQN>"
    }
  }
}
```

---

**File: `agent/agents/<agent-name>/specs/v1/metadata.yml`**
```yaml
version: "1.0.0"
released: "<YYYY-MM-DD>"
status: "draft"
agent_name: "<AGENT_NAME>"
fqn: "<DATABASE>.<SCHEMA>.<AGENT_NAME>"
description: >
  <Description of this agent version>
breaking_changes: []
changelog:
  - "<Change 1>"
```

---

**File: `agent/agents/<agent-name>/specs/README.md`**
```markdown
# Agent Spec Versioning

Each subdirectory represents a released version of the Cortex Agent spec.

## Directory Layout

\```
specs/
├── v1/
│   ├── agent_spec.json   # Versioned spec snapshot
│   └── metadata.yml      # Version metadata, changelog, status
└── v2/                   # Future versions added here
\```

## Versioning Policy

| Field | Rule |
|-------|------|
| Version bump | Any change to tools, models, or tool_resources requires a new version |
| `status` | `draft` → `stable` → `deprecated` |
| Breaking changes | Must be listed in `metadata.yml` before deployment |
| Rollback | Deploy any prior `agent_spec.json` via `--spec-version vN` |

## Promoting a New Version

1. Create `specs/vN/agent_spec.json` with your changes.
2. Add `specs/vN/metadata.yml` with changelog and `status: draft`.
3. Run evals: `python agent/run_evals.py --agent <name>`
4. If evals pass, set `status: stable` and open a PR.
5. After merge, CI deploys via `deploy_all.py`.
```

---

**File: `agent/agents/<agent-name>/prompts/orchestration.md`**

Generate a structured orchestration prompt with these sections:
- `# <AGENT_NAME> Agent — Orchestration Prompt`
- **Identity and Scope** — what database/schema, what data it can access
- **Tool Usage Rules** — when to use each tool, max calls per turn
- **Response Formatting Rules** — number formats, list limits, freshness acknowledgment
- **Security and Safety** — no raw SQL execution, no prompt injection compliance
- **Error Handling** — tool failures, timeouts
- **Examples of in-scope questions** (3-5 examples)
- **Examples of out-of-scope questions** (2-3 examples with decline behavior)

---

**File: `agent/agents/<agent-name>/prompts/response.md`**

Generate formatting rules:
- `# <AGENT_NAME> Agent — Response Formatting Prompt`
- Numbers: currency ($, 2 decimals), counts (comma separators), percentages (1 decimal)
- Tables: markdown tables for multi-row (up to 20), summarize for more
- Summaries: lead with answer, supporting detail, one-line insight
- Tone: professional, concise, no filler
- Exclusions: no raw SQL, no schema internals, no fabricated data

---

**File: `agent/agents/<agent-name>/evals/eval_config.yaml`**

```yaml
eval_suite:
  name: "<AGENT_NAME>_EVALS"
  description: "Ground-truth evaluation suite for <AGENT_NAME> Cortex Agent"
  version: "1.0.0"

connection:
  profile: "default"
  account: "xna38553.east-us-2.azure"
  user: "MCP_SERVICE_USER"
  database: "<DATABASE>"
  schema: "<SCHEMA>"
  warehouse: "ANALYTICS_WH"

agent:
  fqn: "<DATABASE>.<SCHEMA>.<AGENT_NAME>"
  spec_version: null

judge:
  model: "llama3.1-70b"
  criteria:
    - name: "correctness"
      description: "The answer correctly addresses the question using real query results"
      weight: 0.5
    - name: "groundedness"
      description: "The answer is grounded in tool results — no hallucination"
      weight: 0.3
    - name: "completeness"
      description: "The answer covers all aspects of the question"
      weight: 0.2

thresholds:
  overall_pass_score: 0.80
  per_question_min_score: 0.60
  tool_call_accuracy: 1.0

results:
  output_dir: "agent/agents/<agent-name>/evals/results"
  write_to_snowflake: true
  table: "<DATABASE>.<SCHEMA>.AGENT_EVAL_RESULTS"

ground_truth_file: "agent/agents/<agent-name>/evals/ground_truth.json"
```

---

**File: `agent/agents/<agent-name>/evals/ground_truth.json`**

Generate 5-8 ground-truth test cases based on the agent's scope:
```json
[
  {
    "id": "GT-001",
    "category": "<category>",
    "question": "<natural language question>",
    "expected_tool": "<tool_name or null for out-of-scope>",
    "expected_behavior": "<description of correct behavior>",
    "reference_sql": "<SQL that produces the correct answer or null>",
    "evaluation_criteria": {
      "must_include": ["<key term 1>", "<key term 2>"],
      "must_not_include": ["<bad term>"]
    }
  }
]
```

Categories to cover: ranking, aggregation, filter, recency, summary, out_of_scope.

---

**File: `agent/agents/<agent-name>/monitoring/alert_policy.yml`**
```yaml
agent:
  fqn: "<DATABASE>.<SCHEMA>.<AGENT_NAME>"

alerts:
  error_rate_threshold_pct: 5.0
  avg_latency_seconds: 30
  daily_credit_limit: 10.0
  eval_pass_score_min: 0.80
  notification_integration: "SLACK_ALERTS_INTEGRATION"
  notification_recipients:
    - "<team-oncall@example.com>"
```

---

**File: `agent/agents/<agent-name>/monitoring/usage_queries.sql`**

Generate monitoring queries for:
1. Invocation count (last 7 days) — grouped by day
2. Tool call breakdown — sample queries with latency
3. Eval results trend — pass rate over time
4. Slowest queries — performance triage (> 10s)
5. Failed queries — error monitoring
6. Credit consumption — budget tracking

All queries filter by `QUERY_TEXT ILIKE '%<AGENT_NAME>%'`.

---

**Deployment & Eval commands (for reference in summary):**

```bash
# Deploy this agent only
python agent/deploy_all.py -c default --agent <agent-name>

# Dry-run deploy
python agent/deploy_all.py --dry-run --agent <agent-name>

# Run evals for this agent
python agent/run_evals.py --agent <agent-name>

# Dry-run eval
python agent/run_evals.py --agent <agent-name> --dry-run

# Deploy ALL agents
python agent/deploy_all.py -c default

# Run ALL evals
python agent/run_evals.py --all
```

The new agent is automatically discovered by CI — no changes to `deploy_all.py`, `run_evals.py`, or `.github/workflows/` are needed.

---

### 2.11 — MLOps: Custom ML Model Scaffold

When the user wants to scaffold a **custom ML model** into the project, generate the full model lifecycle directory.

**Discovery (if model exists in Snowflake registry):**
```sql
-- Check Snowflake native model registry
SHOW MODELS IN SCHEMA ML_STAGING.MLOPS;
SHOW VERSIONS IN MODEL ML_STAGING.MLOPS.<MODEL_NAME>;

-- Check custom registry table (if foundation SQL deployed)
SELECT * FROM ML_STAGING.MLOPS.MODEL_REGISTRY
WHERE MODEL_NAME = '<model_name>'
ORDER BY CREATED_AT DESC LIMIT 5;

-- Check deployment events
SELECT * FROM ML_STAGING.MLOPS.MODEL_DEPLOYMENT_EVENTS
WHERE MODEL_NAME = '<model_name>'
ORDER BY EVENT_TIMESTAMP DESC LIMIT 5;
```

If creating from scratch, ask the user for:
```
1. Model name (lowercase-kebab, e.g., churn-risk)
2. Version (e.g., v1)
3. Owner (team name)
4. Risk tier: low | medium | high
5. Domain (e.g., subscriptions, payments, marketing)
6. Prediction target (what is it predicting?)
7. Business goal (one sentence)
8. Decision frequency: batch | realtime
9. Source tables (FQNs)
10. Algorithm (e.g., xgboost_classifier, lightgbm, snowflake_ml)
11. Primary metric (e.g., auc_roc, auc_pr, rmse)
12. Minimum threshold for primary metric
```

**Directory structure to create:**
```
custom-ml-models/
└── <model_name>-<version>/
    ├── model_spec.yml                    # Full model specification
    ├── model_card.md                     # Model documentation card
    ├── release_notes.md                  # Version release notes
    ├── README.md                         # Quick reference for this model
    └── snowflake/
        └── sql/
            └── 001_register_model.sql    # Registration + deployment SQL
```

**File: `custom-ml-models/<model_name>-<version>/model_spec.yml`**
```yaml
model:
  name: "<model_name>"
  version: "<version>"
  owner: "<owner_team>"
  risk_tier: "<low|medium|high>"
  domain: "<domain>"

objective:
  prediction_target: "<target>"
  business_goal: "<goal>"
  decision_frequency: "<batch|realtime>"

data_contract:
  source_tables:
    - "<FQN_1>"
    - "<FQN_2>"
  feature_contract_version: "<feature_version>"
  training_window: "<YYYY-MM-DD to YYYY-MM-DD>"
  sensitive_attributes:
    - "<attribute>"

training:
  algorithm: "<algorithm>"
  hyperparameters:
    param_1: <value>
  validation_strategy: "<cv|holdout|time_based_holdout>"
  reproducibility_seed: 42

acceptance_criteria:
  primary_metric: "<metric>"
  minimum_primary_metric: <threshold>
  max_p95_latency_ms: <ms>
  max_drift_score: <score>

deployment:
  target_environment: "staging"
  canary_traffic_percent: <5|10>
  dual_control_required: <true if high-risk>
  rollback_trigger:
    - "<condition_1>"
    - "<condition_2>"
```

**File: `custom-ml-models/<model_name>-<version>/model_card.md`**
```markdown
# Model Card: `<model_name>`

## Overview

- **Version**: `<version>`
- **Owner**: `<owner>`
- **Use case**: <business_use_case>
- **Risk tier**: `<tier>`

## Intended Use

- <Primary decision supported>
- <Confidence/quality expectations>
- <In-scope and out-of-scope boundaries>

## Data and Features

- Sources: <list source tables>
- Feature contract: `<feature_version>`
- Label definition: <what the label represents>

## Performance

- Primary metric: <metric> = `<value>` (target >= `<threshold>`)
- Secondary metric(s): <if known>
- P95 scoring latency target: `< <ms> ms`

## Risk and Fairness

- <Bias checks and outcomes>
- <Failure modes and mitigations>
- <Human oversight requirements based on risk tier>

## Operations

- Deployment path: dev -> staging -> prod
- Monitoring signals: drift score, daily metric proxy, latency p95, scoring volume
- Retraining trigger: drift > `<threshold>` or quality floor breach
- Rollback: revert to last active version in MODEL_REGISTRY
```

**File: `custom-ml-models/<model_name>-<version>/release_notes.md`**
```markdown
# Release Notes: <model_name> <version>

## Scope

- <What this version introduces>
- Uses feature contract `<feature_version>`
- Model artifact at `@ML_MODEL_STAGE/<model_name>/<version>/model.pkl`

## Validation Summary

- <Primary metric>: `<value>` (target >= `<threshold>`)
- <Secondary metric>: `<value>`
- Staging P95 latency: `<ms> ms` (target <= `<max_ms> ms`)
- <Fairness review outcome>

## Release Plan

1. Register version in staging registry
2. Start <canary_percent>% canary traffic
3. Observe health signals for 24 hours
4. Promote to full staging if no threshold breaches
5. Submit production promotion request with evidence

## Rollback Plan

- Deactivate `<version>`
- Reactivate last known healthy version from `V_ACTIVE_MODELS`
- Confirm smoke checks and close incident if triggered
```

**File: `custom-ml-models/<model_name>-<version>/snowflake/sql/001_register_model.sql`**
```sql
-- Registration and activation flow for <model_name> <version>.
-- Adjust database/schema for your environment before execution.

USE DATABASE ML_STAGING;
USE SCHEMA MLOPS;

-- 1) Register the model version in the registry.
INSERT INTO MODEL_REGISTRY (
    MODEL_NAME,
    MODEL_VERSION,
    OWNER,
    RISK_TIER,
    STAGE,
    ARTIFACT_URI,
    FEATURE_CONTRACT_VERSION,
    TRAIN_DATA_WINDOW,
    METRICS,
    IS_ACTIVE
)
SELECT
    '<model_name>',
    '<version>',
    '<owner>',
    '<risk_tier>',
    'staging',
    '@ML_MODEL_STAGE/<model_name>/<version>/model.pkl',
    '<feature_contract_version>',
    '<training_window>',
    PARSE_JSON('<metrics_json>'),
    FALSE;

-- 2) Deactivate older active versions before activation.
UPDATE MODEL_REGISTRY
SET IS_ACTIVE = FALSE
WHERE MODEL_NAME = '<model_name>'
  AND MODEL_VERSION <> '<version>'
  AND IS_ACTIVE = TRUE;

-- 3) Activate this version.
UPDATE MODEL_REGISTRY
SET IS_ACTIVE = TRUE
WHERE MODEL_NAME = '<model_name>'
  AND MODEL_VERSION = '<version>';

-- 4) Log deployment event.
INSERT INTO MODEL_DEPLOYMENT_EVENTS (
    MODEL_NAME,
    MODEL_VERSION,
    ENVIRONMENT,
    EVENT_TYPE,
    EVENT_STATUS,
    APPROVED_BY,
    DETAILS
)
SELECT
    '<model_name>',
    '<version>',
    'staging',
    'deploy',
    'success',
    CURRENT_USER(),
    PARSE_JSON('{"change_ticket":"<ticket>","strategy":"<canary_percent>_percent_canary"}');
```

**Risk tier controls to enforce:**

| Tier | Canary % | Dual approval | Human-in-the-loop | Extra files needed |
|------|----------|---------------|-------------------|--------------------|
| low | 10% | No | No | Standard set |
| medium | 10% | No | Recommended | Standard set |
| high | 5% | Yes (2 reviewers) | Required | Add `approvals.md` with dual-control checklist |

For `high` risk tier models, also generate:
```
custom-ml-models/<model_name>-<version>/approvals.md
```
With dual-control approval checklist:
```markdown
# Dual-Control Approval: <model_name> <version>

## Required Approvals (2 independent reviewers)

- [ ] Reviewer 1: __________ Date: __________
  - [ ] Model card reviewed and accurate
  - [ ] Performance metrics meet acceptance criteria
  - [ ] Fairness review completed with no blocking issues
  - [ ] Rollback plan verified
  
- [ ] Reviewer 2: __________ Date: __________
  - [ ] Source data lineage validated
  - [ ] Feature contract version confirmed current
  - [ ] Monitoring alerts configured and tested
  - [ ] Incident runbook reviewed and actionable
```

---

## PHASE 3: Verification

After all files are generated/modified:

### 3.1 — Naming Convention Check
```bash
cd /Users/kannannvelmurugiah/Desktop/snowflake-project
python scripts/check_naming.py
```

If violations found, fix them before proceeding.

### 3.2 — DCM Plan (dry-run)
```bash
cd /Users/kannannvelmurugiah/Desktop/snowflake-project
snow dcm plan --target DEV -c default
```

Report the plan output to the user. Objects should show as "CREATE" (new) not "ALTER" (unless updating).

### 3.3 — dbt Compile (if dbt models were generated)
```bash
cd /Users/kannannvelmurugiah/Desktop/snowflake-project/dbt
dbt compile
```

Report any compilation errors and fix them.

### 3.4 — Agent Spec Validation (if agent was scaffolded)
```bash
cd /Users/kannannvelmurugiah/Desktop/snowflake-project

# Verify agent is discoverable
python agent/deploy_all.py --list

# Dry-run deploy for the new agent
python agent/deploy_all.py --dry-run --agent <agent-name>

# Dry-run eval
python agent/run_evals.py --agent <agent-name> --dry-run
```

Verify:
- `agent.yml` exists and has required fields (name, fqn, database, schema, owner)
- `agent_spec.json` is valid JSON with required fields (models, tools, tool_resources)
- `metadata.yml` has version, status, fqn fields
- `orchestration.md` has all required sections (Identity, Tool Rules, Security)
- `response.md` has formatting standards
- `eval_config.yaml` has thresholds and judge config
- `ground_truth.json` is valid JSON array with 5+ entries with required fields per entry
- `results/.gitkeep` exists
- Agent appears in `--list` output

### 3.5 — ML Model Spec Validation (if model was scaffolded)

Verify:
- `model_spec.yml` is valid YAML with all required sections (model, objective, data_contract, training, acceptance_criteria, deployment)
- `model_card.md` has all required sections (Overview, Intended Use, Data, Performance, Risk, Operations)
- `release_notes.md` has Scope, Validation Summary, Release Plan, Rollback Plan sections
- `001_register_model.sql` has valid SQL (INSERT into MODEL_REGISTRY, deployment event)
- Risk tier controls are correct (canary %, dual approval for high-risk)
- For high-risk: `approvals.md` exists with dual-control checklist

### 3.6 — Summary Report

Present a final summary:

```
SCAFFOLD COMPLETE
═════════════════

Objects scaffolded: N
Files modified:     N
Files created:      N

Modified files:
  ✓ sources/definitions/tables.sql     (+2 DEFINE TABLE)
  ✓ ingestion/snowflake/streams.sql    (+1 DEFINE STREAM)
  ✓ dbt/models/staging/_sources.yml    (+1 table entry)

Created files:
  ✓ dbt/models/staging/stg_new_table.sql
  ✓ dbt/models/staging/_staging.yml (updated)

Next steps:
  1. Review generated definitions
  2. Run: snow dcm plan --target DEV -c default
  3. Run: cd dbt && dbt run --select stg_new_table
  4. Open a PR for review
```

---

## Conventions Reference

### Naming
- All Snowflake object names: `UPPER_SNAKE_CASE`
- dbt model files: `lowercase_snake_case.sql`
- dbt model prefixes: `stg_` (staging), `int_` (intermediate), `fct_` (fact), `dim_` (dimension)
- Streams suffix: `_STREAM`
- Tasks suffix: `_TASK`
- Landing tables suffix: `_RAW`
- DLQ tables suffix: `_DLQ`
- DMF naming: `DMF_<CHECK_TYPE>_<COLUMN_OR_TABLE>` (e.g., `DMF_NULL_COUNT_EMAIL`)
- Alert naming: `<DOMAIN>_<CONDITION>_ALERT` (e.g., `AGENT_ERROR_RATE_ALERT`)
- Policy naming: `<TYPE>_<DOMAIN>_POLICY` (e.g., `MASK_PII_EMAIL_POLICY`)
- Tag naming: `<DOMAIN>_<CLASSIFICATION>` (e.g., `PII_LEVEL`, `DATA_DOMAIN`)
- Pipe naming: `<SOURCE>_<TARGET>_PIPE` (e.g., `S3_CUSTOMERS_PIPE`)
- Agent folder names: `lowercase-kebab` (e.g., `tpch-analyst`)
- ML model folder names: `lowercase-kebab-version` (e.g., `churn-risk-v1`)

### Templating Variables (DCM)
- `{{env_suffix}}` — resolves to `_DEV` (DEV) or empty (PROD)
- `{{wh_size}}` — resolves to `XSMALL` (DEV) or `MEDIUM` (PROD)
- Only apply to environment-differentiated objects (warehouses, roles)
- Do NOT apply to data tables, views, streams, stages

### File Organization
- One `DEFINE` per logical object (but all tables in one file, all views in one file)
- DCM-managed files: `tables.sql`, `views.sql`, `infrastructure.sql`, `access.sql`, `stages.sql`, `streams.sql`
- Imperative (non-DCM) files: `procedures.sql`, `functions.sql`, `data_quality.sql`, `dynamic_tables.sql`, `alerts.sql`, `policies.sql`, `tags.sql`, `sequences.sql`, `network.sql`, `integrations.sql`, `secrets.sql`, `pipes.sql`
- Comments at the top of each section
- Blank line between `DEFINE` blocks or `CREATE OR REPLACE` blocks
- Tasks use `CREATE OR REPLACE` (not DCM-managed)
- If a target file doesn't exist yet, create it with the standard header comment pattern

### dbt Conventions
- Source database/schema controlled by vars: `source_database`, `source_schema`
- Staging models are views (never tables)
- Intermediate models are ephemeral
- Mart models are incremental with merge strategy
- All mart models get `+grants: {select: ["DATA_READER"]}`

### AgentOps Conventions
- **Multi-agent structure**: each agent lives in `agent/agents/<agent-name>/` (lowercase-kebab folder name)
- Agent Snowflake names: `UPPER_SNAKE_CASE` (e.g., `TPCH_ANALYST`)
- Agent folder names: `lowercase-kebab` (e.g., `tpch-analyst`)
- Discovery anchor: `agent.yml` in each agent folder (without it, agent is invisible to tooling)
- Spec versions: `v1`, `v2`, `v3` (directory-based under `specs/`)
- Auto-selects highest `vN` with `agent_spec.json` for deployment
- Prompts are markdown files in `prompts/` (loaded and injected at deploy time by `deploy_agent.py`)
- Agent FQN format: `DATABASE.SCHEMA.AGENT_NAME`
- Eval ground truth: minimum 5 questions covering ranking, aggregation, filter, recency, out_of_scope
- Eval results path: `agent/agents/<name>/evals/results/` (gitignored)
- Monitoring queries filter by agent name via `QUERY_TEXT ILIKE '%<NAME>%'`
- Shared scripts (do NOT recreate): `agent/deploy_all.py`, `agent/run_evals.py`
- Deploy single: `python agent/deploy_all.py -c default --agent <name>`
- Deploy all: `python agent/deploy_all.py -c default`
- CI auto-discovers all agents — no workflow changes needed for new agents

### MLOps Conventions
- Model directory naming: `<model_name>-<version>` (lowercase-kebab, e.g., `churn-risk-v1`)
- `model_spec.yml` is the source of truth for model metadata
- `model_card.md` documents intended use, performance, risk, and operations
- Registration SQL targets `ML_<ENV>.MLOPS` schema (ML_DEV, ML_STAGING, ML_PROD)
- Risk tier determines canary %, approval gates, and human oversight requirements
- Each model version is immutable once registered — new versions get new directories
- Foundation SQL (001, 002, 003) is in `custom-ml-models/snowflake/sql/` (one-time setup, not per-model)

---

## Error Handling

- If `GET_DDL()` fails with "Object does not exist" → inform user, skip object
- If `DESCRIBE` returns empty → object may have been dropped, confirm with user
- If a file doesn't exist at expected path → create it with the standard header comment
- If DCM plan fails → likely a syntax issue in the DEFINE block, show error and fix
- If dbt compile fails → check for missing refs or sources, fix YAML entries

---

## Safety

- NEVER drop or alter live Snowflake objects — this skill is READ-ONLY against Snowflake (introspection only)
- NEVER overwrite existing file content — always APPEND or use targeted Edit
- NEVER commit to git automatically — leave that to the user
- ALWAYS show the plan and get confirmation before writing any files
- ALWAYS use the project's existing patterns — match indentation, style, and conventions from neighboring code
