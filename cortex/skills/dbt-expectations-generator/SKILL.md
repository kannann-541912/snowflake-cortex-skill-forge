---
name: dbt-expectations-generator
description: "Generate dbt-expectations test cases for dbt models by profiling their materialized Snowflake output tables. Introspects column metadata, null rates, value distributions, ranges, and cardinality, then produces properly-formatted dbt_expectations tests merged into existing schema YAML files. Use when: generate dbt tests, add expectations, profile model, data quality tests for dbt, dbt-expectations, test generation."
---

# dbt-expectations Test Generator

## Core Rule
**Always profile the materialized model output in Snowflake first. Every test threshold (min/max, value sets, regex, freshness) must come from real data — never hardcoded. Smart-select columns: focus on PKs, timestamps, enums, and high-risk columns rather than testing everything.**

---

## When to Use

- User wants to add data quality tests to dbt models
- User says "generate tests for my model", "add expectations", "profile and test"
- User has a dbt project with models materialized in Snowflake
- User wants dbt-expectations (calogica/dbt_expectations) tests auto-generated from real data

---

## PHASE 1: Discover dbt Project & Target Models

### Step 1.1 — Locate the dbt project

Look for `dbt_project.yml` in the current directory or ask the user for the path.

```bash
find . -name "dbt_project.yml" -maxdepth 3 | head -5
```

Read `dbt_project.yml` to extract:
- `name` (project name)
- `vars.source_database` and `vars.source_schema`
- Model materializations and schema overrides per layer

### Step 1.2 — Ask which models to test

```
Which models do you want me to generate dbt-expectations tests for?

Examples:
  - fct_customer_orders
  - stg_customers, stg_orders
  - all models in models/marts/
```

### Step 1.3 — Verify dbt-expectations package is installed

Read `packages.yml` and confirm `calogica/dbt_expectations` is present.

If **missing**, warn the user:
```
⚠ calogica/dbt_expectations not found in packages.yml.
  I'll add it and you'll need to run `dbt deps` before testing.
```

Add to `packages.yml`:
```yaml
  - package: calogica/dbt_expectations
    version: [">=0.10.0", "<1.0.0"]
```

Also check if `dbt_date:time_zone` var is set in `dbt_project.yml` (required by dbt-expectations). If missing, add:
```yaml
vars:
  'dbt_date:time_zone': 'UTC'
```

### Step 1.4 — Read existing schema YAML

For each target model, find and read its schema YAML file:
- Staging models → `models/staging/_staging.yml` or `models/staging/_sources.yml`
- Intermediate → `models/intermediate/_intermediate.yml`
- Marts → `models/marts/_marts.yml`

Also check for any `schema.yml` or `*.yml` file in the same directory that contains the model definition.

Parse existing tests for each column to avoid generating duplicates.

---

## PHASE 2: Resolve the Model's Snowflake Table

### Step 2.1 — Determine the model's FQN

Build the fully-qualified Snowflake table name from:
- `database`: from `dbt_project.yml` vars or profile target database
- `schema`: from model config `+schema:` override, or `generate_schema_name` macro, or target schema
- `table_name`: same as model name (unless `alias` is set in config)

For common patterns:
- Staging models with `+schema: staging` → `{DATABASE}.STAGING.{MODEL_NAME}`
- Marts with `+schema: marts` → `{DATABASE}.MARTS.{MODEL_NAME}`
- No schema override → `{DATABASE}.{TARGET_SCHEMA}.{MODEL_NAME}`

### Step 2.2 — Verify the table exists

```sql
SELECT table_catalog, table_schema, table_name, row_count
FROM {DATABASE}.information_schema.tables
WHERE table_name = '{MODEL_NAME_UPPER}'
  AND table_schema = '{SCHEMA_UPPER}';
```

If not found, try common schema patterns (target schema, schema prefix variations). If still not found:
```
The model '{model_name}' doesn't appear to be materialized in Snowflake yet.
Please run: dbt run --select {model_name}
Then re-run this generator.
```

