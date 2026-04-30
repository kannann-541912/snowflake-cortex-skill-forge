---
name: de-load-validate
description: "Phase 5 — Continuously load data and validate on every load: COPY INTO with quarantine, row count reconciliation, null checks, and automated anomaly alerts"
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Read
  - Write
---

# Safety
- Source is `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10` — read-only. Never write there.
- All INSERT/CREATE targets must be in `SANDBOX.TPCH`.

# TPCH Load Strategy
Because the source is a live Snowflake table (not a stage), the load pattern is
**INSERT INTO ... SELECT FROM source** or **Dynamic Table refresh** — not COPY INTO.
Steps 2 (COPY INTO) and 7 (Snowpipe) are replaced with the pattern below.

## TPCH Load Pattern (replaces Steps 2 & 7)
```sql
-- Initial full load into staging table
INSERT INTO SANDBOX.TPCH.STG_{table_name}
SELECT
    {transform_expressions},
    CURRENT_TIMESTAMP()  AS _loaded_at,
    'TPCH_SF10'          AS _source_system
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.{table_name};
```

For large tables (LINEITEM ~60M, ORDERS ~15M), load incrementally using a filter if a
watermark column exists (e.g. O_ORDERDATE), or do a full replace on first load.

For ongoing refresh, prefer **Dynamic Tables** (see `$de-transform`) over manual INSERT.

# When to Use
- User has transforms set up and wants to load data
- User says "load the data", "run the pipeline", "ingest and validate", "copy data in"
- Setting up continuous/scheduled loading with built-in quality gates

# What This Skill Provides
Replaces nightly batch loads with errors discovered days later. Every load is accompanied
by immediate validation — row count reconciliation, null checks, quarantine, and alerts.
Self-healing: bad rows go to quarantine, good rows proceed. Never fail silently.

# Instructions

## Step 1 — Create quarantine table
Before any load, ensure a quarantine table exists:
```sql
CREATE TABLE IF NOT EXISTS {database}.{schema}.{table_name}_QUARANTINE (
    RAW_ROW       VARIANT,
    ERROR_MESSAGE VARCHAR(2000),
    FILE_NAME     VARCHAR(500),
    ROW_NUMBER    NUMBER,
    QUARANTINED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);
```

## Step 2 — COPY INTO with ON_ERROR = CONTINUE
```sql
COPY INTO {database}.{schema}.{target_table}
FROM @{database}.{schema}.{stage_name}
FILE_FORMAT = (FORMAT_NAME = '{database}.{schema}.{source_name}_FF')
ON_ERROR = 'CONTINUE'           -- bad rows skipped, not blocking
PURGE = FALSE                   -- keep files for audit
LOAD_UNCERTAIN_FILES = TRUE
FORCE = FALSE;                  -- skip already-loaded files
```

Capture load results:
```sql
SELECT *
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY status;
```

## Step 3 — Move rejected rows to quarantine
```sql
INSERT INTO {database}.{schema}.{target_table}_QUARANTINE
    (RAW_ROW, ERROR_MESSAGE, FILE_NAME, ROW_NUMBER, QUARANTINED_AT)
SELECT
    PARSE_JSON(rejected_record)  AS raw_row,
    error                        AS error_message,
    file                         AS file_name,
    line                         AS row_number,
    CURRENT_TIMESTAMP()          AS quarantined_at
FROM TABLE(VALIDATE({database}.{schema}.{target_table},
           JOB_ID => '_last'));
```

## Step 4 — Row count reconciliation
Compare source file row count to loaded row count:
```sql
-- Rows loaded this run
SELECT COUNT(*) AS loaded_rows
FROM {database}.{schema}.{target_table}
WHERE _LOADED_AT >= DATEADD('minute', -5, CURRENT_TIMESTAMP());

-- Rows quarantined this run
SELECT COUNT(*) AS quarantined_rows
FROM {database}.{schema}.{target_table}_QUARANTINE
WHERE QUARANTINED_AT >= DATEADD('minute', -5, CURRENT_TIMESTAMP());
```

