---
name: de-transform
description: "Phase 6 — Apply business transforms with self-healing: incremental merge, Dynamic Table refresh, dbt run, resume-on-failure, and post-transform quality assertions"
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Read
  - Write
  - Bash
---

# Safety
- Source reads from `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10` — read-only.
- All Dynamic Tables, Tasks, Streams must be created in `SANDBOX.TPCH`.

# TPCH Transform Notes
- For TPCH, prefer **Dynamic Tables** over Stream+Task — the source is a static sample
  database that doesn't emit change events, so Streams will always show 0 changes after
  initial load. Use Dynamic Tables with `TARGET_LAG = 'downstream'` for mart models.
- Stream+Task is still valid for SANDBOX.TPCH staging → mart transforms (source = staging table).

# When to Use
- Data is loaded into staging/raw; user wants to apply business transforms to mart/target
- User says "run the transform", "apply business logic", "refresh the model", "run dbt"
- Transforms previously failed and need to resume from checkpoint

# What This Skill Provides
Replaces brittle scripts that re-run from scratch on any failure. Uses Snowflake Streams +
Tasks or Dynamic Tables for incremental processing, with automatic resume, rollback on
threshold breach, and post-transform assertions.

# Instructions

## Step 1 — Determine transform strategy
Read `transform_mappings.yml` to identify whether Dynamic Table or Stream+Task pattern is needed.

- **Dynamic Table**: preferred for continuous/declarative transforms, no orchestration needed
- **Stream + Task**: needed when transform has side effects (alerts, external calls, multi-step logic)

## Step 2a — Dynamic Table approach (preferred)
Refresh the Dynamic Table:
```sql
-- Force immediate refresh (outside regular lag schedule)
ALTER DYNAMIC TABLE {database}.{schema}.{target_table} REFRESH;

-- Check refresh status
SELECT *
FROM INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
  NAME => '{database}.{schema}.{target_table}'
)
ORDER BY REFRESH_START_TIME DESC
LIMIT 5;
```

If lag is acceptable, verify the table is on schedule:
```sql
SHOW DYNAMIC TABLES LIKE '{target_table}' IN SCHEMA {database}.{schema};
```

## Step 2b — Stream + Task approach
### Create stream on source
```sql
CREATE STREAM IF NOT EXISTS {database}.{schema}.{source_table}_STREAM
  ON TABLE {database}.{schema}.{source_table}
  APPEND_ONLY = FALSE           -- capture inserts + updates + deletes
  COMMENT = 'Change stream for {source_table} → {target_table} transform';
```

### Create transform task
```sql
CREATE OR REPLACE TASK {database}.{schema}.{target_table}_TRANSFORM_TASK
  WAREHOUSE = ANALYTICS_WH
  SCHEDULE = '5 MINUTE'         -- or AFTER {parent_task}
  WHEN SYSTEM$STREAM_HAS_DATA('{database}.{schema}.{source_table}_STREAM')
AS
MERGE INTO {database}.{schema}.{target_table} AS tgt
USING (
    SELECT
        ORDER_ID::NUMBER(38,0)               AS order_id,
        TRY_TO_TIMESTAMP_LTZ(ORDER_DATE)     AS order_date,
        ROUND(AMOUNT::FLOAT, 2)              AS order_amount_usd,
        CASE STATUS
            WHEN 'C' THEN 'COMPLETED'
            WHEN 'P' THEN 'PENDING'
            WHEN 'X' THEN 'CANCELLED'
            ELSE 'UNKNOWN'
        END                                  AS order_status,
        METADATA$ACTION,
        METADATA$ISUPDATE,
        METADATA$ROW_ID
    FROM {database}.{schema}.{source_table}_STREAM
) AS src
ON tgt.order_id = src.order_id
WHEN MATCHED AND src.METADATA$ACTION = 'DELETE' THEN DELETE
WHEN MATCHED AND src.METADATA$ISUPDATE THEN
  UPDATE SET
    tgt.order_date        = src.order_date,
    tgt.order_amount_usd  = src.order_amount_usd,
    tgt.order_status      = src.order_status,
    tgt._LOADED_AT        = CURRENT_TIMESTAMP()
WHEN NOT MATCHED AND src.METADATA$ACTION = 'INSERT' THEN
  INSERT (order_id, order_date, order_amount_usd, order_status, _LOADED_AT, _SOURCE_SYSTEM)
  VALUES (src.order_id, src.order_date, src.order_amount_usd, src.order_status,
          CURRENT_TIMESTAMP(), '{source_name}');

-- Resume task
ALTER TASK {database}.{schema}.{target_table}_TRANSFORM_TASK RESUME;
```