### Step 2.3 — Get column metadata

```sql
SELECT
    column_name,
    data_type,
    is_nullable,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    ordinal_position
FROM {DATABASE}.information_schema.columns
WHERE table_schema = '{SCHEMA}'
  AND table_name   = '{TABLE}'
ORDER BY ordinal_position;
```

---

## PHASE 3: Profile the Model's Data

### Step 3.1 — Core profiling query

Run a single comprehensive profiling query. Build it dynamically from the column metadata:

```sql
SELECT
    COUNT(*) AS total_rows,

    -- For each column: null count and distinct count
    COUNT_IF({col} IS NULL) AS null_count_{col},
    COUNT(DISTINCT {col})   AS distinct_count_{col},

    -- For NUMERIC columns: percentiles, mean, min, max
    MIN({numeric_col})                         AS min_{col},
    MAX({numeric_col})                         AS max_{col},
    AVG({numeric_col})                         AS mean_{col},
    STDDEV({numeric_col})                      AS stddev_{col},
    APPROX_PERCENTILE({numeric_col}, 0.01)     AS p01_{col},
    APPROX_PERCENTILE({numeric_col}, 0.05)     AS p05_{col},
    APPROX_PERCENTILE({numeric_col}, 0.50)     AS median_{col},
    APPROX_PERCENTILE({numeric_col}, 0.95)     AS p95_{col},
    APPROX_PERCENTILE({numeric_col}, 0.99)     AS p99_{col},

    -- For VARCHAR columns: length stats
    MIN(LENGTH({varchar_col}))  AS min_len_{col},
    MAX(LENGTH({varchar_col}))  AS max_len_{col},

    -- For TIMESTAMP/DATE columns: freshness
    MAX({timestamp_col})        AS max_ts_{col},
    MIN({timestamp_col})        AS min_ts_{col}

FROM {DATABASE}.{SCHEMA}.{TABLE};
```

**Important**: For wide tables (>30 columns), split into multiple queries to avoid SQL length limits.

### Step 3.2 — Value sets for low-cardinality columns

For columns where `distinct_count ≤ 30`, fetch the actual value set:

```sql
SELECT {col} AS val, COUNT(*) AS freq
FROM {DATABASE}.{SCHEMA}.{TABLE}
WHERE {col} IS NOT NULL
GROUP BY 1
ORDER BY freq DESC
LIMIT 30;
```

### Step 3.3 — Pattern detection for VARCHAR columns

For columns whose names match known patterns, sample values to confirm:

```sql
SELECT {col}, COUNT(*) AS cnt
FROM {DATABASE}.{SCHEMA}.{TABLE}
WHERE {col} IS NOT NULL
GROUP BY 1
LIMIT 10;
```

Patterns to detect:
- `*email*` → email regex
- `*phone*`, `*mobile*` → phone regex
- `*zip*`, `*postal*` → zip code regex
- `*url*`, `*link*`, `*href*` → URL regex
- `*uuid*`, `*guid*` → UUID regex
- `*ip*`, `*ip_address*` → IP address regex

---

## PHASE 4: Smart Column Selection

### Priority tiers for test generation:

**Tier 1 — Always test** (critical columns):
- Primary key columns: name contains `_id`, `_sk`, `_key`, or `distinct_count == total_rows`
- Timestamp columns: name ends with `_at`, `_date`, `_ts`, `_time`, `_timestamp`
- Status/enum columns: `distinct_count ≤ 20` AND name contains `status`, `type`, `category`, `tier`, `segment`, `level`

