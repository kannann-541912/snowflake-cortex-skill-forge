---
name: de-schema-setup
description: "Phase 3 — Generate and deploy idempotent DDL for target tables, file formats, stages, masking policies, and lineage tags — all with governance by default"
parent_skill: de-workflow
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Read
  - Write
---

# Client Context
Read `references/client-context.md` at the start of every invocation. Apply any values it
defines as overrides: target database/schema, DDL create mode, naming prefixes, masking
policy definitions and visible roles, and verification settings. If the file is absent or a
value is unset (`~`), use the built-in defaults. Never fail if the file is missing.

# Safety
- Source is `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10` — read-only. NEVER generate DDL targeting it.
- All CREATE/ALTER statements must target `SANDBOX.TPCH` (or user-confirmed target).
- Before executing any statement, verify the target path does NOT start with `SNOWFLAKE_SAMPLE_DATA`.

# Target Path Convention (TPCH)
- Staging tables: `SANDBOX.TPCH.STG_{source_table}` (e.g. `SANDBOX.TPCH.STG_ORDERS`)
- Mart tables: `SANDBOX.TPCH.MART_{model_name}` (e.g. `SANDBOX.TPCH.MART_ORDERS_ENRICHED`)
- No file formats or external stages needed — source is a live Snowflake table, not a stage

# Domain Context
You are a Snowflake DDL engineer specializing in idempotent, governance-by-default schema
deployment. You generate `CREATE IF NOT EXISTS` DDL only — never `CREATE OR REPLACE` on
tables. You wire masking policies and lineage tags at creation time, never as afterthoughts.

# When to Use
- User has completed `$de-schema-design` and has a `schema_design.md`
- User says "create the tables", "set up the schema", "deploy DDL", "generate the DDL"
- Deploying target objects to Snowflake

# When NOT to Use
- `schema_design.md` doesn't exist yet → run `de-schema-design` first
- User wants to add existing tables to version control → use `snowflake-project-builder`
- User wants to modify an already-deployed table (ALTER) → handle directly, not via this skill

# Gotchas
- Never use `CREATE OR REPLACE TABLE` — it destroys data. Always use `CREATE TABLE IF NOT EXISTS`.
- Deploy order matters: masking policies BEFORE tables that reference them. Always deploy in the order: tags → masking policies → tables → views → row access policies.
- No external stages or file formats are needed for TPCH — it's a live relational source.
- Always check `schema_setup.sql` exists and was committed to Git before calling `de-load-validate`.

# Standalone Quality Gate
```sql
-- Verify tables were created
SELECT table_name, row_count
FROM SANDBOX.information_schema.tables
WHERE table_schema = 'TPCH'
  AND table_name LIKE 'STG_%'
ORDER BY table_name;
```

# What This Skill Provides
Replaces manual DDL by hand with copy-paste errors. Generates production-grade, idempotent
DDL with lineage tags, masking policies, and governance objects pre-wired — all deployed
in a single transaction-safe sequence.

# Instructions

## Step 0 — Load client context
Read `references/client-context.md`. If present, apply:
- `target_database` / `target_schema` → override SANDBOX.TPCH defaults
- `ddl.create_mode` → IF_NOT_EXISTS (safe) vs OR_REPLACE (dev only)
- `naming.*` → table prefixes and tag names
- `masking_policies.visible_to_roles` → roles that see raw values in masking policies
- `masking_policies.policy_definitions` → policy names and behaviors per PII type

## Step 1 — Read schema design
Use `Read` to load `schema_design.md`. If missing, instruct user to run `$de-schema-design`.

## Step 2 — Generate DDL in deployment order

> **TPCH note:** Steps 2a (file format) and 2b (external stage) are skipped — the source
> is `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10`, a live structured database, not a staged file.
> Start directly at Step 2c (lineage tag).

### 2a. File format (if source is staged files)
```sql
CREATE FILE FORMAT IF NOT EXISTS {database}.{schema}.{source_name}_FF
  TYPE = 'CSV'  -- or PARQUET / JSON
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '')
  EMPTY_FIELD_AS_NULL = TRUE
  COMPRESSION = AUTO;
```

### 2b. External stage (if not already exists)
```sql
CREATE STAGE IF NOT EXISTS {database}.{schema}.{source_name}_STAGE
  URL = '{s3_or_gcs_or_azure_url}'
  FILE_FORMAT = {database}.{schema}.{source_name}_FF
  COMMENT = 'Source: {source_description}';
```

### 2c. Lineage tag
```sql
CREATE TAG IF NOT EXISTS {database}.{schema}.SOURCE_LINEAGE
  COMMENT = 'Tracks origin system for data governance';
```

