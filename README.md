# Intelligent Infrastructure for Snowflake

> Custom skills for Snowflake Cortex Code CLI — turning your AI assistant into a context-aware data engineering operating system.

---

## What This Is

This repository contains a curated set of custom skills for the [Snowflake Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code). Each skill is a structured prompt file (`SKILL.md`) that teaches CoCo how to perform a specific data engineering task with Snowflake-native patterns, production conventions, and built-in quality gates.

Skills are composable. They produce artifacts (SQL files, YAML mappings, Markdown reports) that feed into each other, allowing you to chain a complete data pipeline from a single conversation — or invoke individual phases on demand.

The driving idea is simple: **your infrastructure shouldn't require a ticket, a whiteboard session, or a week of script writing**. With the right skills loaded, CoCo becomes the context-aware development fabric your data team already needed.

---

## Skills in This Repository

### AI-Accelerated Data Engineering Workflow

A phase-by-phase pipeline that takes a raw source from profile to governed mart — in hours, not weeks.

| Skill | Invoke | What It Does |
|---|---|---|
| **de-workflow** | `$de-workflow` | Composable end-to-end orchestrator. Chains all 7 phases with quality gates. Supports full run, partial run, and resume. |
| **de-profile** | `$de-profile` | Auto-profiles every column of a source table — null rates, cardinality, distributions, PII candidates, recommended primary keys. |
| **de-schema-design** | `$de-schema-design` | Proposes a target schema from the profile: type mappings, SCD patterns, normalization, PII masking plan. |
| **de-schema-setup** | `$de-schema-setup` | Generates and deploys idempotent DDL — tables, file formats, stages, masking policies, lineage tags. Governance by default. |
| **de-transform-setup** | `$de-transform-setup` | Builds reusable column transform mappings, dbt staging model stubs, and Dynamic Table DDL from source-to-target mappings. |
| **de-load-validate** | `$de-load-validate` | Loads data with a quarantine pattern, row-count reconciliation, null assertions, and a Snowflake alert on every load. |
| **de-transform** | `$de-transform` | Applies business transforms via Dynamic Tables or Stream+Task MERGE. Self-healing: detects failures, resumes, runs post-transform assertions. |
| **de-share** | `$de-share` | Configures role-based access and sharing by default: functional RBAC roles, least-privilege grants, Row Access Policies, and optional cross-account data shares. |

---

## The End-to-End Workflow

```
$de-profile          →  profile_report.md
    ↓  [Quality Gate 1: non-empty, PII & PK identified]

$de-schema-design    →  schema_design.md
    ↓  [Quality Gate 2: all columns mapped, NOT NULL constraints viable]

$de-schema-setup     →  schema_setup.sql  +  Snowflake objects deployed
    ↓  [Quality Gate 3: tables exist, masking policies applied, lineage tagged]

$de-transform-setup  →  transform_mappings.yml  +  dbt models  +  Dynamic Table DDL
    ↓  [Quality Gate 4: 100-row sample test passes, 0 null violations]

$de-load-validate    →  rows loaded  +  quarantine table  +  quality alert
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

Or run any phase standalone:

```
> $de-profile Profile SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.LINEITEM
> $de-transform-setup Build transforms for ORDERS → SANDBOX.TPCH.STG_ORDERS
> $de-workflow resume
```

---

## Repository Structure

```
.
├── AGENTS.md                              # Project-wide conventions loaded by CoCo on every session
└── .cortex/
    └── skills/
        ├── 00-de-workflow/
        │   └── SKILL.md                   # Composable end-to-end orchestrator
        ├── 01-profile/
        │   └── SKILL.md                   # Phase 1 — Profile
        ├── 02-schema-design/
        │   └── SKILL.md                   # Phase 2 — Schema Design
        ├── 03-schema-setup/
        │   └── SKILL.md                   # Phase 3 — Schema Setup
        ├── 04-transform-setup/
        │   └── SKILL.md                   # Phase 4 — Transform Setup
        ├── 05-load-validate/
        │   └── SKILL.md                   # Phase 5 — Load & Validate
        ├── 06-transform/
        │   └── SKILL.md                   # Phase 6 — Transform
        └── 07-share/
            └── SKILL.md                   # Phase 7 — Share
