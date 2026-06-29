---
name: informatica-to-dbt
description: >
  Migrate an Informatica PowerCenter or IDMC mapping to a full dbt project
  targeting Snowflake. Parses an XML export, summarises the transformation
  logic, produces a migration assessment, and scaffolds staging + intermediate
  + mart (CDC MERGE) dbt layers. Use when: migrate informatica to dbt,
  convert informatica mapping, parse informatica xml, informatica to snowflake,
  idmc to dbt, powermart migration, dbt scaffold from informatica.
---

# Client Context
Read `references/client-context.md` at the start of every invocation. Apply any values it
defines as overrides: migration scope, Snowflake target schema names, dbt project settings,
CDC key and hash column conventions, transformation mapping patterns (lookup strategy,
sequence generator, router pattern), and assessment report format. If the file is absent or
a value is unset (`~`), use the built-in defaults. Never fail if the file is missing.

# Informatica → dbt Migration

End-to-end skill: XML parse → assessment → dbt scaffold (staging / intermediate / mart).

## Domain Context
You are an ETL migration specialist who converts Informatica PowerCenter/IDMC mappings to
idiomatic dbt + Snowflake pipelines. You parse XML exports, summarize transformation logic,
produce a migration assessment, and scaffold production-ready dbt model layers.

## When to Use
- User has an Informatica XML export and wants to migrate to dbt on Snowflake
- "migrate Informatica to dbt", "convert this mapping", "parse informatica xml", "IDMC to dbt"
- User wants a migration assessment before committing to a full migration

## When NOT to Use
- User has no Informatica XML — they want a dbt model from scratch → use `dbt-jinja-builder`
- User wants to migrate a different ETL tool (Talend, SSIS, etc.) → handle directly, this skill is Informatica-specific
- User only wants to understand the Informatica mapping (no dbt output needed) → parse the XML and summarize only

## Gotchas
- Informatica XML exports can be large (>10MB) — if the file is very large, ask the user for a specific mapping by name rather than parsing the full export.
- Lookups in Informatica map to dbt `{{ ref() }}` joins — never inline them as subqueries.
- Sequence generators in Informatica have no direct dbt equivalent — generate a Snowflake SEQUENCE and document the limitation.
- Informatica `UPDATE STRATEGY` transformations (INSERT/UPDATE/DELETE) map to dbt `incremental` with `merge` strategy and `unique_key`.
- The generated dbt project must have `dbt_project.yml` with the correct `name` (underscores, not hyphens).

## Parameters

| Parameter | Description | Default |
|---|---|---|
| `<XML_PATH>` | Absolute path to the Informatica XML export | — |
| `<PROJECT_DIR>` | Directory to create the dbt project in | current directory |
| `<PROJECT_NAME>` | dbt project name (snake_case) | — |
| `<RAW_DB>` | Snowflake raw database placeholder | `YOUR_RAW_DATABASE` |
| `<TARGET_TABLE>` | Snowflake target table for the mart MERGE | — |
| `<LAST_RUN_VAR>` | dbt variable name for incremental filtering | `last_run_dt` |

---

## Step 0 — Load client context
Read `references/client-context.md`. If present, apply:
- `snowflake.*` → raw database name, staging/intermediate/mart schema names
- `dbt.*` → project path, name, materializations, last_run_var name
- `cdc.*` → unique key column, hash column, active indicator, soft-delete convention
- `transformation_mapping.*` → lookup pattern, sequence generator, router pattern
- Pre-fill Step 1 parameter collection from `source.xml_path`, `dbt.project_name`, etc.

## Step 1: Collect Parameters

**Ask** the user:

```
To scaffold the dbt project I need:

1. Path to the Informatica XML export file
2. Target directory for the dbt project (or use current directory)
3. dbt project name (snake_case, e.g. prov_alt_id)
4. Snowflake target table name (the mart MERGE destination)
5. Raw database name in Snowflake (or leave blank to use placeholder)

Please provide these details.
```

**⚠️ STOP**: Do not proceed until all required values are supplied.

---

## Step 2: Parse the XML and Summarise Transformation Logic

**Goal:** Understand the full mapping before writing any code.

The XML follows Informatica's PowerMart DTD. Use a Task subagent (subagent_type=Explore)
with the file path to read it in chunks if it is large (>200KB).

**Extract and summarise for each MAPPING block:**

