# Ingestion Objects Reference

These objects are managed via DCM (`DEFINE`) for stages and file formats,
and via imperative SQL (`CREATE OR REPLACE`) for streams, tasks, and pipes.

---

## 2.5 — Stages & File Formats → `ingestion/snowflake/stages.sql`

```sql
DEFINE FILE FORMAT <DATABASE>.<SCHEMA>.<FORMAT_NAME>
    TYPE = <type>
    <properties from GET_DDL>;

DEFINE STAGE <DATABASE>.<SCHEMA>.<STAGE_NAME>
    URL = '<url>'
    STORAGE_INTEGRATION = <integration_name>
    FILE_FORMAT = <DATABASE>.<SCHEMA>.<FORMAT_NAME>
    COMMENT = '<comment>';
```

---

## 2.6 — Streams → `ingestion/snowflake/streams.sql`

```sql
DEFINE STREAM <DATABASE>.<SCHEMA>.<STREAM_NAME>
    ON TABLE <source_table_fqn>
    [APPEND_ONLY = TRUE]         -- include if stream mode is APPEND_ONLY
    [SHOW_INITIAL_ROWS = TRUE]   -- include if present in source DDL
    COMMENT = '<comment>';
```

**Rules:**
- If the source table is a landing table, also generate its `DEFINE TABLE` in this file
- Streams on `SNOWFLAKE_SAMPLE_DATA` are meaningless — note this in a SQL comment

---

## 2.7 — Tasks → `ingestion/snowflake/tasks.sql`

Tasks use `CREATE OR REPLACE` (DCM has no DEFINE syntax for tasks).

```sql
-- ============================================================
-- Tasks — Imperative objects deployed via CI (CREATE OR REPLACE).
-- DCM does not manage tasks.
-- NOTE: Tasks are SUSPENDED by default after creation.
-- Resume with: ALTER TASK <task_name> RESUME;
-- ============================================================

CREATE OR REPLACE TASK <DATABASE>.<SCHEMA>.<TASK_NAME>
    WAREHOUSE = <warehouse>
    [SCHEDULE = '<schedule>']          -- e.g., '5 MINUTE', 'USING CRON 0 2 * * * UTC'
    [AFTER <predecessor_task_fqn>]     -- for task DAGs
    [WHEN system$stream_has_data('<stream_fqn>')]
    COMMENT = '<comment>'
AS
    <task body SQL or CALL statement>;

-- ALTER TASK <DATABASE>.<SCHEMA>.<TASK_NAME> RESUME;
```

---

## Pipes (Snowpipe) → `ingestion/snowflake/pipes.sql`

Pipes use `CREATE OR REPLACE` (DCM has no DEFINE syntax for pipes).

```sql
-- ============================================================
-- Snowpipe — Continuous auto-ingestion (CREATE OR REPLACE).
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
