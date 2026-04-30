---
name: gx-suite-generator
description: Generate a complete Great Expectations (GX) v1.x expectation suite for any Snowflake table or view. Introspects column metadata, primary keys, null rates, value distributions, and cardinality directly from Snowflake, then produces a ready-to-use expectations JSON file, a Snowflake datasource and checkpoint configuration in Python, and an optional Airflow integration task.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Write
---

# Great Expectations Suite Generator

## Core Rule
**Always profile Snowflake first. Every expectation threshold (min/max, value sets, regex, freshness) must come from real data — never hardcoded.**

---

## Step 1 — Confirm the target object exists
```sql
SELECT table_catalog, table_schema, table_name, table_type, row_count
FROM <database>.information_schema.tables
WHERE table_catalog = '<DATABASE>'
  AND table_schema  = '<SCHEMA>'
  AND table_name    = '<TABLE>';
```

---

## Step 2 — Introspect column metadata
```sql
SELECT
    column_name,
    data_type,
    is_nullable,
    character_maximum_length,
    numeric_precision,
    ordinal_position
FROM <database>.information_schema.columns
WHERE table_schema = '<SCHEMA>'
  AND table_name   = '<TABLE>'
ORDER BY ordinal_position;
```

Detect PKs:
```sql
SELECT kcu.column_name
FROM <database>.information_schema.table_constraints tc
JOIN <database>.information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema    = kcu.table_schema
WHERE tc.table_name      = '<TABLE>'
  AND tc.constraint_type = 'PRIMARY KEY';
```

---

## Step 3 — Statistical profiling

Run a batched UNION ALL query covering all columns:
```sql
SELECT
    COUNT(*)                                     AS total_rows,
    COUNT_IF(<col> IS NULL)                      AS null_count,
    COUNT(DISTINCT <col>)                        AS distinct_count,
    APPROX_PERCENTILE(TRY_CAST(<col> AS FLOAT), 0.01) AS p01,  -- numeric only
    APPROX_PERCENTILE(TRY_CAST(<col> AS FLOAT), 0.99) AS p99,  -- numeric only
    MIN(CAST(<col> AS VARCHAR))                  AS min_val,
    MAX(CAST(<col> AS VARCHAR))                  AS max_val,
    MIN(LENGTH(CAST(<col> AS VARCHAR)))          AS min_len,   -- varchar only
    MAX(LENGTH(CAST(<col> AS VARCHAR)))          AS max_len    -- varchar only
FROM <database>.<schema>.<table>;
```

For columns where `distinct_count ≤ 30`, also fetch the value set:
```sql
SELECT DISTINCT CAST(<col> AS VARCHAR) AS val, COUNT(*) AS freq
FROM <database>.<schema>.<table>
GROUP BY 1 ORDER BY freq DESC LIMIT 30;
```

---

## Step 4 — Build the expectation suite JSON

Apply a **5% tolerance buffer** on all numeric thresholds to avoid brittle tests.
Suite name default: `<table_name>_suite`.

```json
{
  "expectation_suite_name": "<table_name>_suite",
  "data_asset_type": "Dataset",
  "expectations": [

    {
      "expectation_type": "expect_table_row_count_to_be_between",
      "kwargs": {
        "min_value": "<total_rows * 0.8>",
        "max_value": "<total_rows * 1.2>"
      },
      "meta": {"notes": "Baseline: <total_rows> rows at profiling time"}
    },

    {
      "expectation_type": "expect_table_columns_to_match_ordered_list",
      "kwargs": {
        "column_list": ["<col1>", "<col2>", "..."]
      }
    },

    // -- Per-column: NOT NULL --
    // Generate when is_nullable='NO' OR (null_count/total_rows) < 0.01
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": {"column": "<col_name>"},
      "meta": {"notes": "Observed null rate: <null_pct>%"}
    },

    // -- Per-column: UNIQUE --
    // Generate when column is PK OR distinct_count == total_rows
    {
      "expectation_type": "expect_column_values_to_be_unique",
      "kwargs": {"column": "<pk_col>"}
    },

    // -- Per-column: RANGE (numeric / date / timestamp) --
    // Use p01 and p99 from profiling; mostly=0.99 for flexibility
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "<numeric_col>",
        "min_value": "<p01>",
        "max_value": "<p99>",
        "mostly": 0.99
      },
      "meta": {"notes": "P1–P99 range from profiling"}
    },

    // -- Per-column: ACCEPTED VALUES (distinct_count ≤ 30) --
    {
      "expectation_type": "expect_column_values_to_be_in_set",
      "kwargs": {
        "column": "<enum_col>",
        "value_set": ["<val1>", "<val2>", "..."]
      }
    },

    // -- Per-column: STRING LENGTH (VARCHAR) --
    {
      "expectation_type": "expect_column_value_lengths_to_be_between",
      "kwargs": {
        "column": "<varchar_col>",
        "min_value": "<min_len>",
        "max_value": "<max_len>"
      }
    },

    // -- Per-column: REGEX FORMAT --
    // Trigger: column name contains email, phone, zip, url, uuid
    // Patterns: email='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    //           phone='^\+?[0-9 \-\(\)]{7,20}$'
    //           zip='^[0-9]{5}(-[0-9]{4})?$'
    //           url='^https?://.+'
    {
      "expectation_type": "expect_column_values_to_match_regex",
      "kwargs": {
        "column": "<pattern_col>",
        "regex": "<pattern>",
        "mostly": 0.99
      }
    },

    // -- Per-column: FRESHNESS (timestamp columns named *_at, *_time, *_ts, *_date) --
    {
      "expectation_type": "expect_column_max_to_be_between",
      "kwargs": {
        "column": "<timestamp_col>",
        "min_value": "<ISO-8601 of NOW minus 48h>",
        "max_value": null,
        "parse_strings_as_datetimes": true
      },
      "meta": {"notes": "Freshness gate: last record must be within 48 hours"}
    }

  ],
  "meta": {
    "great_expectations_version": "1.0.0",
    "generated_by": "CoCo CLI — gx-suite-generator skill",
    "source_table": "<database>.<schema>.<table>",
    "profiled_at": "<UTC timestamp>",
    "total_rows_at_profiling": "<total_rows>"
  }
}
```

