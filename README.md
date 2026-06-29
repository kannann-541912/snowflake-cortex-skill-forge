# Snowflake Cortex Code Skill Forge

> Production-grade plugins and skills for the Snowflake Cortex Code CLI — turning your AI assistant into a context-aware data engineering operating system.

---

## What This Is

A curated collection of **plugins** and **skills** for the [Snowflake Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code). Each unit teaches CoCo how to perform a specific data engineering task with Snowflake-native patterns, production conventions, and built-in quality gates.

**Plugins** wrap related skills into a single enforced unit. Hook-enforced gates make phase ordering, artifact chain integrity, and context-reading constraints impossible to bypass — not just requested.

**Loose skills** handle single-purpose tasks where no phase ordering or shared state is needed.

The core idea: your infrastructure shouldn't require a ticket, a whiteboard session, or a week of script writing. With the right skills loaded, CoCo becomes the context-aware development fabric your data team already needed.

---

## Plugins

### `de-pipeline-plugin` — Hook-Enforced 7-Phase DE Pipeline

The flagship plugin. Wraps all 8 DE workflow skills into a state-machine-governed pipeline.
Phase ordering is a hard constraint — the agent physically cannot jump phases or write files before reading client context.

**Requires:** `jq`

| Skill | Invoke | Phase |
|---|---|---|
| **de-workflow** | `$de-workflow` | Orchestrator — chains all 7 phases with quality gates |
| **de-profile** | `$de-profile` | 1 — Auto-profiles every column: null rates, cardinality, PII candidates |
| **de-schema-design** | `$de-schema-design` | 2 — Proposes target schema: type mappings, SCD patterns, masking plan |
| **de-schema-setup** | `$de-schema-setup` | 3 — Generates and deploys idempotent DDL with governance by default |
| **de-transform-setup** | `$de-transform-setup` | 4 — Builds column transform mappings, dbt stubs, Dynamic Table DDL |
| **de-load-validate** | `$de-load-validate` | 5 — Loads data with quarantine, row-count reconciliation, and quality alerts |
| **de-transform** | `$de-transform` | 6 — Applies business transforms via Dynamic Tables or Stream+Task MERGE |
| **de-share** | `$de-share` | 7 — Configures RBAC, Row Access Policies, and optional cross-account shares |

**What the hooks enforce:**

| Event | Gate |
|---|---|
| `SessionStart` | Reads `state/pipeline_state.json`, injects current phase + artifact chain into context |
| `PreToolUse` (skill) | **Exits 2** if a phase is invoked out of order |
| `PreToolUse` (Write) | **Exits 2** if `references/client-context.md` hasn't been read |
| `PostToolUse` (skill) | Advances phase counter + records artifact in state file |
| `Stop` | Prints `[de-pipeline] Phase: X/7 | Completed: N | Next: $skill` every turn |

**Pipeline flow:**

```
$de-profile          →  profile_report.md
    ↓  [Quality Gate 1: non-empty, PII & PK identified]

$de-schema-design    →  schema_design.md
    ↓  [Quality Gate 2: all columns mapped, NOT NULL constraints viable]

$de-schema-setup     →  schema_setup.sql  +  Snowflake objects deployed
    ↓  [⚠️ Mandatory Stop: user confirms DDL before execution]
    ↓  [Quality Gate 3: tables exist, masking policies applied, lineage tagged]

$de-transform-setup  →  transform_mappings.yml  +  dbt models  +  Dynamic Table DDL
    ↓  [Quality Gate 4: 100-row sample test, 0 null violations]

$de-load-validate    →  rows loaded  +  quarantine table  +  quality alert
    ↓  [⚠️ Mandatory Stop: user confirms target before INSERT]
    ↓  [Quality Gate 5: rows loaded > 0, rejection rate < 5%]

$de-transform        →  populated mart table  +  running Dynamic Table / Task
    ↓  [Quality Gate 6: row delta < 5%, no critical nulls, freshness OK]

$de-share            →  RBAC grants  +  governance_report.md
         [Quality Gate 7: PII masked for consumer role, governance documented]
```

---

## Standalone Skills

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

## Repository Structure