1. **Sources**: SOURCE elements — name, database type, columns
2. **Targets**: TARGET elements — name, columns, update strategy
3. **Transformations**: For each TRANSFORMATION element record:
   - TYPE (Source Qualifier, Expression, Lookup, Joiner, Router,
     Aggregator, Filter, Update Strategy, etc.)
   - NAME
   - Key logic: ports, expressions, join conditions, filter conditions,
     group-by columns, routing groups
4. **Connector flow**: CONNECTOR elements — trace data flow from source to target
5. **Session parameters**: Look for `$$` prefixed variables (e.g. `$$LST_RUN_DT`)
   — these become `var('<LAST_RUN_VAR>')` in dbt

**Present a structured summary:**

```
## Mapping: <name>
### Sources
- <source_name> (<db_type>): <key_columns>

### Targets
- <target_name>: <update_strategy>

### Transformation Chain
1. SQ_<name> — Source Qualifier: <filter/join logic>
2. EXP_<name> — Expression: <key derived columns>
3. LKP_<name> — Lookup: <lookup table>, join on <col>
...

### Key Business Logic
- <concise description of what the mapping does>

### Session Parameters → dbt vars
- $$LST_RUN_DT → var('<LAST_RUN_VAR>')
```

**⚠️ STOP**: Present summary to user and confirm accuracy before proceeding.

---

## Step 3: Migration Assessment

Map each Informatica transformation type to its Snowflake / dbt equivalent:

| Informatica | dbt / Snowflake pattern |
|---|---|
| Source Qualifier (filter/join) | CTE with WHERE clause; or JOIN in staging model |
| Expression transformer | CTE with computed columns |
| Lookup (connected) | LEFT JOIN in CTE |
| Lookup (unconnected) | Scalar subquery or LEFT JOIN |
| Joiner | JOIN (INNER / FULL OUTER based on join type) |
| Router | Separate models or WHERE filters per branch |
| Aggregator | GROUP BY with MIN / MAX / COUNT / SUM |
| Filter | WHERE clause |
| Update Strategy | dbt incremental + `is_incremental()` block + `post_hook` for deletes |
| Sorter | ORDER BY (only in final SELECT if required) |
| `$$SESSION_PARAM` | `{{ var('<LAST_RUN_VAR>') }}` |
| Sequence Generator | `ROW_NUMBER()` or Snowflake sequence |

Produce a **component-by-component assessment** highlighting:
- Direct translations (low risk)
- Transformations needing logic rewrite (medium risk)
- CDC / Update Strategy patterns (high complexity — use mart MERGE model)
- Any Informatica-specific functions needing Snowflake equivalents

---

## Step 4: Scaffold dbt Project Structure

Create the following layout under `<PROJECT_DIR>/<PROJECT_NAME>/`:

```
<PROJECT_NAME>/
├── dbt_project.yml
├── packages.yml
└── models/
    ├── staging/
    │   ├── _sources.yml
    │   └── _schema.yml
    ├── intermediate/
    │   └── _schema.yml
    └── mart/
        └── _schema.yml
```

**`dbt_project.yml`** — set materializations:
```yaml
name: '<PROJECT_NAME>'
version: '1.0.0'
config-version: 2
profile: '<PROJECT_NAME>'
model-paths: ["models"]
vars:
  <LAST_RUN_VAR>: '1900-01-01'
models:
  <PROJECT_NAME>:
    staging:
      +materialized: view
      +schema: staging
    intermediate:
      +materialized: table
      +schema: intermediate
    mart:
      +schema: mart
```

**`packages.yml`**:
```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
```

**`_sources.yml`** — declare one source group per distinct source database/schema
found in the XML. Use `<RAW_DB>` as the database placeholder.

---

## Step 5: Generate Staging Models (views)

One staging model per source table group. For each model:

- Name: `stg_<source_system>_<entity>.sql`
- Materialised as view (inherited from dbt_project.yml)
- Pattern:
  ```sql
  with source as (
      select * from {{ source('<system>', '<table>') }}
      where <incremental_filter_using_var>
  ),
  renamed as (
      select
          -- rename / cast / derive columns here
          -- SRC_PTY_ID composite keys, gender normalisation, etc.
  )
  select * from renamed
  ```

**Key rules:**
- Session parameter (`$$LST_RUN_DT`) → `cast('{{ var("<LAST_RUN_VAR>") }}' as timestamp)`
- All exclusion filters (vendor codes, service types, date cutoffs) stay in staging
- Hardcoded source system codes (e.g. `'PBS'`) go here
- Composite key construction (e.g. `NPI || '|' || VENNPI || '|' || LEFT(vendor,9)`) goes here

---

## Step 6: Generate Intermediate Models (tables)