---

## Step 5 — Generate the GX Python datasource + checkpoint config

Save as `great_expectations/datasources/<project_name>_snowflake.py`.

```python
# great_expectations/datasources/<project_name>_snowflake.py
# Auto-generated by CoCo CLI — gx-suite-generator skill

import great_expectations as gx

context = gx.get_context()

# 1. Datasource
datasource = context.sources.add_snowflake(
    name      = "<project_name>_snowflake",
    account   = "${SNOWFLAKE_ACCOUNT}",
    user      = "${SNOWFLAKE_USER}",
    password  = "${SNOWFLAKE_PASSWORD}",
    database  = "<database>",
    schema    = "<schema>",
    warehouse = "${SNOWFLAKE_WAREHOUSE}",
    role      = "${SNOWFLAKE_ROLE}",
)

# 2. Data asset
data_asset    = datasource.add_table_asset(name="<table_name>", table_name="<table_name>")
batch_request = data_asset.build_batch_request()

# 3. Load suite
suite     = context.get_expectation_suite("<table_name>_suite")
validator = context.get_validator(batch_request=batch_request, expectation_suite=suite)

# 4. Checkpoint with Slack alerting on failure
checkpoint = context.add_or_update_checkpoint(
    name        = "<table_name>_checkpoint",
    validations = [{"batch_request": batch_request, "expectation_suite_name": "<table_name>_suite"}],
    action_list = [
        {"name": "store_validation_result", "action": {"class_name": "StoreValidationResultAction"}},
        {"name": "update_data_docs",        "action": {"class_name": "UpdateDataDocsAction"}},
        {
            "name":   "send_slack_notification",
            "action": {
                "class_name":    "SlackNotificationAction",
                "slack_webhook": "${SLACK_WEBHOOK_URL}",
                "notify_on":     "failure",
                "renderer": {
                    "module_name": "great_expectations.render.renderer.slack_renderer",
                    "class_name":  "SlackRenderer",
                }
            }
        },
    ],
)

if __name__ == "__main__":
    result = checkpoint.run()
    print("Validation passed!" if result.success else "Validation FAILED — check Data Docs")
```

---

## Step 6 — Optional Airflow integration task
Emit this snippet if the user also has an Airflow DAG:

```python
from airflow.operators.python import PythonOperator
import great_expectations as gx

def run_gx_checkpoint():
    context    = gx.get_context()
    checkpoint = context.get_checkpoint("<table_name>_checkpoint")
    result     = checkpoint.run()
    if not result.success:
        raise ValueError("GX validation failed for <table_name>. Check Data Docs.")

gx_validation = PythonOperator(
    task_id         = "gx_validate_<table_name>",
    python_callable = run_gx_checkpoint,
)
# Wire: run_<layer> >> gx_validation >> next_layer
```

---

## Output Format
1. `great_expectations/expectations/<table_name>_suite.json` — full suite
2. `great_expectations/datasources/<project_name>_snowflake.py` — datasource + checkpoint
3. Airflow snippet (separate block, labelled optional)
4. Summary table: `Column | Expectations Generated | Reason`
5. Setup note: required env vars, how to run (`python datasources/<project>.py`), how to view Data Docs (`gx docs build`)

## Expectation Selection Logic
| Signal | Expectation |
|---|---|
| `is_nullable='NO'` or null rate < 1% | `expect_column_values_to_not_be_null` |
| PK or distinct_count == total_rows | `expect_column_values_to_be_unique` |
| Numeric / Date / Timestamp | `expect_column_values_to_be_between` (P1–P99) |
| distinct_count ≤ 30 | `expect_column_values_to_be_in_set` |
| VARCHAR | `expect_column_value_lengths_to_be_between` |
| Col name: email/phone/zip/url | `expect_column_values_to_match_regex` |
| Col name: *_at/*_time/*_ts/*_date | `expect_column_max_to_be_between` (freshness) |
| Always | `expect_table_row_count_to_be_between`, `expect_table_columns_to_match_ordered_list` |

## Edge Cases
- **View as target**: Profile normally; note in meta that the underlying base table may need separate validation.
- **Wide tables (>50 cols)**: Generate expectations for all; group by type in JSON for readability.
- **GX v0.x users**: Note differences — `context.sources` vs `context.add_datasource`, JSON suite path changes.
- **Column with 0 distinct values**: Skip value-level expectations; emit only `not_be_null` with `mostly=0`.