### 2d. Masking policies (one per PII type from schema design)
```sql
-- Email masking: show domain only to DATA_ENGINEER, NULL to others
CREATE MASKING POLICY IF NOT EXISTS {database}.{schema}.MASK_EMAIL
  AS (val STRING) RETURNS STRING ->
    CASE
      WHEN CURRENT_ROLE() IN ('DATA_ENGINEER', 'SYSADMIN')
        THEN val
      ELSE '***@' || SPLIT_PART(val, '@', 2)
    END;

-- Generic PII: SHA2 hash for audit, NULL for others
CREATE MASKING POLICY IF NOT EXISTS {database}.{schema}.MASK_PII_HASH
  AS (val STRING) RETURNS STRING ->
    CASE
      WHEN CURRENT_ROLE() IN ('DATA_ENGINEER', 'SYSADMIN')
        THEN val
      ELSE SHA2(val, 256)
    END;
```

### 2e. Target tables (one per table in schema_design.md)
```sql
CREATE TABLE IF NOT EXISTS {database}.{schema}.{table_name} (
  -- Source columns from mapping
  {col_name}  {snowflake_type}  [NOT NULL]  [DEFAULT {val}],
  ...
  -- Standard audit columns (ALWAYS include)
  _LOADED_AT       TIMESTAMP_LTZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP(),
  _SOURCE_SYSTEM   VARCHAR(50)    NOT NULL  DEFAULT '{source_name}',
  -- SCD2 columns if dimension (include only if SCD2 in schema design)
  _EFF_START_DATE  TIMESTAMP_LTZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP(),
  _EFF_END_DATE    TIMESTAMP_LTZ,
  _IS_CURRENT      BOOLEAN        NOT NULL  DEFAULT TRUE
)
CLUSTER BY ({clustering_columns_if_recommended})
COMMENT = '{table_description}'
TAG ({database}.{schema}.SOURCE_LINEAGE = '{source_system_name}');
```

### 2f. Apply masking policies to PII columns
```sql
ALTER TABLE {database}.{schema}.{table_name}
  MODIFY COLUMN {pii_column}
  SET MASKING POLICY {database}.{schema}.MASK_EMAIL;
```

## Step 3 — Execute DDL

⚠️ **MANDATORY STOPPING POINT** — Before executing ANY CREATE/ALTER statement:
1. Show the user the complete DDL that will be executed (all statements in order).
2. Confirm the target database/schema (`SANDBOX.TPCH` or user-confirmed path).
3. Verify NO statement targets `SNOWFLAKE_SAMPLE_DATA` — if found, **ABORT immediately**.
4. Wait for explicit user confirmation ("yes, deploy it" or equivalent).
5. Only then execute via `snowflake_sql_execute`.

Execute each statement via `snowflake_sql_execute`. Stop and report any error before continuing.
Wrap all table DDL in a sequence with explicit error handling notes in comments.

## Step 4 — Verify deployment
After deployment, verify each object exists:
```sql
SHOW TABLES LIKE '{table_name}' IN SCHEMA {database}.{schema};
SHOW MASKING POLICIES IN SCHEMA {database}.{schema};
```

## Step 5 — Write DDL file
Save all generated DDL to `schema_setup.sql` for version control:
```sql
-- schema_setup.sql
-- Generated by $de-schema-setup at {timestamp}
-- Source: {source_name} → Target: {database}.{schema}
-- Run this file to recreate all objects from scratch (idempotent)
...
```

Also append to `schema_design.md`:
```markdown
## Deployment Log
- Deployed at: {timestamp}
- Objects created: {list}
- DDL saved to: schema_setup.sql
## Next Step
Run `$de-transform-setup` to build transform mappings.
```

## Best Practices
- All DDL is `CREATE ... IF NOT EXISTS` — never `CREATE OR REPLACE` on production tables
- Always apply masking policies immediately at table creation — never defer
- Tag tables at creation with SOURCE_LINEAGE — enables Snowflake lineage graph
- Cluster keys: use columns that appear most in WHERE and JOIN predicates

## Common Patterns

### Pattern 1: CSV stage to table
Generate file format + stage + target table + masking policies in one script

### Pattern 2: Existing table — add audit columns
```sql
ALTER TABLE {t} ADD COLUMN IF NOT EXISTS _LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP();
```

# Examples

## Example 1: TPCH staging tables
User: `$de-schema-setup Deploy schema for ORDERS and LINEITEM`
Assistant: Reads schema_design.md, skips file format/stage steps, generates:
- SOURCE_LINEAGE tag in SANDBOX.TPCH
- STG_ORDERS (10 cols + 2 audit cols, clustered on O_ORDERDATE)
- STG_LINEITEM (17 cols + 2 audit cols, clustered on L_SHIPDATE)
- No masking policies (no PII in TPCH)
Executes all DDL against SANDBOX.TPCH, verifies via SHOW TABLES, writes schema_setup.sql.

