# Client Context — airflow-dag-generator

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$airflow-dag-generator` skill reads this file first and applies these settings
> as overrides over its built-in defaults.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials, webhook URLs, or secrets to this file.**

---

## DAG Variant

```yaml
dag_variant: cosmos                   # cosmos | bash
# cosmos — Astronomer Cosmos (recommended); uses DbtTaskGroup; requires astronomer-cosmos package
# bash   — Plain BashOperator; simpler; no Cosmos dependency
```

---

## Schedule

```yaml
schedule:
  cron: "0 4 * * *"                  # Cron expression for the DAG schedule
                                      # Examples:
                                      # "0 4 * * *"     — daily at 04:00 UTC
                                      # "0 */6 * * *"   — every 6 hours
                                      # "@hourly"        — every hour
                                      # null             — no schedule (manual trigger only)
  catchup: false                      # true = backfill from start_date; false = skip
  start_date: "2026-01-01"           # ISO date string
```

---

## Snowflake Connection

```yaml
snowflake:
  conn_id: snowflake_default          # Airflow connection ID for Snowflake
  database: ~                         # e.g. "ANALYTICS_DB"
  schema: ~                           # e.g. "CORE"
```

---

## dbt Project

```yaml
dbt:
  project_path: /usr/local/airflow/dbt/{project_name}
  profile_name: ~                     # Must match profiles.yml profile name
  target: prod                        # dbt target to use
  executable_path: /usr/local/bin/dbt
```

---

## SnowflakeSensor

```yaml
sensor:
  enabled: true                       # true = add SnowflakeSensor for data arrival detection
  poke_interval_seconds: 300          # How often to check (in seconds)
  timeout_seconds: 3600               # Max time to wait before failing
  mode: poke                          # poke | reschedule
```

---

## Failure Alerting

```yaml
alerting:
  email_on_failure: true
  email: ~                            # e.g. "data-alerts@acme.com"
  slack:
    enabled: false
    conn_id: ~                        # Airflow connection ID for Slack (type: Slack API)
                                      # e.g. "slack_data_alerts"
```

---

## Retry Policy

```yaml
retry:
  retries: 2
  retry_delay_minutes: 5
```

---

## DAG Layer Structure

```yaml
layers:
  # Override the default tag-based layer detection
  # Leave as ~ to infer from manifest.json or stg_/int_/fct_ naming conventions
  staging_selector: ~                 # e.g. "tag:staging" or "path:models/staging"
  intermediate_selector: ~            # e.g. "tag:intermediate"
  marts_selector: ~                   # e.g. "tag:marts"

  test_between_layers: true           # Insert dbt test gate between every layer
```

---

## Output

```yaml
output:
  dag_dir: dags                       # Directory to write the generated DAG file
  filename_template: "dbt_{project_name}_dag.py"
```

---

## Client Notes

```
# Add any client-specific Airflow/DAG requirements here.
# Example:
#   - Client uses Airflow 2.7 on Astronomer; Cosmos >= 1.4 is available
#   - DAG must run at 03:00 EST (08:00 UTC) — use "0 8 * * *"
#   - Slack alerting mandatory; conn_id is "slack_data_team"
#   - No SnowflakeSensor needed — upstream load is guaranteed by a separate pipeline
#   - Use BashOperator (not Cosmos) — client's Airflow environment has no Cosmos
#   - task IDs must use double-underscore separator: e.g. staging__stg_orders
```
