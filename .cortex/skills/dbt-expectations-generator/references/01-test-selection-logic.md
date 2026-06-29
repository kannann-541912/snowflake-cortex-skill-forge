# Test Selection Logic Reference

## Phase 5 — Test Selection by Signal

Apply these rules based on profiling results. Use a **5% tolerance buffer** on numeric thresholds.

| Signal | Test | Parameters |
|--------|------|------------|
| **Table-level** | | |
| Always | `dbt_expectations.expect_table_row_count_to_be_between` | `min_value: total_rows * 0.8`, `max_value: total_rows * 1.5` |
| Has timestamp col | `dbt_expectations.expect_row_values_to_have_recent_data` | `datepart: day`, `interval: 2` |
| **Nulls & Uniqueness** | | |
| null_rate = 0% | `not_null` (built-in) | — |
| null_rate < 1% | `dbt_expectations.expect_column_values_to_not_be_null` | `mostly: 0.99` |
| null_rate 1–5% | `dbt_expectations.expect_column_values_to_not_be_null` | `mostly: 0.95` |
| distinct_count = total_rows | `unique` (built-in) | — |
| PK column | `not_null` + `unique` (built-in) | — |
| **Numeric Ranges** | | |
| Numeric column | `dbt_expectations.expect_column_values_to_be_between` | `min_value: p01 * 0.95`, `max_value: p99 * 1.05`, `mostly: 0.99` |
| Numeric column | `dbt_expectations.expect_column_mean_to_be_between` | `min_value: mean * 0.8`, `max_value: mean * 1.2` |
| Numeric column | `dbt_expectations.expect_column_stdev_to_be_between` | `min_value: stddev * 0.5`, `max_value: stddev * 2.0` |
| Percentage col (0–100) | `dbt_expectations.expect_column_values_to_be_between` | `min_value: 0`, `max_value: 100` |
| Non-negative (amounts) | `dbt_expectations.expect_column_min_to_be_between` | `min_value: 0`, `max_value: 0` |
| **Sets** | | |
| distinct_count ≤ 20 | `dbt_expectations.expect_column_distinct_values_to_be_in_set` | `value_set: [<values>]` |
| distinct_count ≤ 20 | `dbt_expectations.expect_column_distinct_count_to_be_between` | `min_value: count * 0.8`, `max_value: count * 1.2` |
| Low distinct + stable | `accepted_values` (built-in) | `values: [<all_values>]` |
| **Strings** | | |
| VARCHAR | `dbt_expectations.expect_column_value_lengths_to_be_between` | `min_value: min_len`, `max_value: max_len * 1.1` |
| Email pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$'`, `mostly: 0.99` |
| Phone pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^\\+?[0-9 \\-\\(\\)]{7,20}$'`, `mostly: 0.95` |
| ZIP pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^[0-9]{5}(-[0-9]{4})?$'`, `mostly: 0.99` |
| URL pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^https?://.+'`, `mostly: 0.95` |
| UUID pattern | `dbt_expectations.expect_column_values_to_match_regex` | `regex: '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'`, `mostly: 0.99` |
| **Timestamps** | | |
| Timestamp (freshness) | `dbt_expectations.expect_column_max_to_be_between` | `min_value: <now - freshness_window>`, `max_value: <now>` |
| Timestamp (range) | `dbt_expectations.expect_column_values_to_be_between` | `min_value: '<min_date>'`, `max_value: '<max_date + buffer>'`, `mostly: 0.99` |
| Date ordering | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` | When `created_at` and `updated_at` both exist |
| **Distribution** | | |
| Numeric + enough data | `dbt_expectations.expect_column_proportion_of_unique_values_to_be_between` | `min_value: proportion * 0.8`, `max_value: min(proportion * 1.2, 1.0)` |
| **Multi-column** | | |
| Compound PK (>1 PK col) | `dbt_expectations.expect_compound_columns_to_be_unique` | `column_list: [<pk_cols>]` |
| created_at + updated_at | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` | `column_A: updated_at`, `column_B: created_at`, `or_equal: true` |

## Skip Logic

Do NOT generate a test if:
- The exact same test (same type + same params) already exists in the schema YAML
- A stronger built-in test already covers it (e.g., `not_null` already exists → skip `expect_column_values_to_not_be_null`)
- The column has 0 non-null values
- The profiling result is degenerate (e.g., min == max for a "range" check)
- The column is in Tier 3 (see Phase 4 in SKILL.md)

Built-in equivalences (avoid duplication):
- `not_null` ↔ `expect_column_values_to_not_be_null` (without mostly)
- `unique` ↔ `expect_column_values_to_be_unique`
- `accepted_values` ↔ `expect_column_distinct_values_to_be_in_set`

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
