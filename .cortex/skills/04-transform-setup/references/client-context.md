# Client Context — de-transform-setup

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$de-transform-setup` skill reads this file first and applies these settings as overrides.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## Snowflake Environment

```yaml
client_name: ~                        # e.g. "Acme Corp"
source_database: SNOWFLAKE_SAMPLE_DATA
source_schema: TPCH_SF10
target_database: SANDBOX
target_schema: TPCH
warehouse: ANALYTICS_WH
```

---

## Transform Strategy

> Controls what artifacts are generated as the primary transform mechanism.

```yaml
preferred_transform_engine: dynamic_table
# Options:
#   dynamic_table  — Snowflake Dynamic Tables (preferred; declarative, no orchestration)
#   stream_task    — Snowflake Streams + Tasks (use when transforms have side effects)
#   dbt            — dbt models only (use when client already has a dbt project)
#   both           — Generate both Dynamic Table DDL and dbt model stubs
```

---

## Dynamic Table Settings

> Used when `preferred_transform_engine` is `dynamic_table` or `both`.

```yaml
dynamic_table:
  default_target_lag: '1 hour'        # e.g. '1 minute', '1 hour', '1 day', 'downstream'
  refresh_mode: AUTO                  # AUTO | FULL | INCREMENTAL
  warehouse: ANALYTICS_WH
  initialize: ON_CREATE               # ON_CREATE | ON_SCHEDULE
```

---

## dbt Settings

> Used when `preferred_transform_engine` is `dbt` or `both`.

```yaml
dbt:
  project_path: ./dbt                 # Relative path to the dbt project root
  profile_name: ~                     # Profile name in profiles.yml; defaults to project name

  default_materialization: view       # view | table | incremental
  # Per-layer materializations:
  staging_materialization: view
  intermediate_materialization: table
  mart_materialization: incremental

  # Model file paths relative to dbt/models/
  staging_path: staging
  intermediate_path: intermediate
  mart_path: marts

  # Tags added to every generated model
  default_tags:
    - generated

  # Whether to generate sources.yml alongside models
  generate_sources_yml: true
```

---

## Type Cast Standards

> These are applied IN ADDITION to the skill's built-in TPCH cast rules.
> Map source column name patterns to target Snowflake types.

```yaml
type_cast_overrides: {}
# Example:
# type_cast_overrides:
#   FLOAT: NUMBER(15,2)          # Cast all FLOAT columns to NUMBER(15,2)
#   # Override by column name pattern:
#   "*_PRICE": NUMBER(15,2)
#   "*_AMOUNT": NUMBER(18,4)
#   "*_RATE": NUMBER(10,6)
#   "*_DATE": DATE
#   "*_TS": TIMESTAMP_LTZ
```

---

## Incremental Loading

```yaml
incremental:
  watermark_column: ~                 # Column used for incremental filtering
                                      # e.g. "_LOADED_AT" or "O_ORDERDATE"
  watermark_strategy: max_value       # max_value | date_window | sequence
  lookback_days: 3                    # Re-process N days of data to catch late-arriving rows
```

---

## Sample Testing

```yaml
sample_test:
  run_before_full_load: true          # Validate transforms against 100 rows before full load
  sample_row_count: 100
  fail_on_null_violation: true        # Abort if sample shows nulls in NOT NULL target columns
```

---

## Client Notes

```
# Add any client-specific transform rules here.
# Example:
#   - O_ORDERSTATUS codes must be decoded: 'O'→'OPEN', 'F'→'FULFILLED', 'P'→'PROCESSING'
#   - L_RETURNFLAG values must be decoded: 'A'→'ACCEPTED', 'N'→'NOT_RETURNED', 'R'→'RETURNED'
#   - All mart models must include a surrogate key column generated via dbt_utils.generate_surrogate_key
#   - TPCH FLOAT prices always cast to NUMBER(15,2) — no exceptions
```
