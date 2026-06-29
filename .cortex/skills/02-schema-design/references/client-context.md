# Client Context — de-schema-design

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$de-schema-design` skill reads this file first and applies these settings as overrides
> over its built-in defaults.
>
> **This is the highest-impact client-context file** — it controls the entire modeling
> paradigm. Two clients on the same skill can produce completely different schemas:
> one using Canonical/Star Schema, another using Data Vault 2.0.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## Snowflake Environment

```yaml
client_name: ~                        # e.g. "Acme Corp"
target_database: SANDBOX              # REQUIRED — e.g. "ANALYTICS_DB"
target_schema: TPCH                   # REQUIRED — e.g. "CORE"
```

---

## Modeling Paradigm

> **This single setting changes how every table is named, structured, and related.**
> Choose exactly one.

```yaml
modeling_paradigm: canonical
# Options:
#   canonical     — 3NF relational model; staging 1:1 + normalised subject-area tables
#   star_schema   — Kimball dimensional; fact + conformed dimension tables with SCD
#   data_vault    — Data Vault 2.0; Hub / Link / Satellite / PIT / Bridge pattern
#   one_big_table — Denormalized wide table (modern lakehouse / analytics engineering)
```

---

## Canonical / Star Schema Settings

> Used when `modeling_paradigm` is `canonical` or `star_schema`.

```yaml
canonical:
  staging_prefix: STG_                # e.g. STG_, RAW_, LANDING_, SRC_
  mart_prefix: MART_                  # e.g. MART_, DM_, GOLD_
  fact_prefix: FCT_                   # e.g. FCT_, FACT_
  dim_prefix: DIM_                    # e.g. DIM_

  default_scd_strategy: 2             # SCD type to apply to dimension tables: 0 | 1 | 2
  # 0 = no history (overwrite)
  # 1 = current value only (upsert, no history)
  # 2 = full history (add _EFF_START_DATE / _EFF_END_DATE / _IS_CURRENT)

  scd2_columns:                       # Columns added for SCD Type 2
    - name: _EFF_START_DATE
      type: TIMESTAMP_LTZ
      default: CURRENT_TIMESTAMP()
    - name: _EFF_END_DATE
      type: TIMESTAMP_LTZ
    - name: _IS_CURRENT
      type: BOOLEAN
      default: "TRUE"
```

---

## Data Vault 2.0 Settings

> Used when `modeling_paradigm` is `data_vault`.
> The skill will generate Hub / Link / Satellite entities instead of staging/mart tables.

```yaml
data_vault:
  # Object naming
  hub_prefix: HUB_
  link_prefix: LNK_
  satellite_prefix: SAT_
  pit_prefix: PIT_                    # Point-in-Time tables
  bridge_prefix: BRDG_                # Bridge tables (for many-to-many spans)

  # Standard Data Vault column names
  hash_key_suffix: _HK                # e.g. CUSTOMER_HK (SHA2 or MD5 hash of business key)
  business_key_suffix: _BK            # e.g. CUSTOMER_BK
  load_date_column: LOAD_DATE         # Load date column in all DV objects
  record_source_column: RECORD_SOURCE # Source system identifier column

  # Hash key algorithm
  hash_algorithm: SHA2_256            # SHA2_256 | MD5

  # Target layers (schema names within target_database)
  raw_vault_schema: RAW_VAULT         # e.g. RAW_VAULT, DV_RAW
  business_vault_schema: BUS_VAULT    # e.g. BUS_VAULT, DV_BUSINESS
  information_mart_schema: MART       # e.g. MART, INFORMATION_MART

  # Satellite naming: SAT_{HUB_NAME}_{DESCRIPTOR}
  # e.g. SAT_CUSTOMER_DEMOGRAPHICS, SAT_CUSTOMER_FINANCE
  satellite_descriptor_required: true
```

---

## Audit Columns

> These columns are appended to every generated table definition.
> Modify the list to match your client's standards.

```yaml
audit_columns:
  - name: _LOADED_AT
    type: TIMESTAMP_LTZ
    nullable: false
    default: CURRENT_TIMESTAMP()
  - name: _SOURCE_SYSTEM
    type: VARCHAR(50)
    nullable: false
    default: "'UNKNOWN'"              # Override per-table in transform-setup
# Optional additional audit columns:
# - name: _BATCH_ID
#   type: VARCHAR(100)
# - name: _IS_DELETED
#   type: BOOLEAN
#   default: "FALSE"
```

---

## Type Mapping Overrides

> Override specific source-type-to-Snowflake-type mappings.
> These are applied INSTEAD OF the skill's built-in mapping table.

```yaml
type_mapping_overrides: {}
# Example — override how FLOAT prices are handled:
# type_mapping_overrides:
#   FLOAT: NUMBER(15,2)      # Force all FLOAT → NUMBER(15,2) (common for financial data)
#   INTEGER: NUMBER(38,0)    # Force INTEGER → NUMBER(38,0)
```

---

## PII Masking Plan

```yaml
pii_masking:
  default_strategy: sha2              # sha2 | null | partial_mask | tokenize
  # sha2          — SHA2-256 hash of value (reversible with key; audit-friendly)
  # null          — Replace with NULL (strictest; analysts cannot see shape)
  # partial_mask  — e.g. show last 4 digits of SSN, or domain of email
  # tokenize      — Replace with a stable token (requires external vault)

  visible_to_roles:                   # Roles that see raw PII values
    - DATA_ENGINEER
    - SYSADMIN
  # Add client-specific roles:
  # - ACME_PII_AUDITOR_ROLE
```

---

## Naming Conventions

```yaml
naming:
  table_case: UPPER                   # UPPER | lower | TitleCase
  column_case: UPPER                  # UPPER | lower
  composite_pk_separator: "__"        # e.g. ORDER_ID__LINE_NUMBER (used in Data Vault HKs)
```

---

## Client Notes

```
# Add any client-specific schema design constraints here.
# Example (canonical client):
#   - All fact tables must have a DATE_KEY FK into a shared DIM_DATE calendar table
#   - Customer dimension must always be SCD Type 2 regardless of profile recommendation
#   - No VARCHAR columns longer than 1000 chars (DBA policy)

# Example (data vault client):
#   - All business keys must be coerced to VARCHAR before hashing (no native int BKs)
#   - RECORD_SOURCE must use the format "{system}_{layer}" e.g. "ERP_ORDERS_LANDING"
#   - SAT tables must split into at most 2 satellites per Hub (rate of change constraint)
```
