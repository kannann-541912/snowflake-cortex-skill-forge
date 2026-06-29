---
name: dbt-expectations-generator
description: >
  Generate dbt-expectations test cases for dbt models by profiling their materialized
  Snowflake tables. Introspects column metadata, null rates, value distributions, ranges,
  and cardinality, then produces dbt_expectations tests merged into existing schema YAML files.
  Use when: generate dbt tests, add expectations, profile model, data quality tests for dbt,
  dbt-expectations, test generation.
tools:
  - snowflake_sql_execute
  - Read
  - Write
  - Bash
---

# dbt-expectations Test Generator

# Client Context
Read `references/client-context.md` at the start of every invocation. Apply any values it
defines as overrides: dbt project path and schema names, test coverage tier, threshold
tolerances (row count window, numeric range buffer, mostly value), column skip rules,
freshness thresholds, and YAML merge behavior. If the file is absent or a value is unset
(`~`), use the built-in defaults. Never fail if the file is missing.

## Core Rule

**Always profile the materialized model output in Snowflake first. Every test threshold
(min/max, value sets, regex, freshness) must come from real data — never hardcoded.
Smart-select columns: focus on PKs, timestamps, enums, and high-risk columns rather than
testing everything.**

## Domain Context

You are a dbt data quality SME specializing in automated test generation from observed data
distributions. You understand when to apply built-in dbt tests vs dbt-expectations tests,
how to set conservative thresholds that don't false-positive on normal data variance, and
how to merge generated tests into existing schema YAML without overwriting existing work.

## When to Use

- User wants to add data quality tests to dbt models
- "generate tests for my model", "add expectations", "profile and test"
- User has a dbt project with models materialized in Snowflake
- User wants dbt-expectations (calogica/dbt_expectations) auto-generated from real data

## When NOT to Use

- User wants hand-written, custom dbt tests (just help them write YAML directly)
- The dbt model is not yet materialized — prompt them to run `dbt run` first
- User only wants to check if dbt is set up → use `de-transform-setup` instead
- User wants generic profiling without test generation → use `de-profile` instead

## Gotchas

- Never hardcode thresholds — always derive them from the profiling query results.
- Wide tables (>30 columns): split profiling into multiple queries to avoid SQL length limits.
- Ephemeral models have no Snowflake table — offer to profile the upstream source instead.
- `dbt_date:time_zone` var must be set in `dbt_project.yml` or dbt-expectations will error.
- Do not apply freshness tests to static/seed tables (they will always fail).
- When merging YAML: preserve all existing content — never remove or modify existing tests.
- `accepted_values` (built-in) and `expect_column_distinct_values_to_be_in_set` are equivalent — don't generate both.

## Phase 1 — Discover dbt Project & Target Models

### Step 0 — Load client context
Read `references/client-context.md`. If present, apply:
- `dbt.project_path` / `dbt.schema_files` → override project location and schema file names
- `test_coverage.tier` → tier1 | tier1_tier2 | all
- `thresholds.*` → row count tolerance, numeric range buffer, mostly, freshness thresholds
- `skip_columns.*` → metadata columns skip flag and additional patterns to skip
- `yaml_merge.*` → indentation, sort order, append-only flag

### Step 1.1 — Locate the dbt project

```bash
find . -name "dbt_project.yml" -maxdepth 3 | head -5
```

Read `dbt_project.yml` for: project name, `vars.source_database`, `vars.source_schema`,
and model materializations per layer.

### Step 1.2 — Ask which models to test

```
Which models do you want me to generate dbt-expectations tests for?
Examples: fct_customer_orders | stg_customers, stg_orders | all models in models/marts/
```

### Step 1.3 — Verify dbt-expectations is installed

Read `packages.yml` and confirm `calogica/dbt_expectations` is present. If missing, add:
```yaml
  - package: calogica/dbt_expectations
    version: [">=0.10.0", "<1.0.0"]
```
Warn the user to run `dbt deps`. Also ensure `vars: 'dbt_date:time_zone': 'UTC'` is set.

### Step 1.4 — Read existing schema YAML

For each target model, read its schema YAML to parse existing tests and avoid duplicates.
- Staging → `models/staging/_staging.yml` / `_sources.yml`
- Intermediate → `models/intermediate/_intermediate.yml`
- Marts → `models/marts/_marts.yml`

---

## Phase 2 — Resolve the Model's Snowflake Table

### Step 2.1 — Determine FQN

Build the fully-qualified Snowflake table name from `dbt_project.yml` schema config:
- `+schema: staging` → `{DATABASE}.STAGING.{MODEL_NAME}`
- `+schema: marts` → `{DATABASE}.MARTS.{MODEL_NAME}`
- No override → `{DATABASE}.{TARGET_SCHEMA}.{MODEL_NAME}`

### Step 2.2 — Verify the table exists

```sql
SELECT table_catalog, table_schema, table_name, row_count
FROM {DATABASE}.information_schema.tables
WHERE table_name = '{MODEL_NAME_UPPER}' AND table_schema = '{SCHEMA_UPPER}';
```

