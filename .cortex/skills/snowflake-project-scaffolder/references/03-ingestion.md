# Ingestion Pipeline Reference

## ingestion/snowflake/setup_streams_tasks.sql

```sql
-- ingestion/snowflake/setup_streams_tasks.sql
-- Idempotent — safe to re-run

USE ROLE {DEFAULT_ROLE};
USE DATABASE {DATABASE};
USE SCHEMA {SCHEMA};

-- Stream on landing table (captures inserts/updates/deletes)
CREATE STREAM IF NOT EXISTS {TABLE_NAME}_STREAM
  ON TABLE {TABLE_NAME}
  SHOW_INITIAL_ROWS = TRUE
  COMMENT = 'CDC stream for {TABLE_NAME} → {TABLE_NAME}_TRANSFORM_TASK';

-- Transform task (runs every 5 minutes when stream has data)
CREATE TASK IF NOT EXISTS {TABLE_NAME}_TRANSFORM_TASK
  WAREHOUSE = TRANSFORM_WH
  SCHEDULE  = '5 MINUTE'
  WHEN system$stream_has_data('{TABLE_NAME}_STREAM')
AS
  CALL {TABLE_NAME}_TRANSFORM_SP();

-- NOTE: Tasks are SUSPENDED by default.
-- Resume with: ALTER TASK {TABLE_NAME}_TRANSFORM_TASK RESUME;
```

## ingestion/snowflake/copy_into.sql

```sql
-- ingestion/snowflake/copy_into.sql
-- COPY INTO pattern for file-based ingestion

USE ROLE {DEFAULT_ROLE};
USE WAREHOUSE {WAREHOUSE};
USE DATABASE {DATABASE};
USE SCHEMA {SCHEMA};

CREATE STAGE IF NOT EXISTS {TABLE_NAME}_STAGE
  FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1 EMPTY_FIELD_AS_NULL = TRUE)
  COMMENT = 'Landing stage for {TABLE_NAME} raw files';

COPY INTO {TABLE_NAME}
FROM @{TABLE_NAME}_STAGE
  PATTERN         = '.*{table_name_lower}.*\.csv'
  ON_ERROR        = 'CONTINUE'
  PURGE           = FALSE
  FORCE           = FALSE;
```

## ingestion/snowpark/loader.py

```python
"""ingestion/snowpark/loader.py — Snowpark batch loader."""
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, current_timestamp, lit


def load_table(session: Session, source: str, target: str, table: str) -> dict:
    """Load from source schema to target schema with audit columns."""
    df = session.table(f"{source}.{table}")
    df = df.with_column("_LOADED_AT", current_timestamp())
    df = df.with_column("_SOURCE_SYSTEM", lit(source))

    df.write.mode("append").save_as_table(f"{target}.{table}")

    row_count = session.table(f"{target}.{table}").count()
    return {"table": table, "rows_loaded": row_count}


if __name__ == "__main__":
    import toml
    cfg = toml.load("config.toml")["connections"]["default"]
    session = Session.builder.configs(cfg).create()
    result = load_table(session, "{DATABASE}.{LANDING_SCHEMA}", "{DATABASE}.{SCHEMA}", "{TABLE_NAME}")
    print(result)
    session.close()
```

## ingestion/openflow/setup/connector_setup.sql

```sql
-- ingestion/openflow/setup/connector_setup.sql
-- Openflow connector setup (Snowflake Native App)
-- Adjust source_type and connection params for your connector

CREATE OPENFLOW CONNECTION IF NOT EXISTS {TABLE_NAME_LOWER}_conn
  TYPE = 'JDBC'
  CONNECTION_URL = '<source_jdbc_url>'
  USER = '<source_user>'
  PASSWORD = SECRET {TABLE_NAME}_SRC_SECRET;

CREATE OPENFLOW FLOW IF NOT EXISTS {TABLE_NAME_LOWER}_flow
  SOURCE   = {TABLE_NAME_LOWER}_conn
  TARGET   = TABLE {DATABASE}.{SCHEMA}.{TABLE_NAME}
  SCHEDULE = INTERVAL '5 MINUTES'
  OPTIONS  (MODE = 'APPEND');
```