```

`AGENTS.md` carries global conventions — naming standards, warehouse defaults, quality thresholds, audit column rules — so you don't repeat them in every skill.

---

## Getting Started

### Prerequisites

- Snowflake account with Cortex Code CLI enabled
- CoCo CLI installed: `pip install snowflake-cli`
- Access to a writable database (e.g. `SANDBOX.TPCH`)

### Installation

**Project-level** (skills available in this project only):

```bash
git clone https://github.com/your-org/intelligent-infrastructure-for-snowflake
cd intelligent-infrastructure-for-snowflake

# Copy skills into your Snowflake project
cp -r .cortex /path/to/your/snowflake-project/
cp AGENTS.md /path/to/your/snowflake-project/
```

**Global** (skills available in every CoCo session):

```bash
cp -r .cortex/skills/* ~/.snowflake/cortex/skills/
```

### Verify

Open CoCo CLI in your project directory and run:

```
> /skill list
```

You should see all skills listed as `[G] Global` or `[P] Project`. Skills are ready to invoke.

---

## AGENTS.md — Global Conventions

The `AGENTS.md` file is the backbone of consistent skill behaviour. It defines:

- **Source database**: `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10` (read-only) — skills will never write to it
- **Target database**: `SANDBOX.TPCH` — all DDL and DML targets here
- **Source table catalogue**: All 8 TPCH tables with primary keys and approximate row counts, used by profile and transform skills to make smart sampling decisions
- **Naming conventions**: `STG_*` for staging, `MART_*` for mart models, fully-qualified `DB.SCHEMA.TABLE` everywhere
- **Audit columns**: `_LOADED_AT` and `_SOURCE_SYSTEM` added to every table automatically
- **Quality gates**: Thresholds for quarantine rates, row deltas, null rates, and freshness SLAs
- **Safety rule**: Any statement targeting `SNOWFLAKE_SAMPLE_DATA` is aborted immediately

Adapt `AGENTS.md` to your own environment — change the source/target databases, add your own naming conventions, and adjust quality thresholds to match your SLAs.

---

## Design Principles

**Composability over monoliths.** Each skill is a standalone unit that produces a documented artifact. Skills are chained by the orchestrator but can always be run independently.

**Quality gates between every phase.** Skills don't silently proceed on failure. Every phase checks its own output before advancing, reports what went wrong, and offers recovery options.

**Governance by default.** Masking policies, lineage tags, and RBAC roles are applied at object creation — not as an afterthought.

**Idempotent DDL.** All generated SQL uses `CREATE ... IF NOT EXISTS` patterns. Running a skill twice on the same environment is safe.

**Artifact-driven context.** Skills communicate through files (`profile_report.md`, `schema_design.md`, `transform_mappings.yml`, etc.) so that context survives session boundaries and can be version-controlled.

---

## Extending This Repository

Skills are plain Markdown files with a YAML front matter block. To add your own:

```markdown
---
name: my-skill-name
description: "One sentence describing when CoCo should invoke this skill."
tools:
  - snowflake_sql_execute
  - Read
  - Write
---

# Instructions
...your skill content...
```

Drop the folder into `.cortex/skills/my-skill-name/SKILL.md` and run `/skill list` to verify it's picked up.

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
3. Add or edit your `SKILL.md` following the conventions in `AGENTS.md`
4. Test it in a live CoCo session — show the `/skill list` output and at least one example invocation in your PR
5. Open a pull request with a description of what the skill does, what phase it targets, and what artifacts it produces

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

*Built for teams who believe that infrastructure setup should take hours, not weeks — and that your AI assistant should know the difference between a staging table and a mart.*
