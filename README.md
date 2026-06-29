# Snowflake Cortex Code Skill Forge

> Production-grade custom skills for the Snowflake Cortex Code CLI — turning your AI assistant into a context-aware data engineering operating system.

---

## What This Is

This repository contains a curated set of custom skills for the [Snowflake Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code). Each skill is a structured `SKILL.md` file that teaches CoCo how to perform a specific data engineering task with Snowflake-native patterns, production conventions, and built-in quality gates.

Skills are composable. They produce artifacts (`SQL` files, `YAML` mappings, Markdown reports) that feed into each other, allowing you to chain a complete data pipeline from a single conversation — or invoke individual phases on demand.

**The core idea:** your infrastructure shouldn't require a ticket, a whiteboard session, or a week of script writing. With the right skills loaded, CoCo becomes the context-aware development fabric your data team already needed.

---

## Skills in This Repository

### AI-Accelerated Data Engineering Workflow

A phase-by-phase pipeline that takes a raw source from profile to governed mart — in hours, not weeks.

| Skill | Invoke | What It Does |
|---|---|---|
| **de-workflow** | `$de-workflow` | Composable end-to-end orchestrator. Chains all 7 phases with quality gates. Supports full run, partial run, and resume. |
| **de-profile** | `$de-profile` | Auto-profiles every column of a source table — null rates, cardinality, distributions, PII candidates, recommended primary keys. |
| **de-schema-design** | `$de-schema-design` | Proposes a target schema from the profile: type mappings, SCD patterns, normalization, PII masking plan. |
| **de-schema-setup** | `$de-schema-setup` | Generates and deploys idempotent DDL — tables, masking policies, lineage tags. Governance by default. Includes a **mandatory confirmation gate** before any DDL executes. |
| **de-transform-setup** | `$de-transform-setup` | Builds reusable column transform mappings, dbt staging model stubs, and Dynamic Table DDL from source-to-target mappings. |
| **de-load-validate** | `$de-load-validate` | Loads data with a quarantine pattern, row-count reconciliation, null assertions, and a Snowflake alert on every load. Includes a **mandatory confirmation gate** before any INSERT. |
| **de-transform** | `$de-transform` | Applies business transforms via Dynamic Tables or Stream+Task MERGE. Self-healing: detects failures, resumes, runs post-transform assertions. |
| **de-share** | `$de-share` | Configures role-based access and sharing by default: functional RBAC roles, least-privilege grants, Row Access Policies, and optional cross-account data shares. |

### Platform Scaffolding

| Skill | Invoke | What It Does |
|---|---|---|
| **snowflake-project-scaffolder** | `$snowflake-project-scaffolder` | Scaffolds a new Snowflake Account Operations Platform repo from scratch — DataOps, AgentOps, CI/CD, optional MLOps and Dashboards pillars. |
| **snowflake-project-builder** | `$snowflake-project-builder` | Introspects live Snowflake objects (all 20+ types) and scaffolds them into an existing project repo as DCM definitions, dbt models, agent specs, or ML model scaffolds. |

### Code Generators

| Skill | Invoke | What It Does |
|---|---|---|
| **airflow-dag-generator** | `$airflow-dag-generator` | Generates a production Airflow DAG for dbt models against Snowflake, using Astronomer Cosmos or BashOperator with SnowflakeSensor and Slack alerting. |
| **dbt-expectations-generator** | `$dbt-expectations-generator` | Profiles a materialized dbt model in Snowflake and generates dbt-expectations tests merged into existing schema YAML — all thresholds derived from real data. |
| **dbt-jinja-builder** | `$dbt-jinja-builder` | Scaffolds a complete dbt model layer (SQL + schema.yml + sources.yml) for any Snowflake table by introspecting live column metadata. |
| **dmf-generator** | `$dmf-generator` | Generates Snowflake Data Metric Functions (DMFs) for continuous data quality monitoring, with ALTER TABLE attachment DDL and a monitoring query. |
| **great-expectations-suite-generator** | `$gx-suite-generator` | Generates a Great Expectations v1.x suite for a Snowflake table — datasource config, checkpoint, and all expectations derived from live profiling. |
| **informatica-to-dbt** | `$informatica-to-dbt` | Migrates Informatica PowerCenter/IDMC XML exports to a full dbt project targeting Snowflake — parse → assessment → scaffold. |

