---
name: de-workflow
description: "Composable end-to-end AI-accelerated data engineering workflow: runs all 7 phases in sequence (Profile → Schema Design → Schema Setup → Transform Setup → Load & Validate → Transform → Share) with quality gates between each phase"
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Read
  - Write
  - Bash
---

# When to Use
- User wants to build a complete Snowflake data pipeline from scratch in one command
- User says "run the full pipeline", "end-to-end workflow", "set up everything", "build the pipeline"
- Onboarding a new data source into Snowflake from raw to governed mart

# What This Skill Provides
The composable orchestrator that chains all 7 DE workflow skills into a single guided session.
Each phase produces artifacts consumed by the next. Quality gates prevent advancing on failure.
Reduces 2–8 weeks of manual work to 1–4 hours of AI-co-created pipeline setup.

# Instructions

## Workflow Overview

```
$de-profile → $de-schema-design → $de-schema-setup
    → $de-transform-setup → $de-load-validate
        → $de-transform → $de-share
```

Each phase produces an artifact. Each artifact is the input to the next phase.
A quality gate check runs between each phase.

---

# Safety
- Source database `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10` is strictly read-only.
- Before executing any phase, confirm all write targets resolve to `SANDBOX.TPCH` (or user-confirmed DB).
- If any generated statement targets `SNOWFLAKE_SAMPLE_DATA`, abort the phase immediately and report.

## Phase 0 — Gather inputs
Before starting, collect or confirm the following:

```
Source database:  SNOWFLAKE_SAMPLE_DATA.TPCH_SF10 (read-only — confirmed)
Source tables:    Which table(s) to pipeline?
                  Options: ORDERS, LINEITEM, CUSTOMER, SUPPLIER, PART, PARTSUPP, NATION, REGION
                  Suggested starting point: ORDERS + LINEITEM (the two primary fact tables)

Target database:  SANDBOX.TPCH (confirm — user may have a different sandbox DB)

Build mode:       [1] Staging only (STG_* tables, 1:1 source mirror)
                  [2] Staging + Mart (STG_* + MART_ORDERS_ENRICHED denormalised model)
                  [3] Full stack (Staging + Mart + dbt models + Dynamic Tables)

Consumer persona: consumer / analyst / engineer
Cross-account share?  yes / no
```

---

## Phase 1 — Profile
**Invoke:** `$de-profile`
**Input:** Source table or stage
**Output:** `profile_report.md`

Run the full profile skill. On completion, check:
```
QUALITY GATE 1:
✅ profile_report.md exists
✅ All columns profiled (null rates, cardinality, types)
✅ PII candidates identified
✅ Recommended primary key identified
❌ STOP if: profile reveals 0 rows (empty source)
```

---

## Phase 2 — Schema Design
**Invoke:** `$de-schema-design`
**Input:** `profile_report.md`
**Output:** `schema_design.md`

Run the full schema design skill. On completion, check:
```
QUALITY GATE 2:
✅ schema_design.md exists
✅ All source columns have a target mapping
✅ Primary key columns identified
✅ PII masking policy plan documented
✅ Audit columns (_LOADED_AT, _SOURCE_SYSTEM) included
❌ STOP if: any NOT NULL target column has null rate > 50% in source
   → Prompt user: "Column X has {pct}% nulls in source but is mapped as NOT NULL.
     Fix source data or change constraint?"
```

---

## Phase 3 — Schema Setup
**Invoke:** `$de-schema-setup`
**Input:** `schema_design.md`
**Output:** `schema_setup.sql` + deployed Snowflake objects

Run the full schema setup skill. On completion, verify:
```
QUALITY GATE 3:
✅ schema_setup.sql written and saved
✅ All target tables exist in Snowflake (SHOW TABLES confirms)
✅ All masking policies created and applied (POLICY_REFERENCES confirms)
✅ SOURCE_LINEAGE tag applied to all tables
❌ STOP if: any DDL statement failed — report error + affected object
```

```sql
-- Auto-verification query
SELECT table_name, table_type
FROM {database}.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = '{schema}'
  AND TABLE_NAME IN ({target_table_list});
```

---

## Phase 4 — Transform Setup
**Invoke:** `$de-transform-setup`
**Input:** `schema_design.md` + deployed tables
**Output:** `transform_mappings.yml` + dbt model stubs + Dynamic Table DDL

Run the full transform setup skill. On completion, check:
```
QUALITY GATE 4:
✅ transform_mappings.yml exists — all columns mapped
✅ Sample transform test: 100 rows processed with 0 null violations on NOT NULL cols
✅ dbt staging model generated (if dbt project present)
✅ Dynamic Table DDL or Stream+Task DDL generated
❌ STOP if: sample test produces > 5% null rate on any NOT NULL target column
   → Report column name + sample failing values
```

---

## Phase 5 — Load & Validate
**Invoke:** `$de-load-validate`
**Input:** `transform_mappings.yml` + source TPCH tables + target SANDBOX.TPCH tables
**Output:** Rows inserted into staging tables + quarantine table + alert

