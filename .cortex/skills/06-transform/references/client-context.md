# Client Context — de-transform

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$de-transform` skill reads this file first and applies these settings as overrides.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## Snowflake Environment

```yaml
client_name: ~                        # e.g. "Acme Corp"
source_database: SANDBOX
source_schema: TPCH
target_database: SANDBOX
target_schema: TPCH
warehouse: ANALYTICS_WH
```

---

## Transform Engine Preference

```yaml
preferred_engine: dynamic_table       # dynamic_table | stream_task | dbt
# dynamic_table  — Declarative; Snowflake manages refresh scheduling automatically.
#                  Best for: pure SELECT transforms, continuous/near-real-time models.
#                  Limitation: no side effects; source must support change tracking.
# stream_task    — Imperative; Task runs on a schedule or when stream has data.
#                  Best for: transforms with side effects, multi-step logic, external calls.
# dbt            — dbt run via shell; requires a dbt project to be present.
#                  Best for: clients already using dbt as their transform layer.
```

---

## Dynamic Table Settings

> Used when `preferred_engine` is `dynamic_table`.

```yaml
dynamic_table:
  default_target_lag: '1 hour'        # e.g. '1 minute', '1 hour', '7 days', 'downstream'
  refresh_mode: AUTO                  # AUTO | FULL | INCREMENTAL
  initialize: ON_CREATE               # ON_CREATE | ON_SCHEDULE
  resume_after_create: true           # Always ALTER DYNAMIC TABLE ... RESUME after CREATE
```

---

## Stream + Task Settings

> Used when `preferred_engine` is `stream_task`.

```yaml
stream_task:
  task_schedule: '5 MINUTE'           # Schedule expression, e.g. '5 MINUTE', '0 * * * *'
  stream_mode: all                    # all | append_only
  # all         — Captures INSERT + UPDATE + DELETE (use for SCD2 or MERGE patterns)
  # append_only — Captures INSERT only (more efficient; use for append-only fact tables)

  allow_overlapping_execution: false  # Prevent concurrent task runs
  resume_after_create: true           # Always ALTER TASK ... RESUME after CREATE
  warehouse: ANALYTICS_WH
```

---

## Post-Transform Quality Assertions

```yaml
quality_assertions:
  run_after_transform: true
  row_delta_warn_pct: 5               # WARN if source/target row count delta > N%
  critical_null_fail: true            # FAIL if any critical column has null values
  freshness_warn_minutes: 30          # WARN if _LOADED_AT is older than N minutes
  freshness_fail_minutes: ~           # FAIL if older than N minutes (null = no hard fail)
```

---

## Self-Healing

```yaml
self_healing:
  check_task_failures: true           # Query TASK_HISTORY for failed runs after transform
  lookback_hours: 1                   # How many hours back to check for failures
  auto_resume_suspended_tasks: false  # Automatically resume suspended tasks
  # Set true only if you trust the resume is safe without manual review
```

---

## dbt Settings

> Used when `preferred_engine` is `dbt`.

```yaml
dbt:
  project_path: ./dbt
  target: prod                        # dbt target (profile name) to use
  full_refresh_on_schema_change: false
```

---

## Client Notes

```
# Add any client-specific transform requirements here.
# Example:
#   - MART_ORDERS_ENRICHED must be a Dynamic Table with TARGET_LAG = '15 minutes' (SLA)
#   - Stream+Task is used for STG_ORDERS → MART_ORDERS because it triggers a notification
#     to the ERP system via stored procedure (side effect)
#   - All mart Dynamic Tables must use REFRESH_MODE = FULL (incremental not trusted yet)
#   - Task schedule for non-critical tables: 1 hour; for financial tables: 15 minutes
```