---

## The End-to-End DE Workflow

```
$de-profile          →  profile_report.md
    ↓  [Quality Gate 1: non-empty, PII & PK identified]

$de-schema-design    →  schema_design.md
    ↓  [Quality Gate 2: all columns mapped, NOT NULL constraints viable]

$de-schema-setup     →  schema_setup.sql  +  Snowflake objects deployed
    ↓  [⚠️ Mandatory Stop: user confirms DDL before execution]
    ↓  [Quality Gate 3: tables exist, masking policies applied, lineage tagged]

$de-transform-setup  →  transform_mappings.yml  +  dbt models  +  Dynamic Table DDL
    ↓  [Quality Gate 4: 100-row sample test passes, 0 null violations]

$de-load-validate    →  rows loaded  +  quarantine table  +  quality alert
    ↓  [⚠️ Mandatory Stop: user confirms target before INSERT]
    ↓  [Quality Gate 5: rows loaded > 0, rejection rate < 5%]

$de-transform        →  populated mart table  +  running Dynamic Table / Task
    ↓  [Quality Gate 6: row delta < 5%, no critical nulls, freshness OK]

$de-share            →  RBAC grants  +  governance_report.md
    ↓  [Quality Gate 7: PII masked for consumer role, governance documented]
```

Run the whole thing with one command:

```
> $de-workflow Build a pipeline from SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.ORDERS into SANDBOX.TPCH
```

Or run any phase standalone — each skill has its own quality gate you can run independently:

```
> $de-profile Profile SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.LINEITEM
> $de-transform-setup Build transforms for ORDERS → SANDBOX.TPCH.STG_ORDERS
> $de-workflow resume
```

---

## Repository Structure

```
snowflake-cortex-skill-forge/
├── AGENTS.md                              # Global conventions — loaded by CoCo on every session
├── README.md
│
└── .cortex/
    └── skills/
        │
        ├── 00-de-workflow/                # Orchestrates phases 01–07 end-to-end
        │   └── SKILL.md
        │
        ├── 01-profile/                    # Phase 1 — Source profiling
        │   └── SKILL.md
        │
        ├── 02-schema-design/              # Phase 2 — Target schema design
        │   └── SKILL.md
        │
        ├── 03-schema-setup/               # Phase 3 — DDL generation & deployment
        │   └── SKILL.md                   # ⚠️ Mandatory stop before DDL execution
        │
        ├── 04-transform-setup/            # Phase 4 — Transform mappings & dbt stubs
        │   └── SKILL.md
        │
        ├── 05-load-validate/              # Phase 5 — Load + quarantine + quality gates
        │   └── SKILL.md                   # ⚠️ Mandatory stop before INSERT
        │
        ├── 06-transform/                  # Phase 6 — Dynamic Tables / Stream+Task MERGE
        │   └── SKILL.md
        │
        ├── 07-share/                      # Phase 7 — RBAC + governance report
        │   └── SKILL.md
        │
        ├── snowflake-project-scaffolder/  # New project scaffold (DataOps + AgentOps + CI/CD)
        │   ├── SKILL.md                   # ~120 lines — concise entrypoint
        │   └── references/
        │       ├── 01-root-files.md       # manifest, .gitignore, README, config.toml
        │       ├── 02-sources-dcm.md      # DCM table/view/infra/access definitions
        │       ├── 03-ingestion.md        # Streams, Tasks, COPY INTO, Snowpark, Openflow
        │       ├── 04-dbt-layer.md        # dbt_project.yml, profiles, packages, model stubs
        │       ├── 05-agentops.md         # deploy_all.py, run_evals.py, agent stub
        │       ├── 06-scripts.md          # check_naming.py, deploy_agent.py, validate_spec.py
        │       ├── 07-cicd.md             # validate.yml, deploy.yml GitHub Actions
        │       ├── 08-mlops.md            # MLOps pillar (optional)
        │       └── 09-dashboards.md       # Streamlit dashboards pillar (optional)
        │
        ├── snowflake-project-builder/     # Reverse-engineer live objects → project files
        │   ├── SKILL.md                   # ~118 lines — concise entrypoint
        │   └── references/
        │       ├── 01-planning.md         # Discovery, introspection, classification, conflict check
        │       ├── 02-dcm-definitions.md  # TABLE, VIEW, WAREHOUSE, ROLE DEFINE blocks
        │       ├── 03-ingestion-objects.md# STAGE, STREAM, TASK, PIPE templates
        │       ├── 04-procedural-objects.md # PROC, UDF, DMF, DT, ALERT, POLICY, TAG, SECRET
        │       ├── 05-dbt-models.md       # Staging & mart model + sources YAML
        │       ├── 06-agentops-scaffold.md# agent.yml, system_prompt, evals, monitoring
        │       ├── 07-mlops-scaffold.md   # spec.yml, model_card, SQL, lifecycle, runbooks
        │       └── 08-conventions.md      # Naming, templating, file org reference
        │
        ├── dbt-expectations-generator/    # Auto-generate dbt-expectations tests from real data
        │   ├── SKILL.md
        │   └── references/
        │       ├── 01-test-selection-logic.md  # Signal→test mapping table + tolerances
        │       └── 02-test-reference.md         # Full dbt-expectations test catalogue + regex
        │
        ├── airflow-dag-generator/         # Airflow DAG for dbt models (Cosmos / BashOperator)
        │   └── SKILL.md
        │
        ├── dbt-jinja-builder/             # dbt model + schema.yml + sources.yml scaffolder
        │   └── SKILL.md
        │
        ├── dmf-generator/                 # Snowflake Data Metric Function generator
        │   └── SKILL.md
        │
        ├── great-expectations-suite-generator/  # GX v1.x suite from live Snowflake profiling
        │   └── SKILL.md
        │
        └── informatica-to-dbt/            # Informatica PowerCenter/IDMC → dbt migration
            └── SKILL.md
```