```
snowflake-cortex-skill-forge/
├── AGENTS.md                              # Global conventions — loaded by CoCo on every session
├── README.md
├── CONTRIBUTING.md                        # Skill authoring guide & PR process
├── .gitignore
│
└── .cortex/
    │
    ├── plugins/                           # Hook-enforced multi-skill workflows
    │   └── de-pipeline-plugin/
    │       ├── .cortex-plugin/
    │       │   └── plugin.json            # Plugin manifest — lists 8 skills, hooks, references
    │       ├── hooks/
    │       │   ├── hooks.json             # 5 hook event wires
    │       │   └── pipeline-state.sh      # State machine (bash 3+, requires jq)
    │       ├── references/
    │       │   └── client-context.md      # Shared config for all 8 phase skills
    │       ├── skills/
    │       │   ├── de-workflow/SKILL.md
    │       │   ├── de-profile/SKILL.md
    │       │   ├── de-schema-design/SKILL.md
    │       │   ├── de-schema-setup/SKILL.md
    │       │   ├── de-transform-setup/SKILL.md
    │       │   ├── de-load-validate/SKILL.md
    │       │   ├── de-transform/SKILL.md
    │       │   └── de-share/SKILL.md
    │       └── state/
    │           └── pipeline_state.json    # Runtime state — gitignored
    │
    └── skills/                            # Standalone loose skills
        ├── snowflake-project-scaffolder/
        │   ├── SKILL.md
        │   └── references/               # 9 reference files (root files → dashboards)
        ├── snowflake-project-builder/
        │   ├── SKILL.md
        │   └── references/               # 8 reference files (planning → conventions)
        ├── dbt-expectations-generator/
        │   ├── SKILL.md
        │   └── references/               # test-selection-logic + test-reference
        ├── airflow-dag-generator/SKILL.md
        ├── dbt-jinja-builder/SKILL.md
        ├── dmf-generator/SKILL.md
        ├── great-expectations-suite-generator/SKILL.md
        └── informatica-to-dbt/SKILL.md
```

---

## Getting Started

### Prerequisites

- Snowflake account with Cortex Code CLI enabled
- Snowflake CLI installed: `pip install snowflake-cli`
- `jq` installed (required for the DE pipeline plugin hooks): `brew install jq`
- Access to a writable database (e.g. `SANDBOX.TPCH`)

### Installation

#### Option 1 — Global install (recommended)

Skills and plugins installed globally are available in every CoCo session, regardless of working directory.

```bash
git clone https://github.com/kannann-541912/snowflake-cortex-skill-forge.git
cd snowflake-cortex-skill-forge

# Install standalone skills globally
mkdir -p ~/.snowflake/cortex/skills
cp -r .cortex/skills/* ~/.snowflake/cortex/skills/

# Install the DE pipeline plugin globally
mkdir -p ~/.snowflake/cortex/plugins
cp -r .cortex/plugins/de-pipeline-plugin ~/.snowflake/cortex/plugins/

# Start a session from any directory
snow cortex run
```

#### Option 2 — Project-level install

CoCo auto-discovers skills in `.cortex/skills/` and plugins in `.cortex/plugins/` relative to the working directory. If you clone this repo and run CoCo from inside it, no extra steps are needed:

```bash
git clone https://github.com/kannann-541912/snowflake-cortex-skill-forge.git
cd snowflake-cortex-skill-forge
snow cortex run
```

#### Option 3 — Copy into an existing project

```bash
cp -r .cortex /path/to/your/snowflake-project/
cp AGENTS.md /path/to/your/snowflake-project/
```

### First-time DE Pipeline Setup

Before running the plugin for the first time, fill in your client context and initialise the state file:

```bash
# 1. Edit the shared client context
open .cortex/plugins/de-pipeline-plugin/references/client-context.md

# 2. Initialise the state machine
bash .cortex/plugins/de-pipeline-plugin/hooks/pipeline-state.sh init

# 3. Start CoCo and invoke the pipeline
snow cortex run
> $de-workflow Build a pipeline from SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.ORDERS into SANDBOX.TPCH
```

### Verifying Skills and Plugins Loaded

Inside a running CoCo session:

```
> /skill list
```

Expected output:
```
[P] Project  de-workflow                         DE pipeline orchestrator (plugin)
[P] Project  de-profile                          Phase 1 — source profiling (plugin)
[P] Project  de-schema-design                    Phase 2 — schema design (plugin)
[P] Project  de-schema-setup                     Phase 3 — DDL deployment (plugin)
[P] Project  de-transform-setup                  Phase 4 — transform mappings (plugin)
[P] Project  de-load-validate                    Phase 5 — load & validate (plugin)
[P] Project  de-transform                        Phase 6 — business transforms (plugin)
[P] Project  de-share                            Phase 7 — RBAC & governance (plugin)
[P] Project  snowflake-project-scaffolder        New project scaffold
[P] Project  snowflake-project-builder           Reverse-engineer live objects
[P] Project  airflow-dag-generator               Airflow DAG for dbt + Snowflake
[P] Project  dbt-expectations-generator          Auto-generate dbt tests from real data
[P] Project  dbt-jinja-builder                   dbt model + schema.yml + sources.yml
[P] Project  dmf-generator                       Snowflake Data Metric Functions
[P] Project  great-expectations-suite-generator  GX v1.x suite from live profiling
[P] Project  informatica-to-dbt                  Informatica XML → dbt project
```

### Invoking Skills

```
# Full end-to-end pipeline (hook-governed)
> $de-workflow Build a pipeline from SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.ORDERS into SANDBOX.TPCH

# Partial run — start from a specific phase
> $de-workflow start-from schema-setup

# Resume after a context reset
> $de-workflow resume

# Run individual phases
> $de-profile Profile SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.LINEITEM
> $de-transform-setup Build transforms for ORDERS → SANDBOX.TPCH.STG_ORDERS

# Standalone skills
> $snowflake-project-scaffolder Create a new project with DataOps and AgentOps pillars
> $dbt-expectations-generator Generate tests for SANDBOX.TPCH.MART_ORDERS_ENRICHED
```

