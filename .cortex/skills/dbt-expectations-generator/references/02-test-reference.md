# Full dbt-expectations Test Reference

Load this file when the user asks about available tests or you need to pick an uncommon test.

## Table Shape

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

## Nulls, Uniqueness, Types

- `expect_column_to_exist` — column existence
- `expect_column_values_to_not_be_null` — not null (with `mostly` support)
- `expect_column_values_to_be_null` — all null
- `expect_column_values_to_be_unique` — unique values
- `expect_column_values_to_be_of_type` — specific data type
- `expect_column_values_to_be_in_type_list` — one of several types
- `expect_column_values_to_have_consistent_casing` — case consistency

## Sets and Ranges

- `expect_column_values_to_be_in_set` — values in allowed set
- `expect_column_values_to_not_be_in_set` — values not in forbidden set
- `expect_column_values_to_be_between` — numeric/date range (with `mostly`)
- `expect_column_values_to_be_increasing` — monotonically increasing
- `expect_column_values_to_be_decreasing` — monotonically decreasing

## Strings

- `expect_column_value_lengths_to_be_between` — string length range
- `expect_column_value_lengths_to_equal` — exact string length
- `expect_column_values_to_match_regex` — regex match (with `mostly`)
- `expect_column_values_to_match_regex_list` — match any of N regexes
- `expect_column_values_to_not_match_regex` — regex exclusion
- `expect_column_values_to_match_like_pattern` — SQL LIKE pattern
- `expect_column_values_to_match_like_pattern_list` — match any LIKE
- `expect_column_values_to_not_match_like_pattern` — LIKE exclusion

## Aggregate Functions

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

## Multi-Column

- `expect_column_pair_values_A_to_be_greater_than_B` — column A > B
- `expect_column_pair_values_to_be_equal` — two columns equal
- `expect_column_pair_values_to_be_in_set` — pair combinations in set
- `expect_compound_columns_to_be_unique` — composite uniqueness
- `expect_multicolumn_sum_to_equal` — sum of columns equals value
- `expect_select_column_values_to_be_unique_within_record` — row-level uniqueness

## Distributional

- `expect_column_values_to_be_within_n_stdevs` — within N standard deviations
- `expect_column_values_to_be_within_n_moving_stdevs` — within N moving stdevs
- `expect_row_values_to_have_data_for_every_n_datepart` — no date gaps

## Regex Reference

| Pattern | Regex |
|---------|-------|
| Email | `'^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$'` |
| Phone | `'^\\+?[0-9 \\-\\(\\)]{7,20}$'` |
| US ZIP | `'^[0-9]{5}(-[0-9]{4})?$'` |
| URL | `'^https?://.+'` |
| UUID | `'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'` |
| IPv4 | `'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'` |
| ISO Date | `'^\\d{4}-\\d{2}-\\d{2}$'` |
| ISO Timestamp | `'^\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}:\\d{2}'` |