---

## Getting Started

### Prerequisites

- Snowflake account with Cortex Code CLI enabled
- Snowflake CLI installed: `pip install snowflake-cli`
- Access to a writable database (e.g. `SANDBOX.TPCH`)
- `config.toml` configured with your connection (see `config.toml.example` in scaffolded projects)

### Installation

There are three ways to install these skills depending on how broadly you want them available.

---

#### Option 1 — Global install (skills available in every CoCo session)

This is the recommended approach. Skills installed globally are available regardless of which directory you run CoCo from.

**Step 1: Clone this repository**

```bash
git clone https://github.com/kannann-541912/snowflake-cortex-skill-forge.git
cd snowflake-cortex-skill-forge
```

**Step 2: Create the global skills directory if it doesn't exist**

```bash
mkdir -p ~/.snowflake/cortex/skills
```

**Step 3: Copy all skills into it**

```bash
cp -r .cortex/skills/* ~/.snowflake/cortex/skills/
```

Your `~/.snowflake/cortex/skills/` directory will now look like this:

```
~/.snowflake/cortex/skills/
├── 00-de-workflow/
│   └── SKILL.md
├── 01-profile/
│   └── SKILL.md
├── 02-schema-design/
│   └── SKILL.md
├── 03-schema-setup/
│   └── SKILL.md
├── 04-transform-setup/
│   └── SKILL.md
├── 05-load-validate/
│   └── SKILL.md
├── 06-transform/
│   └── SKILL.md
├── 07-share/
│   └── SKILL.md
├── snowflake-project-scaffolder/
├── snowflake-project-builder/
├── dbt-expectations-generator/
├── airflow-dag-generator/
├── dbt-jinja-builder/
├── dmf-generator/
├── great-expectations-suite-generator/
└── informatica-to-dbt/
```

**Step 4: Start a CoCo session from any directory**

```bash
snow cortex run
```

---

#### Option 2 — Project-level install (skills available in this project only)

CoCo auto-discovers skills in `.cortex/skills/` relative to the working directory. If you clone this repo and run CoCo from inside it, no extra steps are needed:

```bash
git clone https://github.com/kannann-541912/snowflake-cortex-skill-forge.git
cd snowflake-cortex-skill-forge
snow cortex run
```

---

#### Option 3 — Copy into an existing project

To bring these skills into a project you already have:

```bash
cp -r .cortex /path/to/your/snowflake-project/
cp AGENTS.md /path/to/your/snowflake-project/
```

