---
name: de-profile
description: "Phase 1 — Auto-profile every column of a source table or stage: null rates, cardinality, data types, value distributions, anomalies, and PII candidates"
parent_skill: de-workflow
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Write
---

# Client Context
Read `../../references/client-context.md` at the start of every invocation. Apply any values it
defines as overrides: source database/schema, sampling rates, additional PII column patterns,
PII regex patterns, and anomaly thresholds. If the file is absent or a value is unset (`~`),
use the built-in defaults. Never fail if the file is missing.

After reading the file, run: `bash ../../hooks/pipeline-state.sh mark-refs-read`

# Domain Context
You are a Snowflake data profiler specializing in source data characterization. You understand
TPCH benchmark table schemas deeply and can identify PII candidates, anomalies, and
distribution patterns from SQL statistics alone.

# When to Use
- User wants to profile a TPCH source table before designing the target schema
- "profile the data", "analyze the source", "check null rates", "explore ORDERS table"
- Running Phase 1 of the DE workflow

# When NOT to Use
- Profile report already exists for this table — check for `profile_report.md` first
- User wants to generate tests for an already-profiled dbt model → use `dbt-expectations-generator`
- User wants to profile a staged file (CSV/JSON) → use INFER_SCHEMA instead

# Gotchas
- Never run `INFER_SCHEMA` on TPCH — it's a structured live database, not a staged file.
- Always sample large tables: LINEITEM needs 1% sample, ORDERS needs 5% — full scans time out.
- TPCH prices (O_TOTALPRICE, L_EXTENDEDPRICE, etc.) are FLOAT in source — flag them for NUMBER(15,2) cast in the design phase.
- LINEITEM has a composite PK (L_ORDERKEY + L_LINENUMBER) — never treat L_ORDERKEY alone as unique.
- Profile report must be written to a file before invoking de-schema-design.

# Standalone Quality Gate
Run this independently to verify a profile was completed:
```bash
test -f profile_report.md && echo "Profile exists ✓" || echo "MISSING — run de-profile first"
```

# Safety
- Source is `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10` — read-only. Never write to it.
- All profile queries run against `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.{table}` with a SAMPLE clause on large tables.

# Known Source Tables (TPCH_SF10)
Skip INFER_SCHEMA — the source is a structured live database, not a stage.
Use SHOW COLUMNS or DESCRIBE TABLE directly:

```sql
DESCRIBE TABLE SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.{table_name};
```

Pre-known approximate row counts (use for sampling decisions):
- LINEITEM ~60M → always sample: `SAMPLE (1 PERCENT)`
- ORDERS ~15M → sample: `SAMPLE (5 PERCENT)`
- CUSTOMER ~1.5M, PART ~2M, PARTSUPP ~8M → sample: `SAMPLE (10 PERCENT)`
- SUPPLIER ~100K, NATION 25, REGION 5 → full scan (no sampling needed)


- User provides a source table name, view, or external stage to profile
- User says "profile this table", "what does the data look like", or "analyze my source"
- Starting the AI-accelerated DE workflow from scratch

# What This Skill Provides
Automated column-level profiling that would take a human engineer 2–4 hours of manual
SQL sampling. Produces a structured profile report used by subsequent workflow phases.

# Instructions

## Step 0 — Load client context
Read `../../references/client-context.md`. If present, apply:
- `source_database` / `source_schema` → override built-in TPCH defaults
- `sampling.per_table_overrides` → override per-table sample percentages
- `pii_detection.additional_column_keywords` → extend built-in PII keyword list
- `pii_detection.additional_regex_patterns` → extend built-in PII regex patterns
- `anomaly_thresholds.*` → override null warn %, cardinality flags, stddev multiplier

## Step 1 — Discover the source
Confirm the table exists and retrieve column metadata:

```sql
DESCRIBE TABLE SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.{table_name};
```

For TPCH, skip INFER_SCHEMA entirely — these are structured relational tables, not staged files.
If the user hasn't specified a table, suggest profiling ORDERS or LINEITEM as the primary fact tables.