## Step 3 — Self-healing: check for failed task runs
```sql
SELECT
    name,
    state,
    error_code,
    error_message,
    scheduled_time,
    completed_time
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => '{target_table}_TRANSFORM_TASK',
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
WHERE state = 'FAILED'
ORDER BY scheduled_time DESC;
```

If failed tasks found, diagnose and resume:
```sql
-- Suspend, fix, then resume
ALTER TASK {database}.{schema}.{target_table}_TRANSFORM_TASK SUSPEND;
-- [apply fix]
ALTER TASK {database}.{schema}.{target_table}_TRANSFORM_TASK RESUME;
-- Force an immediate run
EXECUTE TASK {database}.{schema}.{target_table}_TRANSFORM_TASK;
```

## Step 4 — Post-transform assertions
After transform completes, run quality assertions:
```sql
-- Row count sanity check
SELECT
    (SELECT COUNT(*) FROM {database}.{schema}.{source_table}) AS source_rows,
    (SELECT COUNT(*) FROM {database}.{schema}.{target_table}) AS target_rows,
    ABS(source_rows - target_rows)                            AS row_delta;
-- WARN if delta > 5%

-- Null check on critical output columns
SELECT COUNT(*) AS critical_nulls
FROM {database}.{schema}.{target_table}
WHERE order_id IS NULL OR order_date IS NULL;
-- FAIL if > 0

-- Freshness check
SELECT MAX(_LOADED_AT) AS last_loaded,
       DATEDIFF('minute', MAX(_LOADED_AT), CURRENT_TIMESTAMP()) AS minutes_stale
FROM {database}.{schema}.{target_table};
-- WARN if > 30 minutes
```

## Step 5 — dbt run (if dbt project exists)
```bash
# Check for dbt project
if [ -f "dbt_project.yml" ]; then
  dbt run --select stg_{source_name}+ --target prod
  dbt test --select stg_{source_name}+
fi
```

## Step 6 — Update status log
Append to `schema_design.md`:
```markdown
## Transform Log
- Run at: {timestamp}
- Strategy: Dynamic Table / Stream+Task
- Rows merged: {n} inserts, {n} updates, {n} deletes
- Post-transform assertions: PASS / FAIL
- Task state: RUNNING (scheduled every 5 min)
## Next Step
Run `$de-share` to configure access and sharing.
```

## Best Practices
- Prefer Dynamic Tables for simple column transforms — zero orchestration overhead
- Use Streams+Tasks when transforms have conditional logic or external dependencies
- Always check TASK_HISTORY for silent failures — tasks that "succeed" with 0 rows processed
- Set ALLOW_OVERLAPPING_EXECUTION = FALSE on tasks to prevent concurrent runs

# Examples

## Example 1: TPCH mart Dynamic Table
User: `$de-transform Refresh MART_ORDERS_ENRICHED`
Assistant: Reads transform_mappings.yml, runs ALTER DYNAMIC TABLE SANDBOX.TPCH.MART_ORDERS_ENRICHED REFRESH,
checks refresh history (success, ~15M rows), post-transform assertions: 0 critical nulls,
freshness 4 min stale — PASS.