Then run CoCo from that project directory — skills in `.cortex/skills/` are picked up automatically.

---

### Verify the skills loaded

Inside a running CoCo session, list all available skills:

```
> /skill list
```

You should see all skills labelled as `[G] Global` (from `~/.snowflake/cortex/skills/`) or `[P] Project` (from `.cortex/skills/`):

```
[G] Global   de-workflow                 Composable DE orchestrator — chains all 7 phases
[G] Global   de-profile                  Auto-profiles every column of a source table
[G] Global   de-schema-design            Proposes target schema from a profile report
[G] Global   de-schema-setup             Generates and deploys idempotent DDL
[G] Global   de-transform-setup          Builds column transform mappings and dbt stubs
[G] Global   de-load-validate            Loads data with quarantine and quality gates
[G] Global   de-transform                Applies business transforms via Dynamic Tables
[G] Global   de-share                    Configures RBAC and optional cross-account shares
[G] Global   snowflake-project-scaffolder  Scaffolds a new Snowflake platform repo
[G] Global   snowflake-project-builder   Reverse-engineers live objects into project files
[G] Global   airflow-dag-generator       Generates production Airflow DAG for dbt + Snowflake
[G] Global   dbt-expectations-generator  Auto-generates dbt-expectations tests from real data
[G] Global   dbt-jinja-builder           Scaffolds dbt model + schema.yml + sources.yml
[G] Global   dmf-generator               Generates Snowflake Data Metric Functions
[G] Global   great-expectations-suite-generator  GX v1.x suite from live Snowflake profiling
[G] Global   informatica-to-dbt          Migrates Informatica XML exports to a dbt project
```

To inspect a specific skill's description and trigger phrases:

```
> /skill de-profile
```

---

### Invoking Skills with `/skill`

Once loaded, skills are invoked by natural language — CoCo matches your request to the right skill automatically. The `/skill` command lets you invoke or inspect skills explicitly.

**Invoke a skill directly by name:**

```
> /skill de-profile Profile SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.ORDERS
```

**Invoke via natural language (CoCo picks the skill automatically):**

```
> Profile the ORDERS table and identify PII columns
> Design a target schema for TPCH_SF10.LINEITEM in SANDBOX
> Generate dbt-expectations tests for SANDBOX.TPCH.MART_REVENUE
```

**Run the full end-to-end DE pipeline:**

```
> /skill de-workflow Build a pipeline from SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.ORDERS into SANDBOX.TPCH
```

**Run a specific phase standalone:**

```
> /skill de-profile Profile SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.LINEITEM
> /skill de-transform-setup Build transforms for ORDERS → SANDBOX.TPCH.STG_ORDERS
> /skill de-workflow resume
```

**Reference a skill in any message using `$skill-name` shorthand:**

```
> $de-profile Profile the LINEITEM table
> $dbt-jinja-builder Scaffold models for SANDBOX.TPCH.STG_ORDERS
> $snowflake-project-scaffolder Create a new project with DataOps and AgentOps pillars
```

---

### Keeping Skills Up to Date

To pull the latest skills after changes are published to this repo:

```bash
cd snowflake-cortex-skill-forge
git pull
cp -r .cortex/skills/* ~/.snowflake/cortex/skills/
```

---

## AGENTS.md — Global Conventions

`AGENTS.md` is the backbone of consistent skill behaviour. Every CoCo session in this project inherits it without any skill having to repeat the information.

It defines:

| Section | What It Covers |
|---|---|
| **Identity and Role** | Agent persona — Snowflake DE SME, not a generic SQL generator |
| **Environment** | Source DB (`SNOWFLAKE_SAMPLE_DATA.TPCH_SF10`, read-only), target DB (`SANDBOX.TPCH`), warehouse defaults |
| **TPCH Source Catalogue** | All 8 tables with PKs, FKs, row counts, and sampling guidance |
| **Naming Conventions** | UPPER_SNAKE_CASE objects, `STG_*`/`MART_*`/`MASK_*`/`RAP_*`/`DMF_*` prefixes |
| **Standard Audit Columns** | `_LOADED_AT`, `_SOURCE_SYSTEM`, SCD2 columns — added to every table |
| **Quality Thresholds** | Quarantine rate, row delta, null rate, freshness thresholds with STOP/WARN actions |
| **DDL Rules** | `CREATE IF NOT EXISTS` only, governance-at-creation, clustering key guidance |
| **Type Mapping** | Source pattern → Snowflake type reference |
| **RBAC Role Hierarchy** | `DE_CONSUMER_ROLE`, `DE_ANALYST_ROLE`, `DE_ENGINEER_ROLE` with grant rules |
| **Artifact Chain** | The file sequence connecting all 7 DE phases |
| **TPCH Gotchas** | Known failure modes: static streams, FLOAT prices, composite PKs |