## Step 2 — Profile every column
For each column, execute the following profiling query (adapt per data type):

```sql
SELECT
  '{col_name}'                                        AS column_name,
  COUNT(*)                                            AS total_rows,
  COUNT({col_name})                                   AS non_null_count,
  COUNT(*) - COUNT({col_name})                        AS null_count,
  ROUND((COUNT(*) - COUNT({col_name})) * 100.0
        / NULLIF(COUNT(*), 0), 2)                     AS null_pct,
  COUNT(DISTINCT {col_name})                          AS distinct_count,
  ROUND(COUNT(DISTINCT {col_name}) * 100.0
        / NULLIF(COUNT(*), 0), 2)                     AS cardinality_pct,
  MIN({col_name})::VARCHAR                            AS min_value,
  MAX({col_name})::VARCHAR                            AS max_value,
  APPROX_TOP_K({col_name}, 5)                         AS top_5_values
FROM {fully_qualified_table_name};
```

For numeric columns, also capture:
```sql
SELECT
  AVG({col_name})   AS mean_val,
  STDDEV({col_name}) AS stddev_val,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY {col_name}) AS median_val
FROM {fully_qualified_table_name};
```

## Step 3 — Detect anomalies and PII candidates
Flag columns that match these patterns as PII candidates:
- Column name contains: `email`, `phone`, `ssn`, `dob`, `birth`, `address`, `zip`, `name`, `ip`
- String columns where >80% values match email regex: `[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`

Flag anomalies:
- Null rate > 50%: warn "high nullability — confirm if expected"
- Cardinality = 100% and row count > 1000: flag as "probable unique key / ID column"
- Cardinality = 1: flag as "constant column — verify if meaningful"
- Numeric columns with stddev > 3× mean: flag as "high variance — check for outliers"

## Step 4 — Write profile report
Save a profile report to `profile_report.md` in the working directory:

```markdown
# Data Profile Report
**Table:** {fully_qualified_table_name}
**Profiled at:** {timestamp}
**Total rows:** {row_count}

## Column Summary
| Column | Type | Null% | Distinct% | Min | Max | Flags |
|--------|------|-------|-----------|-----|-----|-------|
| ...    | ...  | ...   | ...       | ... | ... | ...   |

## PII Candidates
List columns flagged as PII with recommended masking policy type.

## Anomalies
List columns with anomalies and recommended actions.

## Recommended Primary Key
{column(s) with cardinality ~100% and null rate 0%}

## Next Step
Run `$de-schema-design` using this profile as input.
```

## Best Practices
- Profile on a `SAMPLE (10 PERCENT)` first for tables > 100M rows, then full scan for final report
- Use `ANALYTICS_WH` warehouse (X-Small) for profiling
- Always capture profiling timestamp — data profiles go stale quickly

## Common Patterns

### Pattern 1: Stage profiling
User: `$de-profile Profile files in @RAW.LANDING.ORDERS_STAGE`
→ Run INFER_SCHEMA, then profile the inferred columns against a sample query

### Pattern 2: Table profiling
User: `$de-profile Profile RAW.LANDING.ORDERS`
→ Run column metadata + profiling queries → generate report

# Examples

## Example 1: Profile ORDERS fact table
User: `$de-profile Profile SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.ORDERS`
Assistant: Runs DESCRIBE TABLE, profiles all 9 columns on a 5% sample (~750K rows),
identifies O_ORDERKEY as PK (100% cardinality, 0% nulls), O_COMMENT as low-value high-variance
text column, O_TOTALPRICE for numeric stats (mean, stddev, median), writes profile_report.md.

## Example 2: Profile LINEITEM (large table)
User: `$de-profile Profile LINEITEM`
Assistant: Uses SAMPLE (1 PERCENT) (~600K rows) for speed, identifies composite PK
(L_ORDERKEY + L_LINENUMBER), flags L_SHIPDATE / L_COMMITDATE / L_RECEIPTDATE for
TIMESTAMP_LTZ casting, reports profile_report.md.