One model per logical transformation stage derived from the mapping chain.
Typical sequence (adjust based on actual XML):

| Model | Informatica equivalent | Purpose |
|---|---|---|
| `int_<entity>_delta_combined` | UNION of delta sources + JNR | Deduplicated changed party IDs |
| `int_<entity>_validated` | Lookup + Router (valid group) | Registry / reference validation |
| `int_<entity>_classified` | Expression (classification logic) | Role / type classification |
| `int_<entity>_filtered` | Filter transformation | Subset for downstream join |
| `int_<entity>_aggregated` | Aggregator | MIN/MAX date aggregation |
| `int_<entity>_keyed` | Expression (key gen) + Lookup | Composite SRC_KEY + MD5 hash |

**Pattern for each:**
```sql
with upstream as (
    select * from {{ ref('...') }}
),
...
select * from final
```

---

## Step 7: Generate Mart Model — CDC MERGE (incremental)

**`mart_<target_table>.sql`** — incremental MERGE:

```sql
{{
    config(
        materialized         = 'incremental',
        unique_key           = 'src_key',
        incremental_strategy = 'merge',
        merge_update_columns = [...],   -- all cols except etl_crt_dtm
        post_hook = ["
            UPDATE {{ this }} tgt
            SET tgt.active_ind = 'I', tgt.etl_actn_ind = 'D',
                tgt.etl_upd_dtm = current_timestamp()
            WHERE tgt.active_ind = 'Y'
              AND NOT EXISTS (
                  SELECT 1 FROM {{ ref('int_<entity>_keyed') }} src
                  WHERE src.src_key = tgt.src_key
              )
        "]
    )
}}

with source as (select * from {{ ref('int_<entity>_keyed') }}),

{% if is_incremental() %}
target_state as (select src_key, etl_hash_cd from {{ this }}),
cdc as (
    select s.*, t.src_key as tgt_src_key, t.etl_hash_cd as tgt_hash
    from source s left join target_state t on s.src_key = t.src_key
    where t.src_key is null or t.etl_hash_cd != s.etl_hash_cd
)
select *, case when tgt_src_key is null then 'I' else 'U' end as etl_actn_ind,
       'Y' as active_ind, current_timestamp() as etl_crt_dtm,
       current_timestamp() as etl_upd_dtm
from cdc
{% else %}
select *, 'I' as etl_actn_ind, 'Y' as active_ind,
       current_timestamp() as etl_crt_dtm, current_timestamp() as etl_upd_dtm
from source
{% endif %}
```

**ETL_HASH_CD** — MD5 of all business key columns + effective dates:
```sql
md5(<col1> || '|' || <col2> || '|' || to_char(<date_col>, 'YYYY-MM-DD HH24:MI:SS'))
```

Also create **`mart_<target_table>_exceptions.sql`** (materialized: table) for
records rejected by any lookup/validation step — filters `is_present IS NOT NULL`.

---

## Step 8: Validate and Present

Run a final check across all generated files:
- Every `{{ ref(...) }}` resolves to a model that was created
- Every `{{ source(...) }}` has a matching entry in `_sources.yml`
- `unique_key` column exists in the mart model SELECT
- `post_hook` UPDATE references `{{ this }}` correctly

Present final file tree and run instructions:

```
✅ dbt project scaffolded at <PROJECT_DIR>/<PROJECT_NAME>/

Run commands:
  dbt deps                                          # install dbt-utils
  dbt compile                                       # validate SQL
  dbt run --select staging+                         # run all layers in order
  dbt run --select mart.<target> --full-refresh     # force full reload
  dbt run --vars '{"<LAST_RUN_VAR>": "YYYY-MM-DD"}' # incremental run
  dbt test --select staging intermediate mart       # data quality tests

Replace placeholders before running:
  <RAW_DB>   → actual Snowflake raw database name
  profiles.yml → add Snowflake connection profile
```

---

## Stopping Points

- ✋ **Step 1** — Parameters collected
- ✋ **Step 2** — XML summary confirmed accurate
- ✋ **Step 3** — Migration assessment reviewed
- ✋ **Step 8** — Final file tree and run instructions reviewed

## Output

A fully scaffolded dbt project with:
- `dbt_project.yml` + `packages.yml`
- Staging views (one per source table group, incremental filter via `var()`)
- Intermediate tables (delta → validate → classify → filter → aggregate → key)
- Mart incremental MERGE model with soft-delete `post_hook` + exceptions model
- `_sources.yml` and `_schema.yml` with column docs and tests at every layer