### State Machine Commands

The DE pipeline plugin ships with a CLI for managing pipeline state:

```bash
cd .cortex/plugins/de-pipeline-plugin

bash hooks/pipeline-state.sh status          # Show current phase and progress
bash hooks/pipeline-state.sh resume          # Inject state into a new session
bash hooks/pipeline-state.sh mark-refs-read  # Unblock the Write gate after reading context
bash hooks/pipeline-state.sh reset           # Reset to Phase 0 (new pipeline run)
```

### Keeping Skills Up to Date

```bash
cd snowflake-cortex-skill-forge
git pull
cp -r .cortex/skills/* ~/.snowflake/cortex/skills/
cp -r .cortex/plugins/de-pipeline-plugin ~/.snowflake/cortex/plugins/
```

---

## AGENTS.md — Global Conventions

`AGENTS.md` is loaded by CoCo at the start of every session in this project. All skills and plugins inherit these conventions without having to re-declare them.

| Section | What It Covers |
|---|---|
| **Identity and Role** | Agent persona — Snowflake DE SME, not a generic SQL generator |
| **Environment** | Source DB (`SNOWFLAKE_SAMPLE_DATA.TPCH_SF10`, read-only), target DB (`SANDBOX.TPCH`), warehouse |
| **TPCH Source Catalogue** | All 8 tables with PKs, FKs, row counts, and sampling guidance |
| **Naming Conventions** | `UPPER_SNAKE_CASE` objects, `STG_*`/`MART_*`/`MASK_*`/`RAP_*` prefixes |
| **Standard Audit Columns** | `_LOADED_AT`, `_SOURCE_SYSTEM`, SCD2 columns — added to every table |
| **Quality Thresholds** | Quarantine rate, row delta, null rate, freshness thresholds with STOP/WARN actions |
| **DDL Rules** | `CREATE IF NOT EXISTS` only, governance-at-creation, clustering key guidance |
| **RBAC Role Hierarchy** | `DE_CONSUMER_ROLE`, `DE_ANALYST_ROLE`, `DE_ENGINEER_ROLE` with grant rules |
| **Artifact Chain** | The file sequence connecting all 7 DE phases |
| **TPCH Gotchas** | Static streams, FLOAT prices, composite PKs |

**Adapting for your environment:** Change the source/target databases, adjust naming conventions, update quality thresholds to match your SLAs, and replace the TPCH catalogue with your own source schema.

---

## Design Principles

**Plugins over loose skills for complex workflows.** When 4+ skills share phase ordering, artifact dependencies, or reference documents, a plugin with hook enforcement beats markdown instructions every time. Instructions are requests. Hooks are constraints.

**Composability over monoliths.** Each skill is a standalone unit producing a documented artifact. Skills are chained by the orchestrator but always runnable independently.

**Progressive disclosure.** Large skills use a concise `SKILL.md` (≤ 200 lines) as the entrypoint and load heavy content from `references/` files on demand — keeping the context window lean.

**Quality gates between every phase.** Skills don't silently proceed on failure. Every phase checks its own output before advancing, reports what went wrong, and offers recovery options.

**Mandatory stopping points for irreversible actions.** DDL execution and bulk INSERTs require explicit human confirmation — even if the user approved the plan earlier in the session.

**Governance by default.** Masking policies, lineage tags, and RBAC roles are applied at object creation — never as an afterthought.

**Idempotent DDL.** All generated SQL uses `CREATE ... IF NOT EXISTS`. Running a skill twice on the same environment is always safe.

**Artifact-driven context.** Skills communicate through files (`profile_report.md`, `schema_design.md`, `transform_mappings.yml`) so context survives session resets and can be version-controlled.

---

## Roadmap

- [ ] `$de-lineage` — cross-system lineage spanning Snowflake, dbt, and Airflow DAGs
- [ ] `$de-cost` — cost optimisation agent: clustering keys, idle warehouses, expensive queries
- [ ] `$de-contract` — auto-generate dbt model contracts and YAML schemas from profile data
- [ ] `$de-anomaly` — anomaly detection rules builder outputting Snowflake alerts and Soda checks
- [ ] `$de-incident` — on pipeline failure, gather errors from Snowflake, Airflow, dbt, and Git, then propose a root cause hypothesis
- [ ] `snowflake-project-plugin` — wrap project-builder + project-scaffolder with shared reference deduplication
- [ ] `data-quality-plugin` — bundle dbt-expectations + great-expectations with unified trigger set

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full skill authoring guide, required sections checklist, and PR process.

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

*Built for teams who believe that infrastructure setup should take hours, not weeks — and that your AI assistant should know the difference between a staging table and a mart.*
