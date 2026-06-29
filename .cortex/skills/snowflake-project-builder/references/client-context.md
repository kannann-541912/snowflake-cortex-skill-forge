# Client Context — snowflake-project-builder

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$snowflake-project-builder` skill reads this file first and applies these settings
> as overrides — including the project root path and all naming conventions.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## Project Location

```yaml
project_root: ~
# REQUIRED — absolute path to the target project repository root.
# Default: /Users/kannannvelmurugiah/Desktop/snowflake-project
# Override to point to the client's actual project directory.
# Example: /Users/you/projects/acme-data-platform
```

---

## Snowflake Environment

```yaml
client_name: ~                        # e.g. "Acme Corp"
snowflake_account: ~                  # e.g. "abc12345.us-east-1"
primary_database: ~                   # e.g. "ANALYTICS"
primary_schema: ~                     # e.g. "CORE"
warehouse: ~                          # e.g. "ANALYTICS_WH"
default_role: ~                       # e.g. "DATA_ENGINEER_ROLE"
```

---

## Naming Conventions

```yaml
naming:
  table_case: UPPER                   # UPPER | lower | TitleCase
  column_case: UPPER                  # UPPER | lower
  schema_separator: _                 # Separator between DB name and schema name

  # Table prefix conventions (must match schema design context)
  staging_prefix: STG_                # e.g. STG_, RAW_
  mart_prefix: MART_                  # e.g. MART_, DM_
  fact_prefix: FCT_
  dim_prefix: DIM_

  # Data Vault prefixes (only if client uses Data Vault)
  hub_prefix: HUB_
  link_prefix: LNK_
  satellite_prefix: SAT_

  environment_suffix_position: suffix # suffix | prefix
  environment_suffix_template: "_{ENV}" # e.g. _DEV, _QA, _PROD
```

---

## Object Classification Rules

> Controls which Snowflake object types go into DCM (declarative) vs imperative SQL files.
> The defaults below match the skill's standard classification.
> Override only if the client manages these objects differently.

```yaml
object_classification:
  dcm_managed:                        # Objects described with DCM DEFINE syntax
    - table
    - view
    - warehouse
    - schema
    - role

  imperative_sql:                     # Objects created with CREATE OR REPLACE (no DEFINE)
    - task
    - alert
    - pipe
    - stream
    - procedure
    - dynamic_table
    - data_metric_function
    - policy
    - tag
    - sequence
    - integration
    - secret
```

---

## dbt Integration

```yaml
dbt:
  generate_dbt_models: true           # Auto-generate dbt model stubs for new tables
  dbt_project_path: ./dbt            # Path to dbt project relative to project_root
  staging_model_prefix: stg_         # e.g. stg_orders
  mart_fact_prefix: fct_             # e.g. fct_orders
  mart_dim_prefix: dim_              # e.g. dim_customer
  sources_file: _sources.yml
  staging_schema_file: _staging.yml
  marts_schema_file: _marts.yml
```

---

## AgentOps Integration

```yaml
agentops:
  generate_agent_stubs: true          # Auto-generate agent.yml + system_prompt.md stubs
  agents_dir: agent                   # Relative to project_root
```

---

## Conflict Detection

```yaml
conflict_detection:
  grep_before_write: true             # Grep existing files for object definitions before writing
  abort_on_duplicate: false           # true = STOP; false = WARN and show diff
```

---

## Verification

```yaml
verification:
  run_naming_check: true              # python scripts/check_naming.py
  run_dcm_plan: true                  # snow dcm plan --target DEV
  run_dbt_compile: true               # dbt compile
  run_agent_spec_validate: true       # python scripts/validate_agent_spec.py
```

---

## Client Notes

```
# Add any client-specific builder constraints here.
# Example:
#   - Project root is /home/devuser/workspace/acme-snowflake (not the default)
#   - Client uses lowercase table names in dbt but UPPERCASE in Snowflake DDL
#   - Tasks and Alerts go into a dedicated ops/ directory (not ingestion/)
#   - dbt models must always include a contract block with enforced: true
#   - All new tables must be added to the DQ manifest for DMF attachment
```
