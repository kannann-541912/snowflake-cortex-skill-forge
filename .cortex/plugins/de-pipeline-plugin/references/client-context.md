# Client Context — de-pipeline-plugin
# Shared across all 8 DE workflow skills

> **Placeholder file.** Copy this template, fill in the values for your client engagement,
> and commit it alongside this plugin. All 8 DE pipeline skills read this single file at
> the start of every invocation. Parameters left as `~` (YAML null) fall through to the
> skill's built-in defaults. Never fail if values are missing.
>
> **Do NOT commit credentials, passwords, or tokens to this file.**
>
> Once you have filled in this file, run:
>   `bash hooks/pipeline-state.sh mark-refs-read`
> to unblock the first Write gate in the session.

---

## Snowflake Environment
# Read by: all skills

```yaml
client_name: ~                        # REQUIRED — e.g. "Acme Corp"
snowflake_account: ~                  # REQUIRED — e.g. "abc12345.us-east-1"

source_database: SNOWFLAKE_SAMPLE_DATA
source_schema: TPCH_SF10

target_database: SANDBOX              # REQUIRED — e.g. "ANALYTICS_DB"
target_schema: TPCH                   # REQUIRED — e.g. "CORE"

warehouse: ANALYTICS_WH               # Warehouse used for all pipeline phases
default_role: ~                       # e.g. "DATA_ENGINEER_ROLE"
```

---

## Phase 0 Wizard Defaults
# Read by: de-workflow

```yaml
workflow_defaults:
  source_tables: ~                    # e.g. [ORDERS, LINEITEM]
  build_mode: 2                       # 1=staging_only | 2=staging+mart | 3=full_stack
  consumer_persona: analyst           # consumer | analyst | engineer
  cross_account_share: false
```

---

## Phase 1 — Profile Settings
# Read by: de-profile

```yaml
sampling:
  default_sample_pct: ~               # e.g. 10 — used if table not in overrides below
  large_table_threshold_rows: 10000000

  # Per-table overrides (TPCH built-in defaults: LINEITEM=1%, ORDERS=5%, etc.)
  per_table_overrides: {}
  # Example:
  # per_table_overrides:
  #   LINEITEM: 1
  #   ORDERS: 5
  #   CUSTOMER: 10

pii_detection:
  additional_column_keywords: []
  # Industry-specific examples:
  # Healthcare: [mrn, npi, diagnosis_code, procedure_code]
  # Finance:    [account_number, routing_number, ein, iban]
  # Retail/CRM: [loyalty_id, member_id, card_last_four]

  additional_regex_patterns: []
  # Example:
  # - pattern: '^[0-9]{9}$'
  #   label: ssn_numeric

output:
  report_filename: profile_report.md
  include_sample_values: true
  include_numeric_stats: true
  include_recommendations: true
```

---

## Phase 2 — Schema Design Settings
# Read by: de-schema-design

```yaml
modeling_paradigm: canonical          # canonical | star_schema | data_vault | one_big_table

canonical:
  staging_prefix: STG_
  mart_prefix: MART_
  default_scd_strategy: type1         # type1 | type2

data_vault:
  hub_prefix: HUB_
  link_prefix: LNK_
  satellite_prefix: SAT_

audit_columns:
  - name: _LOADED_AT
    type: TIMESTAMP_LTZ
    default: CURRENT_TIMESTAMP()
  - name: _SOURCE_SYSTEM
    type: VARCHAR(50)
    default: "'TPCH_SF10'"

# Override source-to-target type mappings per column name pattern
type_mapping_overrides: {}
# Example:
# type_mapping_overrides:
#   O_TOTALPRICE: NUMBER(15,2)       # already built-in for TPCH FLOAT prices
#   L_EXTENDEDPRICE: NUMBER(15,2)

pii_masking:
  default_strategy: sha2             # sha2 | null | partial_mask | tokenize
  visible_to_roles: [DATA_ENGINEER, SYSADMIN]
```

---

## Phase 3 — Schema Setup Settings
# Read by: de-schema-setup

```yaml
ddl:
  create_mode: IF_NOT_EXISTS         # IF_NOT_EXISTS (safe) | OR_REPLACE (dev only)

masking_policies:
  visible_to_roles: [DATA_ENGINEER, SYSADMIN]
  policy_definitions: ~              # Use built-in MASK_EMAIL and MASK_PII_HASH defaults
```

---

## Phase 4 — Transform Setup Settings
# Read by: de-transform-setup