**Tier 2 — Test if interesting** (value-add columns):
- Numeric columns with clear natural bounds (amounts, percentages, counts)
- VARCHAR columns matching known patterns (email, phone, zip, url)
- Columns with suspiciously high null rates (1-10% null when they look like they shouldn't be)
- Boolean/flag columns

**Tier 3 — Skip** (low-value noise):
- High-cardinality VARCHAR columns (>1000 distinct, names like `description`, `notes`, `comment`, `address`, `name`)
- Columns that already have comprehensive tests (both not_null + unique + type-specific)
- Metadata columns: `dbt_updated_at`, `_loaded_at`, `_fivetran_synced`, `_sdc_*`
- Columns with 0 non-null values

Present the column selection to the user before generating:
```
Based on profiling, I'll generate tests for these columns:

TIER 1 (critical):
  ✓ customer_id (PK — unique, not null)
  ✓ order_date (timestamp — freshness)
  ✓ status (enum — 5 distinct values)

TIER 2 (value-add):
  ✓ total_amount (numeric — range check)
  ✓ email (pattern — regex check)

SKIPPING:
  ✗ description (high cardinality VARCHAR)
  ✗ notes (high cardinality VARCHAR)
  ✗ dbt_updated_at (metadata column)

Proceed with this selection? Or adjust?
```

---

## PHASE 5: Generate dbt-expectations Tests

### 5.1 — Test Selection Logic

Apply these rules based on profiling results. Use a **5% tolerance buffer** on numeric thresholds.

| Signal | Test | Parameters |
|--------|------|------------|
| **Table-level** | | |
| Always | `dbt_expectations.expect_table_row_count_to_be_between` | `min_value: total_rows * 0.8`, `max_value: total_rows * 1.5` |
| Has timestamp col | `dbt_expectations.expect_row_values_to_have_recent_data` | `datepart: day`, `interval: 2` (adjust based on freshness) |
| **Column-level: Nulls & Uniqueness** | | |
| null_rate = 0% | `not_null` (built-in) | — |
| null_rate < 1% | `dbt_expectations.expect_column_values_to_not_be_null` | `mostly: 0.99` |
| null_rate 1-5% | `dbt_expectations.expect_column_values_to_not_be_null` | `mostly: 0.95` |
| distinct_count = total_rows | `unique` (built-in) | — |
| PK column | `not_null` + `unique` (built-in) | — |
| **Column-level: Ranges (Numeric)** | | |
| Numeric column | `dbt_expectations.expect_column_values_to_be_between` | `min_value: p01 * 0.95`, `max_value: p99 * 1.05`, `mostly: 0.99` |
| Numeric column | `dbt_expectations.expect_column_mean_to_be_between` | `min_value: mean * 0.8`, `max_value: mean * 1.2` |
| Numeric column | `dbt_expectations.expect_column_stdev_to_be_between` | `min_value: stddev * 0.5`, `max_value: stddev * 2.0` |
| Percentage column (0-100) | `dbt_expectations.expect_column_values_to_be_between` | `min_value: 0`, `max_value: 100` |
| Non-negative column (amounts, counts) | `dbt_expectations.expect_column_min_to_be_between` | `min_value: 0`, `max_value: 0` |
| **Column-level: Sets** | | |
| distinct_count ≤ 20 | `dbt_expectations.expect_column_distinct_values_to_be_in_set` | `value_set: [<values>]` |
| distinct_count ≤ 20 | `dbt_expectations.expect_column_distinct_count_to_be_between` | `min_value: count * 0.8`, `max_value: count * 1.2` |
| Low distinct + stable | `accepted_values` (built-in) | `values: [<all_values>]` |
| **Column-level: Strings** | | |
| VARCHAR | `dbt_expectations.expect_column_value_lengths_to_be_between` | `min_value: min_len`, `max_value: max_len * 1.1` |
| Email pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$'`, `mostly: 0.99` |
| Phone pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^\\+?[0-9 \\-\\(\\)]{7,20}$'`, `mostly: 0.95` |
| ZIP pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^[0-9]{5}(-[0-9]{4})?$'`, `mostly: 0.99` |
| URL pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^https?://.+'`, `mostly: 0.95` |
| UUID pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'`, `mostly: 0.99` |
| **Column-level: Timestamps** | | |
| Timestamp (freshness) | `dbt_expectations.expect_column_max_to_be_between` | `min_value: <now - freshness_window>`, `max_value: <now>` |
| Timestamp (range) | `dbt_expectations.expect_column_values_to_be_between` | `min_value: '<min_date>'`, `max_value: '<max_date + buffer>'`, `mostly: 0.99` |
| Date ordering | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` | When `created_at` and `updated_at` both exist |
| **Column-level: Distribution** | | |
| Numeric + enough data | `dbt_expectations.expect_column_proportion_of_unique_values_to_be_between` | `min_value: proportion * 0.8`, `max_value: min(proportion * 1.2, 1.0)` |
| **Multi-column** | | |
| Compound PK (>1 PK col) | `dbt_expectations.expect_compound_columns_to_be_unique` | `column_list: [<pk_cols>]` |
| created_at + updated_at | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` | `column_A: updated_at`, `column_B: created_at`, `or_equal: true` |

### 5.2 — Skip logic

Do NOT generate a test if:
- The exact same test (same type + same params) already exists in the schema YAML
- A stronger built-in test already covers it (e.g., `not_null` already exists → skip `expect_column_values_to_not_be_null`)
- The column has 0 non-null values (no data to profile)
- The profiling result is degenerate (e.g., min == max for a "range" check)

### 5.3 — YAML output format

Generate tests in this format for the schema YAML:

**Model-level tests:**
```yaml
models:
  - name: {model_name}
    description: "{existing_description}"
    tests:
      - dbt_expectations.expect_table_row_count_to_be_between:
          min_value: {min_rows}
          max_value: {max_rows}
      - dbt_expectations.expect_row_values_to_have_recent_data:
          datepart: day
          interval: 2
          timestamp_column: {freshness_col}
```

**Column-level tests:**
```yaml
    columns:
      - name: {column_name}
        description: "{existing or generated description}"
        tests:
          - not_null
          - unique
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: {min}
              max_value: {max}
              mostly: 0.99
          - dbt_expectations.expect_column_mean_to_be_between:
              min_value: {mean_low}
              max_value: {mean_high}
```

---

## PHASE 6: Write to Schema YAML

### Step 6.1 — Read existing YAML

Parse the existing schema YAML file for the model. Identify:
- Existing model description (preserve)
- Existing model-level tests (preserve)
- Existing columns and their tests (preserve)
- Existing meta fields (preserve)

### Step 6.2 — Merge strategy

For each model:
1. **Preserve** all existing content (descriptions, meta, existing tests)
2. **Append** new tests to existing columns (after existing tests)
3. **Add** new column entries for columns not yet in the YAML
4. **Add** model-level tests if none exist
5. **Never remove** or modify existing tests

For new tests, add a comment or meta annotation:
```yaml
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 99999
              mostly: 0.99
              config:
                meta:
                  generated_by: dbt-expectations-generator
                  profiled_at: "{YYYY-MM-DD}"
                  baseline_rows: {total_rows}
```

### Step 6.3 — Write the merged YAML

Write the complete file back, preserving:
- `version: 2` header
- Proper 2-space indentation
- Existing comments where possible
- Alphabetical or ordinal column order (match existing convention)

---

## PHASE 7: Verification & Summary

### Step 7.1 — Validate

```bash
cd {dbt_project_path} && dbt compile --select {model_name}
```

If compilation errors occur, fix them (usually YAML indentation or quoting issues).

### Step 7.2 — Summary report

Present:

```
TEST GENERATION COMPLETE
════════════════════════

Model: {model_name}
Table profiled: {DATABASE}.{SCHEMA}.{TABLE}
Rows at profiling: {total_rows}
Columns profiled: {n_columns}
Tests generated: {n_tests}

┌─────────────────────┬─────────────────────────────────────────────────┬───────────────────┐
│ Column              │ Tests Added                                     │ Reasoning         │
├─────────────────────┼─────────────────────────────────────────────────┼───────────────────┤
│ (model-level)       │ expect_table_row_count_to_be_between            │ Always            │
│ (model-level)       │ expect_row_values_to_have_recent_data           │ Timestamp col     │
│ customer_id         │ not_null, unique                                │ PK (100% unique)  │
│ total_amount        │ expect_column_values_to_be_between (0–9999)     │ Numeric P1–P99    │
│ total_amount        │ expect_column_mean_to_be_between (120–180)      │ Mean stability    │
│ status              │ expect_column_distinct_values_to_be_in_set      │ 5 distinct values │
│ email               │ expect_column_values_to_match_regex             │ Email pattern     │
│ order_date          │ expect_column_max_to_be_between                 │ Freshness (2d)    │
└─────────────────────┴─────────────────────────────────────────────────┴───────────────────┘

Skipped columns:
  ✗ description — high cardinality VARCHAR (2,340 distinct)
  ✗ dbt_updated_at — metadata column

File modified: models/marts/_marts.yml

Next steps:
  1. Review the generated tests in {yaml_file}
  2. Adjust thresholds if needed (especially row_count and mean ranges)
  3. Run: dbt test --select {model_name}
  4. Commit the updated YAML
```

---

## Edge Cases

### Model not materialized yet
If the table doesn't exist in Snowflake, ask the user to run `dbt run --select <model>` first. Cannot profile data that doesn't exist.

### Ephemeral models
Ephemeral models have no Snowflake table. Offer to:
1. Profile the upstream source instead
2. Skip the model

### Views vs tables
Both work — views can be profiled the same way. Note that freshness tests on views may be slower due to on-the-fly computation.

### Wide tables (>50 columns)
Apply smart selection more aggressively — cap at 20-25 most important columns. Explicitly list skipped columns.

### Existing tests conflict
If a column already has `not_null`, don't add `expect_column_values_to_not_be_null`. If it already has `accepted_values`, don't add `expect_column_distinct_values_to_be_in_set`. Map equivalences:
- `not_null` ↔ `expect_column_values_to_not_be_null` (without mostly)
- `unique` ↔ `expect_column_values_to_be_unique`
- `accepted_values` ↔ `expect_column_values_to_be_in_set` / `expect_column_distinct_values_to_be_in_set`
- `relationships` ↔ (no dbt-expectations equivalent — skip)

### packages.yml missing dbt-expectations
Add the package and warn the user to run `dbt deps`.

### Multiple models in one YAML file
Merge only the target model's section — leave other models untouched.

### Zero rows in model
Skip all data-dependent tests. Generate only structural tests:
- `expect_column_to_exist` for all columns
- `expect_table_column_count_to_equal`
- `expect_table_columns_to_match_ordered_list`

---

## Regex Reference

| Pattern | Regex |
|---------|-------|
| Email | `'^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$'` |
| Phone | `'^\\+?[0-9 \\-\\(\\)]{7,20}$'` |
| US ZIP | `'^[0-9]{5}(-[0-9]{4})?$'` |
| URL | `'^https?://.+'` |
| UUID | `'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'` |
| IPv4 | `'^((25[0-5]\|2[0-4][0-9]\|[01]?[0-9][0-9]?)\\.){3}(25[0-5]\|2[0-4][0-9]\|[01]?[0-9][0-9]?)$'` |
| ISO Date | `'^\\d{4}-\\d{2}-\\d{2}$'` |
| ISO Timestamp | `'^\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}:\\d{2}'` |

---

## Tolerance Buffers

| Metric | Buffer |
|--------|--------|
| Row count | ±20% (min: 0.8×, max: 1.5×) |
| Numeric range (P1–P99) | ±5% on boundaries |
| Mean | ±20% |
| Stddev | 0.5×–2.0× |
| String length | min unchanged, max +10% |
| Distinct count | ±20% (or ±2 for very small sets) |
| Freshness | 2× the observed cadence (min 24h) |
| Proportion unique | ±20% (capped at 1.0) |

---

## Full dbt-expectations Test Reference (Available Tests)

### Table Shape
- `expect_table_row_count_to_be_between` — row count within range
- `expect_table_row_count_to_equal` — exact row count
- `expect_table_column_count_to_equal` — exact column count
- `expect_table_column_count_to_be_between` — column count range
- `expect_table_columns_to_match_ordered_list` — exact column order
- `expect_table_columns_to_match_set` — columns exist (any order)
- `expect_table_columns_to_contain_set` — subset of columns exists
- `expect_table_columns_to_not_contain_set` — columns don't exist
- `expect_row_values_to_have_recent_data` — freshness gate
- `expect_grouped_row_values_to_have_recent_data` — grouped freshness
- `expect_table_row_count_to_equal_other_table` — cross-table count match
- `expect_table_aggregation_to_equal_other_table` — cross-table agg match

### Nulls, Uniqueness, Types
- `expect_column_to_exist` — column existence
- `expect_column_values_to_not_be_null` — not null (with `mostly` support)
- `expect_column_values_to_be_null` — all null
- `expect_column_values_to_be_unique` — unique values
- `expect_column_values_to_be_of_type` — specific data type
- `expect_column_values_to_be_in_type_list` — one of several types
- `expect_column_values_to_have_consistent_casing` — case consistency

### Sets and Ranges
- `expect_column_values_to_be_in_set` — values in allowed set
- `expect_column_values_to_not_be_in_set` — values not in forbidden set
- `expect_column_values_to_be_between` — numeric/date range (with `mostly`)
- `expect_column_values_to_be_increasing` — monotonically increasing
- `expect_column_values_to_be_decreasing` — monotonically decreasing

### Strings
- `expect_column_value_lengths_to_be_between` — string length range
- `expect_column_value_lengths_to_equal` — exact string length
- `expect_column_values_to_match_regex` — regex match (with `mostly`)
- `expect_column_values_to_match_regex_list` — match any of N regexes
- `expect_column_values_to_not_match_regex` — regex exclusion
- `expect_column_values_to_match_like_pattern` — SQL LIKE pattern
- `expect_column_values_to_match_like_pattern_list` — match any LIKE
- `expect_column_values_to_not_match_like_pattern` — LIKE exclusion

### Aggregate Functions
- `expect_column_distinct_count_to_equal` — exact distinct count
- `expect_column_distinct_count_to_be_greater_than` — min distinct
- `expect_column_distinct_count_to_be_less_than` — max distinct
- `expect_column_distinct_values_to_be_in_set` — all distinct values in set
- `expect_column_distinct_values_to_contain_set` — distinct values contain subset
- `expect_column_distinct_values_to_equal_set` — exact distinct value set
- `expect_column_max_to_be_between` — max value range
- `expect_column_min_to_be_between` — min value range
- `expect_column_mean_to_be_between` — mean range
- `expect_column_median_to_be_between` — median range
- `expect_column_stdev_to_be_between` — standard deviation range
- `expect_column_sum_to_be_between` — sum range
- `expect_column_unique_value_count_to_be_between` — unique count range
- `expect_column_proportion_of_unique_values_to_be_between` — uniqueness ratio
- `expect_column_quantile_values_to_be_between` — quantile ranges
- `expect_column_most_common_value_to_be_in_set` — mode in expected set

### Multi-Column
- `expect_column_pair_values_A_to_be_greater_than_B` — column A > B
- `expect_column_pair_values_to_be_equal` — two columns equal
- `expect_column_pair_values_to_be_in_set` — pair combinations in set
- `expect_compound_columns_to_be_unique` — composite uniqueness
- `expect_multicolumn_sum_to_equal` — sum of columns equals value
- `expect_select_column_values_to_be_unique_within_record` — row-level uniqueness

### Distributional
- `expect_column_values_to_be_within_n_stdevs` — within N standard deviations
- `expect_column_values_to_be_within_n_moving_stdevs` — within N moving stdevs
- `expect_row_values_to_have_data_for_every_n_datepart` — no date gaps
