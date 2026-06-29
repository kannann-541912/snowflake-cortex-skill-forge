# Client Context — de-profile

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$de-profile` skill reads this file first and applies these settings as overrides.
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
warehouse: ANALYTICS_WH               # Warehouse used for profiling queries
```

---

## Sampling Strategy

> Override per-table sampling rates. Built-in defaults apply for tables not listed here.

```yaml
sampling:
  default_sample_pct: ~               # e.g. 10 — used if table not listed below
  large_table_threshold_rows: 10000000  # tables above this row count use large_table_pct

  # Per-table overrides (use table names as keys)
  per_table_overrides: {}
  # Example:
  # per_table_overrides:
  #   LINEITEM: 1
  #   ORDERS: 5
  #   CUSTOMER: 10
```

---

## PII Detection

> Extend the built-in PII column name keyword list with industry-specific patterns.
> These additions are appended to the default list (email, phone, ssn, dob, etc.).

```yaml
pii_detection:
  additional_column_keywords:         # Column NAME patterns that flag as PII
    []
  # Industry-specific examples:
  # Healthcare:
  #   - mrn             # Medical Record Number
  #   - npi             # National Provider Identifier
  #   - diagnosis_code
  #   - procedure_code
  # Finance:
  #   - account_number
  #   - routing_number
  #   - ein             # Employer Identification Number
  #   - iban
  # Retail / CRM:
  #   - loyalty_id
  #   - member_id
  #   - card_last_four

  additional_regex_patterns:          # Value-level regex patterns that flag as PII
    []
  # Example:
  # additional_regex_patterns:
  #   - pattern: '^[0-9]{9}$'
  #     label: ssn_numeric
  #   - pattern: '^[0-9]{10,11}$'
  #     label: possible_phone_numeric
```

---

## Anomaly Thresholds

```yaml
anomaly_thresholds:
  high_null_warn_pct: 50              # Warn if null rate > N%
  unique_key_cardinality_min_pct: 99  # Flag as "probable PK" if cardinality >= N%
  constant_column_cardinality: 1      # Flag as constant if distinct count <= N
  high_variance_stddev_multiplier: 3  # Flag if stddev > N × mean
```

---

## Output Format

```yaml
output:
  report_filename: profile_report.md
  include_sample_values: true         # Include top-5 values per column
  include_numeric_stats: true         # Include mean/median/stddev for numeric cols
  include_recommendations: true       # Include "Next Step" and mapping suggestions
```

---

## Client Notes

```
# Add any client-specific profiling notes here.
# Example:
# - C_COMMENT and L_COMMENT columns contain free text; skip value distribution profiling
# - O_ORDERSTATUS is an enum with only 3 valid values: 'O', 'F', 'P'
# - Treat P_RETAILPRICE as PII-equivalent (commercially sensitive pricing)
```
