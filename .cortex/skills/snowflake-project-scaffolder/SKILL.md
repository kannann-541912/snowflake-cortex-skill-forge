---
name: snowflake-project-scaffolder
description: >
  Scaffolds a new Snowflake Account Operations Platform repository from scratch.
  Creates the full directory structure, DCM definitions, dbt transform layer, AgentOps
  lifecycle, CI/CD pipelines, and optional MLOps and Streamlit dashboard pillars.
  Use when: new project, scaffold Snowflake project, init platform, start from scratch,
  create project structure, bootstrap Snowflake repo, new data platform.
tools:
  - Write
  - Bash
---

# Client Context
Read `references/client-context.md` at the start of every invocation. If present, use values
defined there to pre-fill the Phase 1 wizard answers — skipping interactive prompts for any
parameter that is already set. Apply CI/CD platform, environments, naming conventions, pillar
selections, and DCM templating rules from this file. If the file is absent or a value is
unset (`~`), prompt the user interactively. Never fail if the file is missing.

# Snowflake Project Scaffolder

Scaffolds a complete production-grade Snowflake platform repository in the current directory.
Always runs the interactive wizard first — never generates files without user confirmation.

## Domain Context

You are a Snowflake platform architect specializing in DataOps, AgentOps, and production-grade
infrastructure-as-code for Snowflake accounts. You generate opinionated, consistent scaffolding
that teams can extend without knowing every Snowflake CLI convention upfront.

Behavioral directive: produce complete, runnable files — never stubs with TODOs that block the user.

## When to Use

- User wants to start a new Snowflake platform project from scratch
- User says "scaffold a project", "init a new Snowflake project", "bootstrap a Snowflake repo"
- User wants DataOps + AgentOps + CI/CD for their Snowflake account in one setup

## When NOT to Use

- User already has an existing project and wants to add objects → use `snowflake-project-builder` instead
- User only wants a single dbt model → use `dbt-jinja-builder` instead
- User wants to profile or load data → use the `de-*` workflow skills instead

## Gotchas

- `config.toml` must NEVER be committed — it contains PAT secrets. Always add to `.gitignore` before generating any other files.
- DCM `{{env_suffix}}` templating applies ONLY to warehouses and roles — never to data tables or views.
- The shared `agent/deploy_all.py` and `agent/run_evals.py` scripts are generated once — do NOT recreate them when adding subsequent agents.
- `dbt_project.yml` `name` field must use underscores (not hyphens): `my-data-platform` → `my_data_platform`.
- Tasks are SUSPENDED by default after creation — always add `ALTER TASK ... RESUME` to the deployment notes.
- For high-risk ML models, `approvals.md` with dual-control checklist is mandatory — do not skip.

## Step 0 — Load client context
Read `references/client-context.md`. If present, apply:
- Wizard pre-fill values (`project_name`, `snowflake_account`, `primary_database`, etc.)
- `include_mlops` / `include_dashboards` → pillar selection overrides
- `cicd.platform` → github | gitlab | azure_devops
- `environments` → list of envs with suffixes and approval requirements
- `naming.*` → warehouse/role/schema naming templates
- Skip prompting for any wizard question that already has a non-`~` value set.

## Phase 1 — Interactive Wizard (Mandatory — Do Not Skip)

Ask the user:

```
REQUIRED:
1. Project name (lowercase-kebab, e.g., "my-data-platform")
2. Snowflake account identifier (e.g., "abc12345.us-east-1")
3. Primary database name (e.g., "ANALYTICS")
4. Primary schema name (e.g., "CORE")
5. Landing schema name (e.g., "CORE_LANDING")
6. Warehouse name (e.g., "ANALYTICS_WH")
7. Service user name (e.g., "CI_SERVICE_USER")
8. Default role (e.g., "ACCOUNTADMIN")
9. Reader role name (e.g., "DATA_READER")

OPTIONAL PILLARS (DataOps, AgentOps, CI/CD are always included):
10. Include MLOps pillar? [yes/no]
11. Include Dashboards pillar? [yes/no]

OPTIONAL INITIAL STUBS:
12. Name of first table to stub (e.g., "CUSTOMERS") — blank to skip
13. Name of first agent to stub (e.g., "data-analyst") — blank to skip
```

Present a scaffold plan table and **⚠️ STOP: get explicit confirmation before generating any files.**

## Phase 2 — Generate Files

Generate in this order. Read the reference files below for the exact content of each section:

| Section | Reference File |
|---|---|
| Root files (manifest, .gitignore, README, config.toml.example) | See [references/01-root-files.md](references/01-root-files.md) |
| Sources / DCM definitions | See [references/02-sources-dcm.md](references/02-sources-dcm.md) |
| Ingestion pipeline (Openflow, Streams, Tasks, Snowpark) | See [references/03-ingestion.md](references/03-ingestion.md) |
| dbt transform layer | See [references/04-dbt-layer.md](references/04-dbt-layer.md) |
| AgentOps (deploy_all.py, run_evals.py, agent stubs) | See [references/05-agentops.md](references/05-agentops.md) |
| Scripts (check_naming.py, deploy_agent.py, validate_agent_spec.py) | See [references/06-scripts.md](references/06-scripts.md) |
| CI/CD workflows (validate.yml, deploy.yml) | See [references/07-cicd.md](references/07-cicd.md) |
| MLOps pillar (only if requested) | See [references/08-mlops.md](references/08-mlops.md) |
| Dashboards pillar (only if requested) | See [references/09-dashboards.md](references/09-dashboards.md) |

## Phase 3 — Verify

Run these checks after generation:

```bash
cd {PROJECT_NAME}
python scripts/check_naming.py
python scripts/validate_agent_spec.py
python agent/deploy_all.py --list
python agent/deploy_all.py --dry-run
cd dbt && pip install dbt-snowflake -q && dbt deps && dbt parse
```

Report any errors and fix them before presenting the summary.

## Phase 4 — Summary

Present:
```
SCAFFOLD COMPLETE ✓
Project:   {PROJECT_NAME}/
Pillars:   DataOps, AgentOps, CI/CD {, MLOps} {, Dashboards}
Files:     {N} created

Next steps:
  1. cd {PROJECT_NAME} && git init && git add . && git commit -m "Initial scaffold"
  2. cp config.toml.example config.toml  (fill in your PAT — never commit this file)
  3. snow connection test -c default
  4. snow dcm plan --target DEV -c default
```
