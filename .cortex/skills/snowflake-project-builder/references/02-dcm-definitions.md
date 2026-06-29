# DCM Definitions Reference

All DCM definitions use the `DEFINE` keyword and are managed by `snow dcm plan/deploy`.
APPEND all generated blocks to the appropriate target file — never overwrite the file.

---

## 2.1 — DCM Table Definition → `sources/definitions/tables.sql`

```sql
DEFINE TABLE <DATABASE>.<SCHEMA>.<TABLE_NAME> (
    <COLUMN_NAME> <DATA_TYPE> [NOT NULL] [DEFAULT <expr>],
    ...
    _LOADED_AT       TIMESTAMP_LTZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP(),
    _SOURCE_SYSTEM   VARCHAR(50)    NOT NULL  DEFAULT '<source_name>'
)
    COMMENT = '<comment from SHOW TABLES or user-provided>'
    [CHANGE_TRACKING = TRUE]    -- add if any stream references this table
    [CLUSTER BY (<keys>)];      -- add if clustering info found in SHOW TABLES
```

**Rules:**
- UPPER_SNAKE_CASE for all identifiers
- Preserve original column order from DESCRIBE
- `NOT NULL` only if marked NOT NULL in DESCRIBE output
- `DEFAULT` only if a non-null default exists
- `CHANGE_TRACKING = TRUE` if any stream references this table
- `{{env_suffix}}` templating — NEVER apply to data tables (only warehouses/roles)

---

## 2.2 — DCM View Definition → `sources/definitions/views.sql`

```sql
DEFINE VIEW <DATABASE>.<SCHEMA>.<VIEW_NAME> AS
    <full SELECT body extracted from GET_DDL>;
```

**Rules:**
- Extract only the SELECT portion from `GET_DDL` (strip `CREATE OR REPLACE VIEW ... AS`)
- Preserve formatting and indentation from the original
- All referenced tables must use fully-qualified names (`DATABASE.SCHEMA.TABLE`)
- Never use `CREATE OR REPLACE VIEW` — this is a DCM definition

---

## 2.3 — DCM Infrastructure → `sources/definitions/infrastructure.sql`

```sql
-- Warehouse
DEFINE WAREHOUSE <WH_NAME>{{env_suffix}}
    WAREHOUSE_SIZE = '{{wh_size}}'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = '<comment>';

-- Schema
DEFINE SCHEMA <DATABASE>.<SCHEMA_NAME>
    COMMENT = '<comment>';
```

`{{env_suffix}}` and `{{wh_size}}` are DCM templating variables — always include them on
warehouse and role names.

---

## 2.4 — DCM Access Control → `sources/definitions/access.sql`

```sql
DEFINE ROLE <ROLE_NAME>{{env_suffix}}
    COMMENT = '<role description>';

GRANT USAGE ON WAREHOUSE <WH_NAME>{{env_suffix}}
    TO ROLE <ROLE_NAME>{{env_suffix}};

GRANT USAGE ON DATABASE <DATABASE>
    TO ROLE <ROLE_NAME>{{env_suffix}};

GRANT USAGE ON SCHEMA <DATABASE>.<SCHEMA>
    TO ROLE <ROLE_NAME>{{env_suffix}};

-- Future-proof: new tables auto-accessible
GRANT SELECT ON FUTURE TABLES IN SCHEMA <DATABASE>.<SCHEMA>
    TO ROLE <ROLE_NAME>{{env_suffix}};

-- Existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA <DATABASE>.<SCHEMA>
    TO ROLE <ROLE_NAME>{{env_suffix}};
```

**Rules:**
- Always use functional roles — never grant directly to users
- Always include `GRANT SELECT ON FUTURE TABLES` so new tables are automatically accessible
- Extract existing grants from `SHOW GRANTS TO ROLE <name>` in introspection
