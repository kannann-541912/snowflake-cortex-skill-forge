# Client Context — dmf-generator

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$dmf-generator` skill reads this file first and applies these settings as overrides.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## Snowflake Environment

```yaml
client_name: ~                        # e.g. "Acme Corp"
target_database: ~                    # e.g. "ANALYTICS_DB"
target_schema: ~                      # e.g. "CORE"
warehouse: ANALYTICS_WH
```

---

## DMF Naming

```yaml
naming:
  dmf_prefix: DMF_                    # Prefix for all generated DMF names
  pattern: "{DMF_PREFIX}{TABLE}_{CHECK}_{COLUMN}"
  # Results in names like: DMF_ORDERS_NULL_COUNT_CUSTOMER_EMAIL
  # Override pattern if client has a different convention:
  # pattern: "{TABLE}_DQ_{CHECK}_{COLUMN}"
  use_upper_case: true
```

---

## Schedule

```yaml
schedule:
  default: TRIGGER_ON_CHANGES         # TRIGGER_ON_CHANGES | 'N MINUTE' | 'N HOUR'
  # TRIGGER_ON_CHANGES — Recommended; runs after each DML change on the table
  # '60 MINUTE'        — Fixed interval (every 60 minutes)
  # '1440 MINUTE'      — Daily (use for large tables to control cost)

  per_table_overrides: {}
  # Example — override schedule for specific tables:
  # per_table_overrides:
  #   STG_ORDERS: TRIGGER_ON_CHANGES
  #   MART_ORDERS_ENRICHED: '15 MINUTE'
  #   STG_LINEITEM: '120 MINUTE'      # Large table — less frequent
```

---

## DMF Selection Rules

```yaml
dmf_selection:
  max_dmfs_per_table: 20              # Cap for wide tables (>50 columns)
  priority_columns:                   # These columns always get DMFs regardless of cap
    - any column matching: [_id, _key, _sk, _hk]    # IDs and keys
    - any column matching: [_at, _date, _ts, _time]  # Timestamps (freshness)
    - any column matching: [status, type, flag]       # Status/enum columns

  skip_metadata_columns: true         # Skip _loaded_at, _source_system, etc.
  skip_comment_columns: true          # Skip high-cardinality free-text columns

  dmf_types:
    null_count: true                  # For all nullable columns
    duplicate_count: true             # For PK/ID/email columns
    out_of_range: true                # For numeric and date columns
    format_invalid: true              # For email/phone/zip/url columns
    freshness: true                   # For timestamp columns
    row_count: true                   # Always one per table
```

---

## Alert on Breach

```yaml
alert:
  enabled: true
  # If DMF value exceeds thresholds, generate a Snowflake ALERT:
  null_count_threshold: 0             # Alert if null_count > N (0 = any null in NOT NULL col)
  duplicate_threshold: 0             # Alert if duplicate_count > N
  freshness_hours_threshold: 48       # Alert if hours_stale > N
  notification_email: ~              # e.g. "data-quality@acme.com"
  alert_schedule: '15 MINUTE'
```

---

## View Target Handling

```yaml
view_targets:
  identify_base_table: true           # Run GET_DDL to find the base table for view targets
  attach_to_base_table: true          # Attach DMFs to base table, not the view
  note_in_output: true                # Include a note in output explaining the attachment
```

---

## Client Notes

```
# Add any client-specific DMF requirements here.
# Example:
#   - DMF names must use lowercase snake_case (client DBA policy)
#   - All DMFs must use TRIGGER_ON_CHANGES — no fixed-interval schedules allowed
#   - freshness threshold is 24 hours (not default 48) for all financial tables
#   - DMFs on LINEITEM must use a 2-hour schedule — too large for TRIGGER_ON_CHANGES
#   - Alert email is dq-team@acme.com, NOT the generic data-alerts address
#   - Do not generate out_of_range DMFs for price columns (known high variance)
```