**Adapting for your environment:** Change the source/target databases, adjust naming conventions, update quality thresholds to match your SLAs, and replace the TPCH catalogue with your own source schema.

---

## Design Principles

**Composability over monoliths.** Each skill is a standalone unit that produces a documented artifact. Skills are chained by the orchestrator but always run independently.

**Progressive disclosure.** Large skills use a concise `SKILL.md` (≤ 200 lines) as the entrypoint and load heavy content from `references/` files on demand — keeping the context window lean and fast.

**Quality gates between every phase.** Skills don't silently proceed on failure. Every phase checks its own output before advancing, reports what went wrong, and offers recovery options.

**Mandatory stopping points for irreversible actions.** DDL execution and bulk INSERTs require explicit human confirmation — even if the user has approved the plan earlier in the session.

**Governance by default.** Masking policies, lineage tags, and RBAC roles are applied at object creation — not as an afterthought.

**Idempotent DDL.** All generated SQL uses `CREATE ... IF NOT EXISTS`. Running a skill twice on the same environment is always safe.

**Artifact-driven context.** Skills communicate through files (`profile_report.md`, `schema_design.md`, `transform_mappings.yml`) so context survives session boundaries and can be version-controlled.

---

## Building a New Skill — Best Practices Guide

This section covers everything you need to know to contribute a production-grade skill to this repository (or build one from scratch for your own project).

### Anatomy of a Skill

Every skill is a folder with a required `SKILL.md` and optional supporting files:

```
my-skill-name/
├── SKILL.md          ← Required. The skill entrypoint.
└── references/       ← Optional. Heavy content loaded on demand.
    ├── 01-topic-a.md
    └── 02-topic-b.md
```

### SKILL.md Structure

```markdown
---
name: my-skill-name
description: >
  One-to-three sentences the runtime uses for skill matching.
  Include natural-language trigger phrases: "when user says X, Y, Z".
  Make it specific enough to avoid false activations.
parent_skill: parent-skill-name   # Optional — for sub-skills in a hierarchy
tools:
  - snowflake_sql_execute
  - Read
  - Write
---

# My Skill Title

## Domain Context
[Who the agent is and what expertise it brings. 3–5 sentences.]
[Includes a behavioral directive: "produce complete X, never Y".]

## When to Use
- [Concrete trigger scenario 1]
- [Trigger phrases: "user says X, Y, Z"]

## When NOT to Use
- [Out-of-scope scenario 1] → direct to the right skill instead
- [Scenario that looks similar but isn't] → redirect with reason

## Gotchas
- [Non-obvious failure mode or constraint — one line each]
- [Ordering dependency, API quirk, naming pitfall]

## Phase 1 — [Phase Name] (mandatory gate)

⚠️ **MANDATORY STOPPING POINT** — [only for irreversible actions]
[Enumerate what must be confirmed before proceeding]

[Phase instructions...]

## Phase 2 — [Phase Name]

For heavy content, link to a reference file:
Read [references/01-topic.md](references/01-topic.md) for [what it contains].

## Standalone Quality Gate
[SQL or bash to verify this skill completed successfully]
```

---

### Naming Rules

| Rule | Detail |
|---|---|
| Skill name | `lowercase-kebab-case` — no spaces, no underscores |
| Reserved words | Never use: `claude`, `cursor`, `cortex`, `snowflake` as the **first** word |
| Folder name | Must exactly match the `name:` field in frontmatter |
| Snowflake objects | `UPPER_SNAKE_CASE` — tables, views, roles, policies |
| dbt models | `lowercase_snake_case` — `stg_orders`, `fct_revenue` |

---

