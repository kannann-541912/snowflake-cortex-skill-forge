# Client Context — informatica-to-dbt

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$informatica-to-dbt` skill reads this file first and applies these settings
> as overrides — including target schema names, CDC key conventions, and migration scope.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## Migration Scope

```yaml
client_name: ~                        # e.g. "Acme Corp"
migration_type: full                  # full | assessment_only
# full             — Parse XML, produce assessment, scaffold full dbt project
# assessment_only  — Parse XML and produce migration assessment only; no code generation
```

---

## Source System

```yaml
source:
  system_name: ~                      # e.g. "INFORMATICA_POWERMART" or "IDMC"
  xml_path: ~                         # Absolute path to the Informatica XML export file
  session_param_prefix: "$$"          # Informatica session variable prefix (default $$)
```

---

## Snowflake Target

```yaml
snowflake:
  raw_database: ~                     # REQUIRED — e.g. "RAW_DB" or "LANDING"
  staging_schema: staging
  intermediate_schema: intermediate
  mart_schema: mart
  warehouse: ~                        # e.g. "TRANSFORM_WH"
```

---

## dbt Project

```yaml
dbt:
  project_dir: ~                      # Directory to create the dbt project in
  project_name: ~                     # snake_case; e.g. "acme_provider_registry"
  target: prod                        # dbt target name

  # Materialization by layer
  staging_materialization: view
  intermediate_materialization: table
  mart_materialization: incremental
  mart_incremental_strategy: merge    # merge | delete+insert | append

  # Variable naming
  last_run_var: last_run_dt           # dbt var name for incremental date filter
  last_run_default: "1900-01-01"      # Default value for first/full run
```

---

## CDC / Update Strategy

```yaml
cdc:
  unique_key: src_key                 # Column used as the MERGE unique key
  hash_column: etl_hash_cd            # MD5 hash column for change detection
  active_indicator: active_ind        # Column tracking active/inactive status
  active_value: "Y"
  inactive_value: "I"
  action_indicator: etl_actn_ind      # I = Insert, U = Update, D = Delete
  created_at_column: etl_crt_dtm
  updated_at_column: etl_upd_dtm

  soft_delete: true                   # true = UPDATE active_ind='I' instead of hard DELETE
```

---

## Transformation Mapping

```yaml
transformation_mapping:
  # Informatica type → dbt/Snowflake equivalent
  # Override built-in defaults if client has unusual transformation patterns
  lookup_pattern: left_join           # left_join | scalar_subquery
  # left_join      — Informatica Lookup → CTE with LEFT JOIN (preferred)
  # scalar_subquery — Use inline scalar subquery (only for very simple lookups)

  sequence_generator: snowflake_sequence
  # snowflake_sequence — Generate a SEQUENCE object in Snowflake
  # row_number         — Use ROW_NUMBER() OVER (ORDER BY ...) in the model

  router_pattern: separate_models     # separate_models | where_filter
  # separate_models — Each Router branch → its own dbt model
  # where_filter    — Use WHERE clause in a single model (only for simple 2-branch routers)
```

---

## Assessment Report

```yaml
assessment:
  output_file: migration_assessment.md
  risk_levels:
    - direct_translation: low
    - logic_rewrite_needed: medium
    - cdc_update_strategy: high
  show_component_mapping: true        # Table mapping Informatica type → dbt/Snowflake
```

---

## Client Notes

```
# Add any client-specific migration constraints here.
# Example:
#   - Client uses IDMC (cloud), not PowerCenter — XML format is slightly different
#   - All sequence generators must use Snowflake SEQUENCE objects (not ROW_NUMBER)
#   - Informatica session param prefix is $$ but some mappings use % — handle both
#   - Client wants intermediate models as views, not tables (performance trade-off accepted)
#   - CDC key is "COMPOSITE_KEY" not "src_key" — all MERGEs use COMPOSITE_KEY
#   - Provider registry migration: PROV_ALT_ID mapping is the most complex — plan 3 intermediate models
```
