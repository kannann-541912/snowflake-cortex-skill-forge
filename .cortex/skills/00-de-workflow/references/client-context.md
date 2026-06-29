# Client Context — de-workflow

> **Placeholder file.** Copy this template, fill in the values for your client engagement,
> and commit it alongside this skill. When this file exists, the `$de-workflow` skill reads
> it first and uses these values as overrides over its built-in defaults.
>
> Parameters left as `~` (YAML null) fall through to the skill's built-in defaults.
> Parameters marked **REQUIRED** must be filled in before running the workflow.
>
> **Do NOT commit credentials, passwords, or tokens to this file.**

---

## Snowflake Environment

```yaml
client_name: ~                        # REQUIRED — e.g. "Acme Corp"
snowflake_account: ~                  # REQUIRED — e.g. "abc12345.us-east-1"

source_database: SNOWFLAKE_SAMPLE_DATA
source_schema: TPCH_SF10

target_database: SANDBOX              # REQUIRED — e.g. "ANALYTICS_DB"
target_schema: TPCH                   # REQUIRED — e.g. "CORE"

warehouse: ANALYTICS_WH               # Warehouse used for all workflow phases
default_role: ~                       # e.g. "DATA_ENGINEER_ROLE"
```

---

## Phase 0 — Default Answers (Workflow Wizard Pre-fill)

> Leave any value as `~` to be prompted interactively during Phase 0.

```yaml
workflow_defaults:
  source_tables: ~                    # e.g. [ORDERS, LINEITEM] — tables to pipeline
  build_mode: 2                       # 1=staging_only | 2=staging+mart | 3=full_stack
  consumer_persona: analyst           # consumer | analyst | engineer
  cross_account_share: false
```

---

## Quality Gate Thresholds

> These override the default gate thresholds checked between each phase.
> Raising a threshold loosens a gate; lowering it makes it stricter.

```yaml
quality_gates:
  # Phase 1 — Profile
  empty_source_abort: true            # Abort if source has 0 rows

  # Phase 2 — Schema Design
  high_null_warn_pct: 50              # Warn if NOT NULL column has > N% nulls in source

  # Phase 5 — Load & Validate
  row_count_delta_stop_pct: 1         # STOP if loaded rows differ from source by > N%
  quarantine_rate_stop_pct: 5         # STOP if quarantine rate exceeds N%

  # Phase 6 — Transform
  output_null_fail_pct: 5             # STOP if critical output null rate > N%
  row_delta_warn_pct: 5               # WARN if source/target row delta > N%
  freshness_warn_minutes: 30          # WARN if _LOADED_AT is older than N minutes
```

---

## Error Recovery Policy

```yaml
on_phase_failure: stop                # stop | prompt | auto_retry
max_auto_retries: 0                   # number of auto-retries before stopping
rollback_on_abort: false              # true = drop objects from failed phase on abort
```

---

## Artifact Paths

```yaml
artifact_dir: "."                     # Directory where all .md/.sql/.yml artifacts are written
                                      # Default: current working directory
```

---

## Notifications

```yaml
alert_email: ~                        # e.g. "data-alerts@acme.com"
slack_webhook_env_var: ~              # env var name holding the Slack webhook URL
                                      # e.g. "SLACK_WEBHOOK_URL"
```

---

## Client Notes

> Free-text field. Add any client-specific context here that the AI should be aware of
> during workflow execution (e.g. known data quality issues, business rules, SLAs).

```
# Example:
# - Source system ORDERS has ~2% known duplicate orders from ERP migration (expected)
# - SLA: data must be in mart by 06:00 UTC daily
# - LINEITEM large table load should run off-hours only (Sat/Sun or after 22:00 UTC)
```