Run the full load-validate skill. For TPCH, this uses INSERT INTO ... SELECT (not COPY INTO).
On completion, check:
```
QUALITY GATE 5:
✅ Rows loaded > 0 (ORDERS ~15M, LINEITEM ~60M, etc.)
✅ Row count matches source: SELECT COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.{table}
✅ No null violations on PK columns (O_ORDERKEY, L_ORDERKEY + L_LINENUMBER, etc.)
✅ Quality alert created and in STARTED state
❌ STOP if: loaded row count differs from source by > 1%
```

---

## Phase 6 — Transform
**Invoke:** `$de-transform`
**Input:** Loaded staging data + `transform_mappings.yml`
**Output:** Populated target mart table + running task/dynamic table

Run the full transform skill. On completion, check:
```
QUALITY GATE 6:
✅ Target table row count > 0
✅ Row delta between source and target < 5%
✅ No critical nulls in output (order_id, order_date, etc.)
✅ Freshness: _LOADED_AT within last 30 minutes
✅ Dynamic Table or Task is RUNNING/scheduled
❌ STOP if: critical nulls found in output
   → Report null count per column, show sample offending rows
```

---

## Phase 7 — Share
**Invoke:** `$de-share`
**Input:** Deployed mart table + consumer personas from Phase 0
**Output:** RBAC grants + `governance_report.md`

Run the full share skill. On completion, check:
```
QUALITY GATE 7:
✅ DE_CONSUMER_ROLE created and granted SELECT
✅ All PII columns have active masking policies
✅ governance_report.md written
✅ Data share created (if cross-account was requested)
❌ STOP if: masking policy verification shows any PII column is unmasked for CONSUMER role
```

---

## Final — Pipeline Summary
After all 7 phases complete, generate `pipeline_summary.md`:

```markdown
# Pipeline Summary
**Source:** {source}
**Target:** {target_db}.{target_schema}.{target_table}
**Completed at:** {timestamp}
**Duration:** {elapsed}

## What Was Built
| Phase | Status | Output Artifact |
|-------|--------|-----------------|
| 1. Profile | ✅ DONE | profile_report.md |
| 2. Schema Design | ✅ DONE | schema_design.md |
| 3. Schema Setup | ✅ DONE | schema_setup.sql |
| 4. Transform Setup | ✅ DONE | transform_mappings.yml |
| 5. Load & Validate | ✅ DONE | {n} rows loaded, {n} quarantined |
| 6. Transform | ✅ DONE | Dynamic Table / Task running |
| 7. Share | ✅ DONE | governance_report.md |

## Snowflake Objects Created
- Tables: {list}
- Masking Policies: {list}
- Row Access Policies: {list}
- Tasks/Dynamic Tables: {list}
- Alerts: {list}
- Shares: {list}

## Running Pipeline
- Refresh cadence: {lag / schedule}
- Quality alert: {alert_name} — notifies {email} on quarantine breach
- Governed by: DE_CONSUMER_ROLE / DE_ANALYST_ROLE / DE_ENGINEER_ROLE

## Ongoing Operations
- Re-profile after 30 days to detect schema drift: `$de-profile`
- Add new source columns: update schema_design.md, re-run `$de-schema-setup` + `$de-transform-setup`
- Grant access to a new user: `GRANT ROLE DE_CONSUMER_ROLE TO USER {username};`
```

---

## Partial Workflow Usage
The workflow can also be invoked from any phase:
- `$de-workflow start-from schema-setup` — skip profile + design, start at DDL
- `$de-workflow run-phase transform` — run only Phase 6
- `$de-workflow resume` — resume from last completed phase (reads pipeline_summary.md)

## Error Recovery
If any phase fails:
1. Report: which phase failed, what the error was, which objects were partially created
2. Do NOT auto-proceed — always stop and present the error
3. Offer: "Retry this phase", "Skip and continue", or "Abort and rollback"
4. On rollback: drop objects created in the failed phase only (use schema_setup.sql as rollback reference)

## Best Practices
- Run `$de-workflow` in a dedicated CoCo CLI session — each phase adds context to the conversation
- Commit generated artifacts (profile_report.md, schema_design.md, schema_setup.sql,
  transform_mappings.yml) to Git after each phase
- Quality gates are strict by default — override thresholds only with explicit user approval

# Examples

## Example 1: Full end-to-end
User: `$de-workflow Build a pipeline from RAW.LANDING.ORDERS into ANALYTICS.MART`
Assistant: Runs all 7 phases in sequence, pauses at each quality gate, asks for confirmation
on a 30% quarantine rate in Phase 5 (user confirms known bad data), completes all phases,
generates pipeline_summary.md.

## Example 2: Partial run
User: `$de-workflow run-phase transform`
Assistant: Reads transform_mappings.yml, runs $de-transform skill directly, runs quality gate 6.

## Example 3: Resume after failure
User: `$de-workflow resume`
Assistant: Reads pipeline_summary.md, sees Phase 4 completed and Phase 5 failed, resumes
from Phase 5 ($de-load-validate).