Report: `{loaded_rows} rows loaded, {quarantined_rows} rows quarantined ({pct}% rejection rate)`

## Step 5 — Column-level validation
Run quality checks on the just-loaded batch:
```sql
-- Null check on NOT NULL columns
SELECT
    '{col}'                                       AS column_name,
    COUNT(*) - COUNT({col})                       AS null_count,
    ROUND((COUNT(*) - COUNT({col})) * 100.0
          / NULLIF(COUNT(*), 0), 2)               AS null_pct
FROM {database}.{schema}.{target_table}
WHERE _LOADED_AT >= DATEADD('minute', -5, CURRENT_TIMESTAMP())
HAVING null_count > 0;

-- Referential integrity check (if FK exists)
SELECT COUNT(*) AS orphan_count
FROM {database}.{schema}.{fact_table} f
LEFT JOIN {database}.{schema}.{dim_table} d ON f.{fk_col} = d.{pk_col}
WHERE d.{pk_col} IS NULL
  AND f._LOADED_AT >= DATEADD('minute', -5, CURRENT_TIMESTAMP());
```

## Step 6 — Create Snowflake alert for ongoing monitoring
```sql
CREATE OR REPLACE ALERT {database}.{schema}.{table_name}_QUALITY_ALERT
  WAREHOUSE = ANALYTICS_WH
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1
    FROM {database}.{schema}.{table_name}_QUARANTINE
    WHERE QUARANTINED_AT >= DATEADD('minute', -5, CURRENT_TIMESTAMP())
    HAVING COUNT(*) > {quarantine_threshold}
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      '{notification_email}',
      'Data Quality Alert: {table_name}',
      'Quarantine threshold exceeded. Check {table_name}_QUARANTINE.'
    );

ALTER ALERT {database}.{schema}.{table_name}_QUALITY_ALERT RESUME;
```

## Step 7 — Set up Snowpipe for continuous loading (optional)
If user wants continuous ingest rather than manual COPY INTO:
```sql
CREATE PIPE IF NOT EXISTS {database}.{schema}.{table_name}_PIPE
  AUTO_INGEST = TRUE
  COMMENT = 'Continuous ingest for {source_name}'
AS
COPY INTO {database}.{schema}.{target_table}
FROM @{database}.{schema}.{stage_name}
FILE_FORMAT = (FORMAT_NAME = '{database}.{schema}.{source_name}_FF')
ON_ERROR = 'CONTINUE';

-- Get SQS ARN for S3 event notification
SHOW PIPES LIKE '{table_name}_PIPE' IN SCHEMA {database}.{schema};
```

## Step 8 — Update status log
Append to `schema_design.md`:
```markdown
## Load & Validate Log
- Load run at: {timestamp}
- Rows loaded: {n}
- Rows quarantined: {n} ({pct}%)
- Quality checks: PASS / FAIL
- Alert created: YES
- Snowpipe: YES / NO
## Next Step
Run `$de-transform` to apply business transforms.
```

## Best Practices
- Never use `ON_ERROR = 'ABORT_STATEMENT'` in production — one bad row kills the load
- Always create quarantine table before loading — retrospective quarantine is painful
- Alert on quarantine rate > 1% — anything higher signals upstream schema drift
- Keep `PURGE = FALSE` until validation passes — you need the files for reprocessing

## Common Patterns

### Pattern 1: First load
Full load with validation, quarantine setup, and alert creation

### Pattern 2: Incremental load
COPY INTO skips already-loaded files automatically via metadata; validate only new batch

# Examples

## Example 1: Load TPCH ORDERS into staging
User: `$de-load-validate Load ORDERS into SANDBOX.TPCH.STG_ORDERS`
Assistant: Creates STG_ORDERS_QUARANTINE, runs INSERT INTO STG_ORDERS SELECT FROM
TPCH_SF10.ORDERS (full load ~15M rows), validates row count match, null checks on
O_ORDERKEY + O_CUSTKEY (0 nulls), creates quality alert. Reports 15,000,000 rows loaded,
0 quarantined.

