# Client Context — dbt-jinja-builder

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$dbt-jinja-builder` skill reads this file first and applies these settings as overrides.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## Snowflake Environment

```yaml
client_name: ~                        # e.g. "Acme Corp"
source_database: ~                    # e.g. "ANALYTICS_DB"
source_schema: ~                      # e.g. "CORE"
```

---

## dbt Project Structure

```yaml
dbt:
  project_path: ./dbt                 # Path to dbt project root (relative to CWD)
  profile_name: ~                     # Profile name in profiles.yml

  # Schema layer names (must match dbt_project.yml +schema settings)
  staging_schema: staging
  intermediate_schema: intermediate
  mart_schema: marts

  # Schema YAML filenames per layer
  schema_files:
    staging: _staging.yml
    intermediate: _intermediate.yml
    marts: _marts.yml

  # Model path structure under dbt/models/
  staging_path: staging
  intermediate_path: intermediate
  mart_path: marts
```

---

## Materialization Defaults

```yaml
materialization:
  staging: view                       # view | table | incremental
  intermediate: table                 # view | table | incremental
  mart: incremental                   # view | table | incremental

  incremental_strategy: merge         # merge | delete+insert | append
  unique_key: ~                       # Default unique key (~ = auto-detect from PKs)
  on_schema_change: sync_all_columns  # sync_all_columns | fail | ignore | append_new_columns
```

---

## Surrogate Key

```yaml
surrogate_key:
  method: dbt_utils                   # dbt_utils | native_hash | none
  # dbt_utils     — dbt_utils.generate_surrogate_key() (requires dbt-utils package)
  # native_hash   — MD5(CAST(col1 AS VARCHAR) || '|' || CAST(col2 AS VARCHAR))
  # none          — Do not generate surrogate keys
  column_name: surrogate_key          # Name of the generated surrogate key column
```

---

## Model Tags

```yaml
tags:
  staging:
    - staging
    - generated
  intermediate:
    - intermediate
    - generated
  marts:
    - marts
    - generated
  # Add client-specific tags:
  # - acme
  # - finance_domain
```

---

## Macro Library

```yaml
macros:
  generate_column_list: true          # Generate a {model}_columns() macro
  generate_null_safe_cast: true       # Generate safe_cast() macro
  generate_deduplication: true        # Generate deduplicate() macro (only if dupes detected)
  generate_timestamp_standardize: true  # Generate standardize_ts() macro
  generate_enum_mapper: true          # Generate map_{col}() macros for low-cardinality cols
  generate_referential_integrity: true  # Generate test_referential_integrity() macro
```

---

## Type Cast Rules

```yaml
type_cast_overrides: {}
# Example overrides:
# type_cast_overrides:
#   FLOAT: "NUMBER(15,2)"          # Cast FLOAT → NUMBER(15,2) for all financial data
#   "*_price": "NUMBER(15,2)"      # Column name pattern → type
#   "*_amount": "NUMBER(18,4)"
#   "*_rate": "NUMBER(10,6)"
```

---

## Contract Enforcement

```yaml
contract:
  enforced: false                     # true = add "contract: enforced: true" to all models
  # Enabling this requires ALL columns to be declared in schema.yml
  # Recommended only for mature, stable models
```

---

## Client Notes

```
# Add any client-specific dbt conventions here.
# Example:
#   - All staging models must be suffixed with _base: stg_orders_base.sql
#   - Intermediate models use double-underscore naming: int_orders__line_items.sql
#   - dbt project name is "acme_analytics" — use underscores, not hyphens
#   - All models must have a contract block with enforced: true (strict typing policy)
#   - Surrogate keys use native MD5, not dbt_utils (dbt-utils not installed)
#   - No incremental models in staging layer — views only (performance policy)
```
