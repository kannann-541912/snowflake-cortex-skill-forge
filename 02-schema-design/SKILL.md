---
name: de-schema-design
description: "Phase 2 — Propose target schema from source profile: map source columns to target types, recommend normalization, suggest SCD patterns, and produce a schema design document"
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Read
  - Write
---

# Safety
- Source is `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10` — read-only. Target must be `SANDBOX.TPCH`.
- Never generate DDL targeting `SNOWFLAKE_SAMPLE_DATA`.

# Known TPCH Source Schema
Use this as ground truth when reading profile_report.md — these are the source PKs and FKs:

| Table    | PK                        | Key FKs                                      |
|----------|---------------------------|----------------------------------------------|
| ORDERS   | O_ORDERKEY                | O_CUSTKEY → CUSTOMER.C_CUSTKEY               |
| LINEITEM | L_ORDERKEY + L_LINENUMBER | L_ORDERKEY → ORDERS, L_PARTKEY → PART, L_SUPPKEY → SUPPLIER |
| CUSTOMER | C_CUSTKEY                 | C_NATIONKEY → NATION.N_NATIONKEY             |
| SUPPLIER | S_SUPPKEY                 | S_NATIONKEY → NATION.N_NATIONKEY             |
| PART     | P_PARTKEY                 | —                                            |
| PARTSUPP | PS_PARTKEY + PS_SUPPKEY   | PS_PARTKEY → PART, PS_SUPPKEY → SUPPLIER     |
| NATION   | N_NATIONKEY               | N_REGIONKEY → REGION.R_REGIONKEY             |
| REGION   | R_REGIONKEY               | —                                            |

Recommended target layer architecture for TPCH:
- **Staging** (`SANDBOX.TPCH.STG_*`): 1:1 mirror of source with audit columns + type casts
- **Mart** (`SANDBOX.TPCH.MART_*`): denormalised fact/dimension models (e.g. MART_ORDERS_ENRICHED)

# When to Use
- User has completed `$de-profile` and has a `profile_report.md`
- User says "design a schema for this data", "propose target tables", "map my source columns"
- Converting raw/landing data into a structured target schema

# What This Skill Provides
Replaces 1–2 week whiteboard sessions and manual schema design cycles. Reads the profile
report and produces a complete, opinionated target schema with type mappings, constraints,
SCD recommendations, and a visual column-mapping table.

# Instructions

## Step 1 — Read the profile report
Use `Read` to load `profile_report.md`. If it doesn't exist, instruct user to run `$de-profile` first.

Extract:
- Source table/stage name
- All columns with types, null rates, cardinality, PII flags
- Recommended primary key from the profile

## Step 2 — Map source types to Snowflake target types
Apply these mapping rules:

| Source Pattern | Recommended Snowflake Type | Notes |
|---|---|---|
| Integer, numeric ID < 10 digits | NUMBER(38,0) | Use for PKs and FKs |
| Float/double | FLOAT | |
| Decimal with scale | NUMBER(precision, scale) | Preserve source precision |
| Short string < 50 chars | VARCHAR(256) | Give headroom |
| Long text, JSON blobs | VARIANT | Or VARCHAR(16777216) |
| Date only | DATE | |
| Datetime/timestamp | TIMESTAMP_LTZ | Always timezone-aware |
| Boolean (0/1, Y/N, true/false) | BOOLEAN | |
| Constant column (cardinality=1) | VARCHAR(50) | Consider dropping or defaulting |
| PII-flagged string | VARCHAR(256) — add masking policy | |

## Step 3 — Recommend table architecture
Based on row count and cardinality patterns, recommend:

- **Fact table**: high row count, foreign keys, numeric measures, append-heavy
- **Dimension table**: lower row count, descriptive attributes, SCD Type 2 if history needed
- **Staging table**: 1:1 mirror of source for raw landing
- **Bridge/junction**: many-to-many relationships

If dimension table with history needed, apply SCD Type 2 pattern:
```sql
-- SCD Type 2 standard columns to add:
_EFF_START_DATE    TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
_EFF_END_DATE      TIMESTAMP_LTZ,
_IS_CURRENT        BOOLEAN NOT NULL DEFAULT TRUE,
_SOURCE_SYSTEM     VARCHAR(50)
```

## Step 4 — Produce schema design document
Write `schema_design.md`:

```markdown
# Schema Design
**Source:** {source_table}
**Target DB/Schema:** {target_db}.{target_schema}
**Designed at:** {timestamp}

## Target Tables

### {TARGET_TABLE_NAME} ({fact|dimension|staging})
**Description:** ...
**Estimated row growth:** ...

| Source Column | Source Type | Target Column | Target Type | Constraints | Notes |
|---|---|---|---|---|---|
| ORDER_ID | INTEGER | ORDER_ID | NUMBER(38,0) | PRIMARY KEY | Unique ID |
| CUSTOMER_EMAIL | VARCHAR | CUSTOMER_EMAIL | VARCHAR(256) | NOT NULL | PII — mask |
| ... | | | | | |

**Standard audit columns added:**
- `_LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()`
- `_SOURCE_SYSTEM VARCHAR(50) DEFAULT 'source_name'`

## Relationships
Describe FK relationships between tables.

## SCD Strategy
- {table}: Type {0|1|2} — reason

## PII Masking Policy Plan
| Column | Policy Type | Visible To |
|---|---|---|
| CUSTOMER_EMAIL | SHA2 hash | DATA_ENGINEER role |
| SSN | NULL mask | No role |

## Next Step
Run `$de-schema-setup` to generate and deploy DDL.
```

## Best Practices
- Always add audit columns — never skip `_LOADED_AT`
- Prefer `TIMESTAMP_LTZ` over `TIMESTAMP_NTZ` for operational data
- Cluster key recommendation: high-cardinality columns used in WHERE filters on large tables
- Keep staging tables as 1:1 source mirrors — transform in separate layer

## Common Patterns

### Pattern 1: Simple fact table
Source has order_id, amounts, dates → propose ORDERS fact table with numeric PKs, TIMESTAMP_LTZ dates, FLOAT amounts

### Pattern 2: SCD Dimension
Source has customer records with slow-changing attributes → propose SCD Type 2 with _EFF_START_DATE/_EFF_END_DATE

# Examples

## Example 1: TPCH ORDERS + LINEITEM
User: `$de-schema-design Design target schema for ORDERS and LINEITEM`
Assistant: Reads profile_report.md, maps ORDERS (9 cols) to SANDBOX.TPCH.STG_ORDERS with
O_TOTALPRICE as NUMBER(15,2), O_ORDERDATE as DATE, audit columns added. Maps LINEITEM
(16 cols) to STG_LINEITEM with composite PK, L_*PRICE and L_*PERCENT as NUMBER(15,2),
three date columns as DATE. Recommends MART_ORDERS_ENRICHED as denormalised join of
ORDERS + LINEITEM + CUSTOMER. No PII detected in TPCH. Writes schema_design.md.

