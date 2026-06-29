# Client Context — gx-suite-generator

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$gx-suite-generator` skill reads this file first and applies these settings
> as overrides over its built-in defaults.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials, webhook URLs, or Snowflake passwords to this file.**
> All credentials must be in environment variables.

---

## Snowflake Environment

```yaml
client_name: ~                        # e.g. "Acme Corp"
snowflake:
  account_env_var: SNOWFLAKE_ACCOUNT  # Name of the env var holding the account ID
  user_env_var: SNOWFLAKE_USER
  password_env_var: SNOWFLAKE_PASSWORD
  warehouse_env_var: SNOWFLAKE_WAREHOUSE
  role_env_var: SNOWFLAKE_ROLE
  database: ~                         # e.g. "ANALYTICS_DB"
  schema: ~                           # e.g. "CORE"
```

---

## GX Version and Project Layout

```yaml
gx:
  version: 1.x                        # 1.x | 0.x (legacy)
  # 1.x uses context.sources.add_snowflake() and add_or_update_checkpoint()
  # 0.x uses context.add_datasource() and context.add_expectation_suite()
  # ALWAYS default to 1.x — only set 0.x if client is on legacy GX

  expectations_dir: great_expectations/expectations
  datasources_dir: great_expectations/datasources
  checkpoints_dir: great_expectations/checkpoints
  data_docs_dir: great_expectations/uncommitted/data_docs
```

---

## Expectation Thresholds

```yaml
thresholds:
  row_count_tolerance_pct: 20         # Row count window: ±N% from baseline
  numeric_range_tolerance_pct: 5      # P01/P99 range buffer: ±N%
  mostly_default: 0.99                # Default "mostly" value for range/format checks
  # Raise mostly to 1.0 for zero-tolerance clients (strict financial data quality)
  # Lower to 0.95 for clients with known dirty data (legacy system migration)

  freshness_warn_hours: 48            # Freshness gate: warn if last record > N hours old
  value_set_max_distinct: 30          # Only generate accepted_values tests when distinct ≤ N
```

---

## Alerting

```yaml
alerting:
  slack:
    enabled: false
    webhook_env_var: SLACK_WEBHOOK_URL  # env var name holding the Slack webhook URL
    notify_on: failure                  # failure | all
  email:
    enabled: false
    # Note: GX email alerting requires a custom action — document in generated file
    email_address: ~
```

---

## Airflow Integration

```yaml
airflow:
  generate_snippet: false             # true = also generate the Airflow PythonOperator snippet
  dag_task_id_template: "gx_validate_{table_name}"
```

---

## Expectation Categories

```yaml
expectation_types:
  table_row_count: true               # expect_table_row_count_to_be_between
  column_order: true                  # expect_table_columns_to_match_ordered_list
  not_null: true                      # expect_column_values_to_not_be_null
  unique: true                        # expect_column_values_to_be_unique
  range: true                         # expect_column_values_to_be_between
  accepted_values: true               # expect_column_values_to_be_in_set
  string_length: true                 # expect_column_value_lengths_to_be_between
  regex_format: true                  # expect_column_values_to_match_regex
  freshness: true                     # expect_column_max_to_be_between (timestamp cols)
```

---

## Client Notes

```
# Add any client-specific GX suite requirements here.
# Example:
#   - Client uses GX 0.x (legacy) — set gx.version: 0.x
#   - Strict financial data: set mostly_default: 1.0 (no tolerance for out-of-range)
#   - Row count window should be ±5% (not ±20%) — tightly controlled data volumes
#   - Slack webhook env var is ACME_SLACK_DQ_WEBHOOK (not the default)
#   - Airflow snippet required — client uses Airflow for GX checkpoint orchestration
#   - Do not generate expectations for COMMENT columns (cardinality too high)
```