### The `description:` Field — Write It for the Matcher

The description is how the runtime decides which skill to invoke. It is not a user-facing label. Write it to match natural user phrasing:

```yaml
# Bad — too abstract
description: "Handles data engineering tasks."

# Good — specific + includes trigger phrases
description: >
  Generate Snowflake Data Metric Functions for automated data quality monitoring.
  Use when: add DMFs, create data metric functions, set up quality monitoring,
  add data quality checks, attach DMF to table.
```

Include 5–10 natural-language trigger phrases as a comma-separated list after "Use when:".

---

### Progressive Disclosure — Keep SKILL.md Lean

The single biggest performance lever in skill design. The SKILL.md is loaded in full for every invocation. Every line costs tokens.

**Target sizes:**
- `SKILL.md`: ≤ 200 lines for a focused skill, ≤ 400 lines for a complex orchestrator
- `references/*.md`: no hard limit — loaded on demand only when needed

**What stays in `SKILL.md`:** phases, decision logic, short SQL patterns, stopping points, quality gates

**What moves to `references/`:** large SQL templates, 40+ row lookup tables, complete file templates, full test catalogues, detailed runbooks

Reference files are loaded by instruction in the skill body:
```markdown
Read [references/01-test-selection-logic.md](references/01-test-selection-logic.md)
for the complete test selection table before generating tests.
```

This pattern reduces context window usage by 60–80% compared to monolithic skills.

---

### Required Sections Checklist

Every skill in this repository must have these sections. Run this checklist before submitting a PR:

```
[ ] name: field — lowercase-kebab-case, no reserved words
[ ] description: field — includes 5+ natural trigger phrases
[ ] parent_skill: field — if this is a sub-skill of an orchestrator
[ ] tools: field — minimum necessary tool list
[ ] Domain Context — who the agent is + behavioral directive
[ ] When to Use — 3+ concrete triggers
[ ] When NOT to Use — 2+ explicit out-of-scope cases with redirects
[ ] Gotchas — 3+ non-obvious failure modes or constraints
[ ] SKILL.md ≤ 400 lines — heavy content in references/ files
[ ] ⚠️ MANDATORY STOPPING POINT — before any irreversible action (DDL, bulk INSERT, deploy)
[ ] Standalone Quality Gate — SQL/bash to verify the skill ran successfully
```

---

### Domain Context — Give the Agent a Persona

The Domain Context section shapes everything the agent produces. Without it, responses are generic. With it, the agent reasons like a specialist.

```markdown
## Domain Context
You are a Snowflake schema architect specializing in idempotent, governance-by-default
DDL deployment. You know every Snowflake object type, which belong in DCM vs imperative
SQL, and how to apply masking policies and lineage tags at object creation time — never
as afterthoughts.

Behavioral directive: produce complete, runnable DDL files — never stubs with TODOs.
```

**Pattern:** `You are a [role] specializing in [domain].` + 1–2 sentences of expert knowledge + 1 behavioral directive.

---

### When NOT to Use — Prevent False Activations

This section is as important as "When to Use". Without it, the agent will attempt tasks it's not suited for.

```markdown
## When NOT to Use
- User wants to profile data first → run `de-profile` before this skill
- User only wants to view the schema, not deploy → describe it in plain text
- User's target is SNOWFLAKE_SAMPLE_DATA → abort immediately, it's read-only
```

For each case, name the better alternative if one exists.

---

### Gotchas — Document What Breaks

Gotchas are concise, factual statements about failure modes the agent must know. They prevent the most common categories of errors:

```markdown
## Gotchas
- Never use CREATE OR REPLACE TABLE — it destroys data. Always CREATE TABLE IF NOT EXISTS.
- Deploy order: masking policies → tables → views → row access policies. Never reverse.
- Streams on SNOWFLAKE_SAMPLE_DATA always show 0 rows — it's a static dataset.
- Tasks are SUSPENDED by default — always ALTER TASK ... RESUME after creation.
```

**Sources for gotchas:** your own debugging sessions, known API quirks, ordering dependencies, naming constraints, and anything you've had to look up twice.

---

### Mandatory Stopping Points — Protect Against Irreversible Actions

Add a stopping point before any action that cannot be undone:

