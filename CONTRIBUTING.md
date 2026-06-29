# Contributing to Snowflake Cortex Code Skill Forge

This guide covers everything you need to build a production-grade skill or plugin for this repository — or for your own CoCo project.

---

## Building a New Skill

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

## Phase 1 — [Phase Name]

⚠️ **MANDATORY STOPPING POINT** — [only for irreversible actions]
[Enumerate what must be confirmed before proceeding]

[Phase instructions...]

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

## Building a Plugin (Skill + Hooks)

When to build a plugin instead of a loose skill (from the article ["Why Snowflake Cortex Code Plugins Beat Loose Skills"](https://medium.com/snowflake/why-snowflake-cortex-code-plugins-beat-loose-skills-for-complex-ai-workflows-59caaea56360)):

| Situation | Approach |
|---|---|
| Single-purpose task | Loose SKILL.md |
| 2–3 related skills, no ordering | Either works |
| 4+ skills with phase dependencies | **Plugin** |
| Shared reference docs across skills | **Plugin** |
| Agent routinely skips required steps | **Plugin + hooks** |
| Distributed to a team | **Plugin** |

### Plugin Folder Structure

```
my-plugin/
├── .cortex-plugin/
│   └── plugin.json          ← manifest: lists skills, hooks path, references path
├── hooks/
│   ├── hooks.json           ← hook event wires
│   └── lifecycle.sh         ← state machine implementation (requires jq)
├── references/
│   └── client-context.md    ← shared config — replaces per-skill duplicates
├── skills/
│   ├── phase-one/SKILL.md
│   └── phase-two/SKILL.md
└── state/
    └── pipeline_state.json  ← runtime state, gitignored
```

### Hook Events

| Event | Exit code | Effect |
|---|---|---|
| `SessionStart` | — | Inject state into the new session |
| `PreToolUse` | `0` = allow, `2` = block | Gate phase ordering and context reading |
| `PostToolUse` | — | Advance state, record artifacts |
| `Stop` | — | Emit a status line at turn end |

### Reference Paths in Plugin Skills

Skills inside a plugin reference the shared `references/` folder using a relative path up to the plugin root:

```markdown
Read `../../references/client-context.md` at the start of every invocation.
```

---

## Pull Request Process

To add a new skill or improve an existing one:

1. Fork the repository
2. Create a branch: `git checkout -b skill/your-skill-name`
3. Build your skill following the guide above
4. Run the required sections checklist before opening a PR
5. Test the skill in a live CoCo session — include the `/skill list` output and at least one example invocation in your PR description
6. Open a pull request with: what the skill does, which phase/category it belongs to, what artifacts it produces, and the trigger phrases in the description field

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