```yaml
preferred_transform_engine: dynamic_table  # dbt | dynamic_table | both

dynamic_table:
  default_target_lag: "1 hour"       # e.g. "15 minutes" | "1 hour" | "7 days"
  refresh_mode: AUTO

dbt:
  project_path: ~                    # e.g. "./dbt"
  staging_materialization: view
  mart_materialization: table

# Override column-name-pattern → target type mappings
type_cast_overrides: {}

incremental:
  watermark_column: ~                # e.g. O_ORDERDATE or _LOADED_AT
```

---

## Phase 5 — Load & Validate Settings
# Read by: de-load-validate

```yaml
load:
  strategy: full                     # full | incremental
  method: insert_select              # insert_select | copy_into | dynamic_table_refresh
  watermark_column: ~                # column used for incremental WHERE filter
  on_error: CONTINUE                 # CONTINUE | ABORT_STATEMENT

validation:
  row_count_delta_stop_pct: 1        # STOP if loaded/source delta > N%
  quarantine_rate_stop_pct: 5        # STOP if quarantine rate > N%
  null_fail_on_not_null: true        # FAIL if any NOT NULL column has nulls in batch

alerts:
  schedule: "5 MINUTE"
  quarantine_threshold: 100          # Alert if quarantine count > N in last 5 min
  email: ~                           # e.g. "data-alerts@acme.com"
  slack_webhook_env_var: ~           # env var name holding Slack webhook URL

snowpipe:
  enabled: false
```

---

## Phase 6 — Transform Settings
# Read by: de-transform

```yaml
preferred_engine: dynamic_table      # dynamic_table | stream_task | dbt

stream_task:
  task_schedule: "5 MINUTE"
  stream_mode: standard              # standard | append_only

quality_assertions:
  row_delta_warn_pct: 5              # WARN if source/target row count delta > N%
  output_null_fail_pct: 5            # STOP if critical output column null rate > N%
  freshness_warn_minutes: 30         # WARN if _LOADED_AT older than N minutes

self_healing:
  lookback_hours: 1                  # Hours to look back for failed task runs
```

---

## Phase 7 — Share Settings
# Read by: de-share

```yaml
rbac:
  role_prefix: DE_               # e.g. "ACME_" → ACME_CONSUMER_ROLE
  role_hierarchy:
    - DE_CONSUMER_ROLE
    - DE_ANALYST_ROLE
    - DE_ENGINEER_ROLE
  additional_roles: []           # e.g. [DE_SCIENTIST_ROLE, DE_AUDITOR_ROLE]

pii_governance:
  level: standard                # strict | standard | minimal

row_access_policy:
  enabled: false
  filter_column: ~               # e.g. "REGION"
  mapping_table: ~               # e.g. "SANDBOX.TPCH.USER_REGION_MAP"

cross_account_share:
  enabled: false
  consumer_account_locator: ~    # e.g. "ABC12345"
  share_name: ~                  # e.g. "TPCH_DATA_SHARE"
```

---

## Quality Gate Thresholds (Global Overrides)
# Applied by: de-workflow between all phases

```yaml
quality_gates:
  empty_source_abort: true           # Phase 1: abort if source has 0 rows
  high_null_warn_pct: 50             # Phase 2: warn if NOT NULL col > N% nulls in source
  row_count_delta_stop_pct: 1        # Phase 5: STOP if loaded/source delta > N%
  quarantine_rate_stop_pct: 5        # Phase 5: STOP if quarantine rate > N%
  output_null_fail_pct: 5            # Phase 6: STOP if critical null rate > N%
  row_delta_warn_pct: 5              # Phase 6: WARN if source/target delta > N%
  freshness_warn_minutes: 30         # Phase 6: WARN if _LOADED_AT lag > N minutes
```

---

## Error Recovery Policy

```yaml
on_phase_failure: stop               # stop | prompt | auto_retry
max_auto_retries: 0
rollback_on_abort: false             # true = drop objects from failed phase on abort
```

---

## Artifact Paths

```yaml
artifact_dir: "."                    # Directory where .md/.sql/.yml artifacts are written
                                     # Default: current working directory
```

---

## Notifications

```yaml
alert_email: ~                       # e.g. "data-alerts@acme.com"
slack_webhook_env_var: ~             # env var name holding Slack webhook URL
```

---

## Client Notes

```
# Add any client-specific context here that the AI should be aware of across all phases.
# Examples:
# - Source system ORDERS has ~2% known duplicate orders from ERP migration (expected)
# - SLA: data must be in mart by 06:00 UTC daily
# - LINEITEM large table load should run off-hours only (after 22:00 UTC)
# - C_COMMENT and L_COMMENT columns contain free text; skip value distribution profiling
```