```markdown
⚠️ **MANDATORY STOPPING POINT** — Before executing any CREATE/ALTER statement:
1. Show the user the complete DDL that will be executed.
2. Verify the target path does NOT start with SNOWFLAKE_SAMPLE_DATA.
3. Wait for explicit user confirmation before proceeding.
```

Use these for: DDL execution, bulk data loads, agent/model deployments, any destructive operation.

---

### Standalone Quality Gates — Enable Independent Invocation

Every phase skill should be independently verifiable. A quality gate is a SQL or bash snippet that confirms the phase completed correctly, without requiring the full workflow context:

```markdown
## Standalone Quality Gate
```sql
SELECT COUNT(*) AS rows_loaded, MAX(_LOADED_AT) AS last_load
FROM SANDBOX.TPCH.STG_ORDERS;
-- Expected: rows_loaded > 0, last_load within the last hour
```
```

This enables:
- Resuming a workflow from the middle
- Debugging a specific phase in isolation
- CI/CD verification steps

---

### Sub-Skills and `parent_skill`

When a skill is a logical component of a larger orchestrating skill, declare the relationship:

```yaml
---
name: de-profile
parent_skill: de-workflow   # ← links this to the orchestrator
---
```

This enables hierarchical discovery: CoCo can navigate from the parent to the sub-skill and back, and users can see the full skill tree with `/skill list`.

---

### Tools — Minimum Necessary

Request only the tools your skill actually uses. Unnecessary tool declarations expand the permission surface and slow down invocations.

| Tool | When to Include |
|---|---|
| `snowflake_sql_execute` | Any skill that runs SQL |
| `snowflake_object_search` | Any skill that needs to discover Snowflake objects |
| `Read` | Any skill that reads local files (YAML, SQL, Markdown) |
| `Write` | Any skill that creates or updates local files |
| `Edit` | When in-place file edits are needed (vs full rewrites) |
| `Bash` | For local CLI commands (dbt, git, snow, python scripts) |
| `Glob` | For pattern-based file discovery |
| `Grep` | For searching file contents |

---

### Testing Your Skill Before Committing

1. **Load check**: `snow cortex /skill list` — skill should appear with correct name
2. **Trigger test**: describe your use case in natural language — skill should activate
3. **Boundary test**: describe an out-of-scope case — skill should NOT activate (or should redirect)
4. **Run it end-to-end** with at least one real invocation — all phases must complete without errors
5. **Quality gate**: run the standalone quality gate SQL/bash and verify it returns expected results
6. **Line count**: `wc -l SKILL.md` — should be ≤ 400 lines. If over, move content to `references/`

---

## Roadmap

- [ ] `$de-lineage` — cross-system lineage view spanning Snowflake, dbt, and Airflow DAGs
- [ ] `$de-cost` — cost optimisation agent: clustering keys, idle warehouses, expensive queries
- [ ] `$de-contract` — auto-generate dbt model contracts and YAML schemas from profile data
- [ ] `$de-anomaly` — anomaly detection rules builder outputting Snowflake alerts and Soda checks
- [ ] `$de-incident` — on pipeline failure, gather errors from Snowflake, Airflow, dbt, and Git, then propose a root cause hypothesis

---

## Contributing

Contributions are welcome. To add a new skill or improve an existing one:

1. Fork the repository
2. Create a branch: `git checkout -b skill/your-skill-name`
3. Build your skill following the **Building a New Skill** guide above
4. Run the required sections checklist before opening a PR
5. Test the skill in a live CoCo session — include the `/skill list` output and at least one example invocation in your PR description
6. Open a pull request with: what the skill does, what phase/category it belongs to, what artifacts it produces, and the trigger phrases in the description field

**Quality bar for merging:**
- ✓ Passes the required sections checklist
- ✓ `SKILL.md` ≤ 400 lines
- ✓ Has `When NOT to Use` with at least 2 redirects
- ✓ Has `Gotchas` with at least 3 entries
- ✓ Has a `Standalone Quality Gate`
- ✓ All irreversible actions have a `⚠️ MANDATORY STOPPING POINT`
- ✓ At least one successful end-to-end test run documented in the PR

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

*Built for teams who believe that infrastructure setup should take hours, not weeks — and that your AI assistant should know the difference between a staging table and a mart.*
