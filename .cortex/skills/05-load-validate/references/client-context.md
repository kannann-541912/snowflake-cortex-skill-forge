# Client Context — de-load-validate

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$de-load-validate` skill reads this file first and applies these settings as overrides.
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

## Load Strategy

```yaml
load:
  strategy: incremental               # full | incremental
  # full        — Truncate and reload the entire target table on every run
  # incremental — Append/merge only new or changed records using a watermark

  method: insert_select               # insert_select | copy_into | dynamic_table_refresh
  # insert_select        — INSERT INTO ... SELECT FROM source (for live Snowflake tables)
  # copy_into            — COPY INTO from an external stage (for staged files)
  # dynamic_table_refresh — ALTER DYNAMIC TABLE ... REFRESH (for DT-based pipelines)

  watermark_column: ~                 # e.g. "O_ORDERDATE" or "_LOADED_AT"
  on_error: CONTINUE                  # CONTINUE | ABORT_STATEMENT
  # CONTINUE — bad rows go to quarantine; good rows proceed (recommended for production)
  # ABORT_STATEMENT — entire load aborts on first error (use only for critical pipelines)
```

---

## Validation Thresholds

```yaml
validation:
  row_count_delta_stop_pct: 1         # STOP if loaded rows differ from source by > N%
  quarantine_rate_stop_pct: 5         # STOP if quarantine rejection rate exceeds N%
  null_check_enabled: true            # Run null checks on NOT NULL columns after load
  fk_integrity_check_enabled: false   # Check referential integrity (adds query overhead)
```

---

## Quarantine Configuration

```yaml
quarantine:
  table_suffix: _QUARANTINE           # e.g. STG_ORDERS_QUARANTINE
  include_error_message: true
  include_file_info: true
  retention_days: 30                  # How long quarantine records are retained
```

---

## Alerting

```yaml
alerts:
  enabled: true
  schedule: '5 MINUTE'               # CRON expression or 'N MINUTE' interval
  quarantine_threshold_rows: 100     # Trigger alert when quarantine exceeds N rows in window
  window_minutes: 5                  # Lookback window for alert evaluation
  notification_email: ~              # e.g. "data-alerts@acme.com"
  slack_webhook_env_var: ~           # env var name, e.g. "SLACK_WEBHOOK_URL"
```

---

## Snowpipe / Continuous Ingest

```yaml
snowpipe:
  enabled: false                      # true = set up Snowpipe for continuous ingest
  auto_ingest: true                   # true = trigger via S3/GCS/Azure event notification
  purge_files_after_load: false       # false = keep files for audit / reprocessing
```

---

## Client Notes

```
# Add any client-specific load constraints or policies here.
# Example:
#   - Full load only on Sundays; incremental every 15 minutes Mon–Sat
#   - Quarantine threshold is 0.5% for financial tables (stricter than default 5%)
#   - ORDERS large table must use the LARGE_WAREHOUSE_WH (cost separation)
#   - Alert should go to both data-alerts@acme.com AND the #data-quality Slack channel
#   - LINEITEM full load is allowed to exceed the 1% row delta threshold (known ~1.2% delta)
```
