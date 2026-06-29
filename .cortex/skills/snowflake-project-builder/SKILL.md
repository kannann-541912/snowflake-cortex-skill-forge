---
name: snowflake-project-builder
description: >
  Introspect live Snowflake objects (tables, views, stages, streams, tasks, warehouses, roles,
  Cortex Agents, ML models, procedures, UDFs, DMFs, dynamic tables, policies, tags, pipes,
  sequences, integrations, secrets) and scaffold them into the snowflake-project repository
  following DCM, dbt, AgentOps, and MLOps conventions.
  Triggers: build object, scaffold table, add to project, import from Snowflake,
  onboard object, reverse-engineer DDL, add table to DCM, add stream, add task,
  scaffold dbt model, scaffold agent, new agent, add ML model, onboard model, register model.
tools:
  - snowflake_sql_execute
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Client Context
Read `references/client-context.md` at the start of every invocation. Apply any values it
defines as overrides: project root path, Snowflake environment, naming conventions, object
classification rules (DCM vs imperative SQL), dbt integration settings, and conflict
detection behavior. If the file is absent or a value is unset (`~`), use the built-in
defaults. Never fail if the file is missing.

# Snowflake Project Builder

Reverse-engineers live Snowflake objects and scaffolds them into the `snowflake-project`
repository following all existing conventions: DCM `DEFINE` syntax, dbt model patterns,
ingestion config, and naming standards.

## Domain Context

You are a Snowflake platform reverse-engineer specializing in object introspection, DCM
definition generation, and dbt model scaffolding. You know every Snowflake object type,
which belong in DCM vs imperative SQL, and how to translate `GET_DDL` output into
idiomatic project code. You produce complete, append-ready file sections — never stubs.

Behavioral directive: always run `DESCRIBE` and `GET_DDL` before writing any file. Never
assume column types or DDL — read from the live account.

## Project Root

The target project is located at: `/Users/kannannvelmurugiah/Desktop/snowflake-project`

All file paths are relative to this root unless otherwise stated.

## When to Use

- User wants to add an existing Snowflake object to the project as code
- "add this table to the project", "scaffold a dbt model for X", "import this stream"
- User provides Snowflake FQNs (e.g., `SANDBOX.TPCH.MY_TABLE`) and wants them in the repo
- User wants to reverse-engineer DDL into DCM definitions
- User wants to onboard new objects discovered in Snowflake into version control

## When NOT to Use

- User wants to start a brand new project from scratch → use `snowflake-project-scaffolder`
- User only wants to profile or load data → use the `de-*` workflow skills
- User wants a standalone dbt test → use `dbt-expectations-generator`
- User is building an Airflow DAG → use `airflow-dag-generator`

## Gotchas

- `env_suffix` templating applies ONLY to warehouses and roles — **never** to data tables/views. Applying it to tables will break DCM deploys.
- Tasks and alerts are **NOT DCM-managed** (no `DEFINE` syntax exists) — they always use `CREATE OR REPLACE` and go in imperative SQL files.
- Secrets: never include actual secret values — always use empty string placeholders with a Snowsight comment.
- Stored procedures with colon-prefixed variables (`:var`) inside SQL statements are a Snowflake Scripting quirk — preserve them exactly.
- Streams on TPCH source (`SNOWFLAKE_SAMPLE_DATA`) will always show 0 rows — see AGENTS.md gotcha.
- Tasks are SUSPENDED by default after `CREATE OR REPLACE` — always note `ALTER TASK ... RESUME` in the generated file header.
- For dbt staging models: use `source()` ref, not direct table FQNs.

## Step 0 — Load client context
Read `references/client-context.md`. If present, apply:
- `project_root` → override the hardcoded default project path
- `naming.*` → table case, column case, schema separator, and all prefix conventions
- `object_classification.dcm_managed` / `object_classification.imperative_sql` → classification rules
- `dbt.*` → dbt project path, model prefixes, schema file names
- `conflict_detection.*` → whether to abort or warn on duplicate definitions

## Phase 1 — Planning (Mandatory — Do Not Skip)

Read [references/01-planning.md](references/01-planning.md) for:
- Step 1.1: How to gather and discover the object list
- Step 1.2: Introspection commands per object type (full lookup table)
- Step 1.3: Object classification → target file mapping
- Step 1.4: Dependency analysis queries
- Step 1.5: Conflict detection (grep for existing definitions)
- Step 1.6: Plan presentation format and confirmation gate

**⚠️ MANDATORY STOPPING POINT — present the scaffold plan table and wait for explicit user confirmation before generating any files.**

## Phase 2 — Generation

Read the appropriate reference file for each object type being generated:

| Object Category | Reference File |
|---|---|
| DCM objects: Tables, Views, Infra (Warehouses/Schemas), Access (Roles/Grants) | [references/02-dcm-definitions.md](references/02-dcm-definitions.md) |
| Ingestion objects: Stages, File Formats, Streams, Tasks, Pipes | [references/03-ingestion-objects.md](references/03-ingestion-objects.md) |
| Procedural objects: Stored Procs, UDFs, DMFs, Dynamic Tables, Alerts, Policies, Tags, Sequences, Integrations, Secrets | [references/04-procedural-objects.md](references/04-procedural-objects.md) |
| dbt Staging and Mart models | [references/05-dbt-models.md](references/05-dbt-models.md) |
| Cortex Agent scaffold | [references/06-agentops-scaffold.md](references/06-agentops-scaffold.md) |
| ML Model scaffold | [references/07-mlops-scaffold.md](references/07-mlops-scaffold.md) |
| Conventions reference (naming, templating, file org) | [references/08-conventions.md](references/08-conventions.md) |

## Phase 3 — Verification

After generation:

```bash
cd /Users/kannannvelmurugiah/Desktop/snowflake-project
python scripts/check_naming.py
snow dcm plan --target DEV -c default
cd dbt && dbt compile
python scripts/validate_agent_spec.py
```

Fix any errors reported before presenting the summary.

## Phase 4 — Summary

```
SCAFFOLD COMPLETE ✓
Objects:   {N} scaffolded
Files:     {list of modified/created files}

⚠️ Reminder: If any tasks or alerts were generated, resume them:
  ALTER TASK <task_name> RESUME;
  ALTER ALERT <alert_name> RESUME;
```
