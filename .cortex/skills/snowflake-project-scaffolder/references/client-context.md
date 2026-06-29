# Client Context — snowflake-project-scaffolder

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$snowflake-project-scaffolder` skill reads this file first. Values defined here
> pre-fill the interactive wizard — any `~` value will still be prompted interactively.
>
> **Do NOT commit credentials or secrets to this file.**
> `config.toml` must NEVER be committed — it contains the PAT token.

---

## Wizard Pre-fill

> These values answer the Phase 1 wizard questions automatically.
> Leave as `~` to be prompted interactively during scaffold.

```yaml
# REQUIRED — prompted if left as ~
project_name: ~                       # lowercase-kebab; e.g. "acme-data-platform"
snowflake_account: ~                  # e.g. "abc12345.us-east-1"
primary_database: ~                   # e.g. "ANALYTICS"
primary_schema: ~                     # e.g. "CORE"
landing_schema: ~                     # e.g. "CORE_LANDING"
warehouse: ~                          # e.g. "ANALYTICS_WH"
service_user: ~                       # e.g. "CI_SERVICE_USER"
default_role: ~                       # e.g. "ACCOUNTADMIN"
reader_role: ~                        # e.g. "DATA_READER"

# OPTIONAL PILLARS
include_mlops: false                  # true = generate MLOps pillar
include_dashboards: false             # true = generate Streamlit dashboards pillar

# OPTIONAL INITIAL STUBS
first_table_stub: ~                   # e.g. "CUSTOMERS" — blank to skip
first_agent_stub: ~                   # e.g. "data-analyst" — blank to skip
```

---

## CI/CD Platform

```yaml
cicd:
  platform: github                    # github | gitlab | azure_devops
  branch_strategy: gitflow            # gitflow | trunk | github_flow
  # gitflow     — main + develop + feature/* branches
  # trunk       — single main branch, feature flags
  # github_flow — main + feature/* branches (no develop)

  protected_branches:
    - main
    - develop                         # Remove if not using gitflow
```

---

## Environments

```yaml
environments:
  - name: DEV
    suffix: _DEV
  - name: QA
    suffix: _QA
  - name: PROD
    suffix: ""                        # PROD has no suffix (objects are named as-is)
    requires_approval: true           # Deployment to PROD requires manual approval step
```

---

## Naming Conventions

```yaml
naming:
  dbt_project_name_separator: _      # snake_case for dbt project name (always underscore)
  warehouse_naming: "{NAME}_WH"       # e.g. ANALYTICS_WH, TRANSFORM_WH
  role_naming: "{NAME}_ROLE"          # e.g. DATA_ENGINEER_ROLE
  schema_naming: "{DB}_{SCHEMA}"      # e.g. ANALYTICS_CORE, ANALYTICS_LANDING
  table_naming: UPPER                 # UPPER | lower
```

---

## DCM Templating

```yaml
dcm:
  env_suffix_applies_to:              # DCM {{env_suffix}} is ONLY applied to these types
    - warehouses
    - roles
  # Never apply env_suffix to: tables, views, schemas, stages, pipes
```

---

## AgentOps

```yaml
agentops:
  agents_dir: agent                   # Directory for agent definitions
  evals_dir: agent/evals
  generate_deploy_scripts: true       # Generate deploy_all.py and run_evals.py
```

---

## MLOps (if include_mlops: true)

```yaml
mlops:
  models_dir: ml
  dual_control_approval: true         # Require approvals.md with dual-control checklist
  # for high-risk models
  model_registry: snowflake           # snowflake | mlflow | custom
```

---

## Dashboards (if include_dashboards: true)

```yaml
dashboards:
  framework: streamlit                # streamlit | sigma | custom
  apps_dir: dashboards
  shared_auth: true                   # Generate shared auth.py module
```

---

## Client Notes

```
# Add client-specific scaffolding constraints here.
# Example:
#   - Client uses GitLab CI/CD, not GitHub Actions — use gitlab platform
#   - Only DEV and PROD environments (no QA)
#   - Service user is "SF_CI_BOT" not the default "CI_SERVICE_USER"
#   - MLOps pillar required with Snowflake Model Registry
#   - All warehouses must be X-SMALL by default (cost control)
#   - Default role for CI/CD must be ANALYTICS_ENGINEER_ROLE, not ACCOUNTADMIN
```
