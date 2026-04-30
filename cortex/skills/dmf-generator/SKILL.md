---
name: dmf-generator
description: Generate Snowflake Data Metric Functions (DMFs) for data quality monitoring on any table or view. Introspects column metadata and real data distributions from Snowflake, then produces CREATE DATA METRIC FUNCTION statements, ALTER TABLE attachment DDL, and a monitoring query — covering nullness, uniqueness, value ranges, regex format checks, and freshness.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Write
---

# Snowflake Data Metric Function (DMF) Generator

## Core Rule
**Always introspect Snowflake first. Never assume column names, types, or data distributions. Run the metadata and profiling queries below before writing any DDL.**

---

## Step 1 — Resolve the fully-qualified object name
If the user provides a short name, resolve it:
```sql
SHOW TABLES LIKE '<table>';
-- or
SHOW VIEWS LIKE '<table>';
```
Obtain the full `<database>.<schema>.<table>` path from the result.

---

## Step 2 — Introspect column metadata
```sql
SELECT
    column_name,
    data_type,
    is_nullable,
    character_maximum_length,
    numeric_precision,
    numeric_scale
FROM <database>.information_schema.columns
WHERE table_schema = '<SCHEMA>'
  AND table_name   = '<TABLE>'
ORDER BY ordinal_position;
```

---

## Step 3 — Profile the data
Run a single batched profiling query (UNION ALL all columns) to get real thresholds:
```sql
SELECT
    '<col>'                           AS col_name,
    COUNT(*)                          AS total_rows,
    COUNT_IF(<col> IS NULL)           AS null_count,
    COUNT(DISTINCT <col>)             AS distinct_count,
    MIN(CAST(<col> AS VARCHAR))       AS min_val,
    MAX(CAST(<col> AS VARCHAR))       AS max_val,
    APPROX_PERCENTILE(<col>, 0.01)    AS p01,   -- numeric/date cols only
    APPROX_PERCENTILE(<col>, 0.99)    AS p99
FROM <database>.<schema>.<table>
```

For VARCHAR columns, also run:
```sql
SELECT MIN(LENGTH(<col>)) AS min_len, MAX(LENGTH(<col>)) AS max_len
FROM <database>.<schema>.<table>;
```

---

## Step 4 — Check for existing DMFs (avoid collisions)
```sql
SHOW DATA METRIC FUNCTIONS IN SCHEMA <database>.<schema>;
```

---

## Step 5 — Generate DMF definitions

Use naming convention: `dmf_<table>_<check>_<col>`

### 5a — NULL COUNT (every nullable column)
```sql
CREATE OR REPLACE DATA METRIC FUNCTION <schema>.dmf_<table>_null_count_<col>(
    arg_t TABLE (<col> <data_type>)
)
RETURNS NUMBER
AS $$
    SELECT COUNT_IF(<col> IS NULL) FROM arg_t
$$;
```

### 5b — DUPLICATE COUNT (PK-like columns: col name contains id/key/uuid/email, OR distinct_count = total_rows)
```sql
CREATE OR REPLACE DATA METRIC FUNCTION <schema>.dmf_<table>_duplicate_count_<col>(
    arg_t TABLE (<col> <data_type>)
)
RETURNS NUMBER
AS $$
    SELECT COUNT(*) - COUNT(DISTINCT <col>) FROM arg_t
$$;
```

### 5c — OUT OF RANGE (numeric / date / timestamp columns)
Populate min/max from p01/p99 in Step 3 profiling results.
```sql
CREATE OR REPLACE DATA METRIC FUNCTION <schema>.dmf_<table>_out_of_range_<col>(
    arg_t TABLE (<col> <data_type>)
)
RETURNS NUMBER
COMMENT = 'Rows outside expected range [<p01>, <p99>]'
AS $$
    SELECT COUNT_IF(<col> < <p01> OR <col> > <p99>) FROM arg_t
$$;
```

### 5d — FORMAT INVALID (VARCHAR columns whose name contains: email, phone, zip, postal, url, code)
Default regex patterns:
- email  → `'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'`
- phone  → `'^\+?[0-9 \-\(\)]{7,20}$'`
- zip    → `'^[0-9]{5}(-[0-9]{4})?$'`
- url    → `'^https?://.+'`

```sql
CREATE OR REPLACE DATA METRIC FUNCTION <schema>.dmf_<table>_format_invalid_<col>(
    arg_t TABLE (<col> VARCHAR)
)
RETURNS NUMBER
AS $$
    SELECT COUNT_IF(NOT REGEXP_LIKE(<col>, '<pattern>'))
    FROM arg_t
    WHERE <col> IS NOT NULL
$$;
```

### 5e — FRESHNESS (timestamp/date columns named *_at, *_time, *_date, *_ts)
```sql
CREATE OR REPLACE DATA METRIC FUNCTION <schema>.dmf_<table>_freshness_hours_<col>(
    arg_t TABLE (<col> TIMESTAMP_NTZ)
)
RETURNS NUMBER
COMMENT = 'Hours since the most recent record'
AS $$
    SELECT DATEDIFF('hour', MAX(<col>), CURRENT_TIMESTAMP()) FROM arg_t
$$;
```

### 5f — ROW COUNT (always generate one per table)
```sql
CREATE OR REPLACE DATA METRIC FUNCTION <schema>.dmf_<table>_row_count(
    arg_t TABLE (placeholder VARCHAR)
)
RETURNS NUMBER
AS $$
    SELECT COUNT(*) FROM arg_t
$$;
```

---

## Step 6 — Attach DMFs to the table
```sql
ALTER TABLE <database>.<schema>.<table>
    ADD DATA METRIC FUNCTION <schema>.dmf_<table>_null_count_<col>
    ON (<col>)
    SCHEDULE = ('60 MINUTE');
-- Repeat for each DMF
```

---

## Step 7 — Emit the monitoring query
```sql
SELECT
    metric_name,
    table_name,
    ref_entity_name AS column_name,
    value,
    measurement_time
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
    ref_entity_name   => '<database>.<schema>.<table>',
    ref_entity_domain => 'TABLE'
))
ORDER BY measurement_time DESC;
```

---

## Output Format
1. Summary table: `Column | Type | DMFs Generated`
2. All `CREATE DATA METRIC FUNCTION` statements — single SQL block
3. All `ALTER TABLE ... ADD DATA METRIC FUNCTION` statements — second SQL block
4. Monitoring query — third SQL block
5. Note any skipped columns and why

## Edge Cases
- **View target**: Generate DMFs but note they must be attached to the underlying base table. Identify it with `SELECT GET_DDL('VIEW', '<database>.<schema>.<view>')`.
- **Wide tables (>50 cols)**: Cap at 20 most important columns (PKs, timestamps, high-null). List skipped columns.
- **Name collisions**: Warn if a DMF with the same name already exists (from Step 4 check).