If not found, ask user to run `dbt run --select {model_name}` first.

### Step 2.3 — Get column metadata

```sql
SELECT column_name, data_type, is_nullable, character_maximum_length,
       numeric_precision, numeric_scale, ordinal_position
FROM {DATABASE}.information_schema.columns
WHERE table_schema = '{SCHEMA}' AND table_name = '{TABLE}'
ORDER BY ordinal_position;
```

---

## Phase 3 — Profile the Model's Data

Run a single comprehensive query (split for >30 columns):

```sql
SELECT
    COUNT(*) AS total_rows,
    -- Per column: null count, distinct count
    COUNT_IF({col} IS NULL)  AS null_count_{col},
    COUNT(DISTINCT {col})    AS distinct_count_{col},
    -- Numeric: percentiles, mean, stddev
    MIN({num_col})                     AS min_{col},
    MAX({num_col})                     AS max_{col},
    AVG({num_col})                     AS mean_{col},
    STDDEV({num_col})                  AS stddev_{col},
    APPROX_PERCENTILE({num_col}, 0.01) AS p01_{col},
    APPROX_PERCENTILE({num_col}, 0.99) AS p99_{col},
    -- VARCHAR: length stats
    MIN(LENGTH({str_col}))  AS min_len_{col},
    MAX(LENGTH({str_col}))  AS max_len_{col},
    -- Timestamps: freshness
    MAX({ts_col}) AS max_ts_{col},
    MIN({ts_col}) AS min_ts_{col}
FROM {DATABASE}.{SCHEMA}.{TABLE};
```

For columns where `distinct_count ≤ 30`, also fetch the value set:
```sql
SELECT {col} AS val, COUNT(*) AS freq
FROM {DATABASE}.{SCHEMA}.{TABLE}
WHERE {col} IS NOT NULL GROUP BY 1 ORDER BY freq DESC LIMIT 30;
```

---

## Phase 4 — Smart Column Selection

**Tier 1 — Always test**: PK columns (`_id`, `_sk`, `_key` or distinct = total_rows),
timestamp columns (`_at`, `_date`, `_ts`), status/enum columns (distinct ≤ 20 + contains
`status`, `type`, `category`, `tier`, `segment`).

**Tier 2 — Test if interesting**: numeric columns with natural bounds, VARCHAR with known
patterns (email, phone, zip, url), high null rate columns, booleans.

**Tier 3 — Skip**: high-cardinality VARCHAR (>1000 distinct, names like `description`,
`notes`, `comment`), columns with 0 non-null values, metadata columns (`_loaded_at`,
`_fivetran_synced`, `dbt_updated_at`).

Present the selection to the user and confirm before generating.

---

## Phase 5 — Generate Tests

Read [references/01-test-selection-logic.md](references/01-test-selection-logic.md) for
the complete test selection table (40+ signal → test mappings) and tolerance buffers.

Read [references/02-test-reference.md](references/02-test-reference.md) for the full
list of available dbt-expectations tests when you need to pick a less common test.

YAML output format for generated tests:

```yaml
models:
  - name: {model_name}
    tests:
      - dbt_expectations.expect_table_row_count_to_be_between:
          min_value: {min_rows}
          max_value: {max_rows}
    columns:
      - name: {column_name}
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: {min}
              max_value: {max}
              mostly: 0.99
              config:
                meta:
                  generated_by: dbt-expectations-generator
                  profiled_at: "{YYYY-MM-DD}"
                  baseline_rows: {total_rows}
```

---

## Phase 6 — Write to Schema YAML

1. Read the existing YAML file completely.
2. **Preserve all** existing content: descriptions, meta fields, existing tests.
3. **Append** new tests to existing columns (after existing tests).
4. **Add** new column entries for columns not yet in the YAML.
5. **Never remove** existing tests.
6. Write back with `version: 2` header, 2-space indentation, and alphabetical column order.

---

## Phase 7 — Verification & Summary

```bash
cd {dbt_project_path} && dbt compile --select {model_name}
```

Fix any YAML indentation or quoting errors, then present a summary table showing:
- model name, table profiled, row count, columns profiled, tests generated
- Per-column: tests added and reasoning
- Skipped columns with reason
- Next steps: review YAML → adjust thresholds → `dbt test --select {model_name}` → commit

---

## Edge Cases

| Situation | Action |
|---|---|
| Model not materialized | Ask user to run `dbt run --select {model_name}` first |
| Ephemeral model | Offer to profile upstream source instead |
| Views vs tables | Profile identically — note freshness tests may be slower |
| Wide tables >50 cols | Cap at 20–25 most important columns; list all skipped |
| packages.yml missing | Add package and warn to run `dbt deps` |
| Multiple models in one YAML | Merge only the target model section — leave others untouched |
| Zero rows | Generate only structural tests: `expect_column_to_exist`, `expect_table_column_count_to_equal` |
