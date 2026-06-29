# Root Files Reference

## Directory Structure

```bash
mkdir -p {PROJECT_NAME}
cd {PROJECT_NAME}
mkdir -p sources/definitions
mkdir -p ingestion/openflow/setup ingestion/openflow/flows ingestion/openflow/connectors
mkdir -p ingestion/snowflake ingestion/snowpark ingestion/config
mkdir -p dbt/models/staging dbt/models/intermediate dbt/models/marts
mkdir -p dbt/macros dbt/snapshots dbt/tests/generic dbt/analyses dbt/seeds
mkdir -p agent/agents scripts .github/workflows
```

If MLOps:
```bash
mkdir -p custom-ml-models/snowflake/sql custom-ml-models/templates
mkdir -p custom-ml-models/lifecycle custom-ml-models/environments custom-ml-models/runbooks
```

If Dashboards:
```bash
mkdir -p streamlit/shared streamlit/apps
```

---

## manifest.yml

```yaml
manifest_version: 2
type: DCM_PROJECT
default_target: 'DEV'

targets:
  DEV:
    project_name: '{DATABASE}.{SCHEMA}.{PROJECT_NAME_UPPER}_DEV'
    project_owner: {DEFAULT_ROLE}
    account_identifier: '{ACCOUNT}'
    templating_config: 'DEV'
  PROD:
    project_name: '{DATABASE}.{SCHEMA}.{PROJECT_NAME_UPPER}'
    project_owner: {DEFAULT_ROLE}
    account_identifier: '{ACCOUNT}'
    templating_config: 'PROD'
  CI:
    project_name: '{DATABASE}_CI.{SCHEMA}.{PROJECT_NAME_UPPER}_CI'
    project_owner: {DEFAULT_ROLE}
    account_identifier: '{ACCOUNT}'
    templating_config: 'DEV'

templating:
  defaults:
    env_suffix: '_DEV'
    wh_size: 'XSMALL'
  configurations:
    DEV:
      env_suffix: '_DEV'
      wh_size: 'XSMALL'
    PROD:
      env_suffix: ''
      wh_size: 'MEDIUM'
```

`{PROJECT_NAME_UPPER}` = PROJECT_NAME in UPPER_SNAKE_CASE (e.g., `my-data-platform` → `MY_DATA_PLATFORM`).

---

## config.toml.example

```toml
# Copy to config.toml and fill in your PAT — NEVER COMMIT config.toml
[connections.default]
account       = "{ACCOUNT}"
user          = "{SERVICE_USER}"
authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
token         = ""
warehouse     = "{WAREHOUSE}"
database      = "{DATABASE}"
schema        = "{SCHEMA}"
role          = "{DEFAULT_ROLE}"

[connections.dev]
account       = "{ACCOUNT}"
user          = "{SERVICE_USER}"
authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
token         = ""
warehouse     = "{WAREHOUSE}"
database      = "{DATABASE}"
schema        = "{SCHEMA}"
role          = "{DEFAULT_ROLE}"

[connections.prod]
account       = "{ACCOUNT}"
user          = "{SERVICE_USER}"
authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
token         = ""
warehouse     = "{WAREHOUSE}"
database      = "{DATABASE}"
schema        = "{SCHEMA}"
role          = "{DEFAULT_ROLE}"

[connections.ci]
account       = "{ACCOUNT}"
user          = "{SERVICE_USER}"
authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
token         = ""   # Set via SNOWFLAKE_PAT GitHub Secret in CI
warehouse     = "{WAREHOUSE}"
database      = "{DATABASE}"
schema        = "{SCHEMA}"
role          = "{DEFAULT_ROLE}"
```

---

## .gitignore

```gitignore
out/
.snow/
__pycache__/
*.pyc
*.pyo
.venv/
venv/
.env
config.toml
*.pem
*.key
*.p8
profiles.yml
dbt/target/
dbt/dbt_packages/
dbt/logs/
airflow.db
airflow.cfg
airflow/logs/
webserver_config.py
agent/agents/*/evals/results/*.json
.DS_Store
Thumbs.db
.idea/
.vscode/
```

---

## .gitleaks.toml

```toml
[allowlist]
description = "Gitleaks allowlist for CI templates"
paths = [
    '''config\.toml\.example''',
    '''profiles\.yml\.example''',
]
```

---

## README.md

```markdown
# {PROJECT_NAME_TITLE}

> A unified platform for managing a production Snowflake account: **DataOps**, **AgentOps**{, **MLOps**}{, **Dashboards**}.

## Snowflake Account

| Setting | Value |
|---------|-------|
| Account | `{ACCOUNT}` |
| Primary database | `{DATABASE}` |
| Schema | `{SCHEMA}` / `{LANDING_SCHEMA}` |
| Warehouse | `{WAREHOUSE}` |
| Service user | `{SERVICE_USER}` |

### Local Setup

```bash
pip install snowflake-cli
cp config.toml.example config.toml
# Fill in your PAT — NEVER commit config.toml
snow connection test -c default
```

## Quick Start

```bash
snow dcm plan --target DEV -c default
snow dcm deploy --target DEV -c default
cd dbt && dbt deps && dbt run && dbt test
python agent/deploy_all.py -c default
```

## CI/CD

- **PR Validation** (`validate.yml`): DCM plan, dbt compile, agent validation, naming lint, security scan.
- **Deploy** (`deploy.yml`): Deploys on merge to `main` (PROD) or manually (DEV).
```
