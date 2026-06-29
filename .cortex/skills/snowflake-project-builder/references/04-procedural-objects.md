# Procedural Objects Reference

All objects below use `CREATE OR REPLACE` (not `DEFINE`) — DCM has no syntax for them.

| Object Type | Target File |
|---|---|
| Stored Procedure (SQL) | `sources/definitions/procedures.sql` |
| Stored Procedure (Snowpark) | `ingestion/snowpark/transforms.py` |
| UDF / UDTF | `sources/definitions/functions.sql` |
| Data Metric Function (DMF) | `sources/definitions/data_quality.sql` |
| Dynamic Table | `sources/definitions/dynamic_tables.sql` |
| Alert | `sources/definitions/alerts.sql` |
| Masking / Row Access Policy | `sources/definitions/policies.sql` |
| Tag | `sources/definitions/tags.sql` |
| Sequence | `sources/definitions/sequences.sql` |
| Network Rule / EAI | `sources/definitions/network.sql` |
| Storage / Notification Integration | `sources/definitions/integrations.sql` |
| Secret | `sources/definitions/secrets.sql` |

---

## Stored Procedures (SQL) → `sources/definitions/procedures.sql`

```sql
CREATE OR REPLACE PROCEDURE <DATABASE>.<SCHEMA>.<PROCEDURE_NAME>(
    <PARAM_NAME> <param_type> [DEFAULT <default>]
)
RETURNS <return_type>
LANGUAGE SQL
[EXECUTE AS CALLER | OWNER]    -- CALLER for read-only, OWNER for privileged ops
COMMENT = '<comment>'
AS
$$
BEGIN
    <procedure_body>;
END;
$$;
```

## Stored Procedures (Snowpark) → `ingestion/snowpark/transforms.py`

Add a Python function + registration call:
```python
def <function_name>(session: Session) -> str:
    df = session.table("<SOURCE_TABLE_FQN>")
    # transformation logic
    df.write.mode("overwrite").save_as_table("<TARGET_TABLE_FQN>")
    return f"Processed {df.count()} records"

# In register_procedures():
session.sproc.register(
    func=<function_name>,
    name="<DATABASE>.<SCHEMA>.<PROCEDURE_NAME>",
    replace=True, is_permanent=True,
    stage_location="@SANDBOX.TPCH_LANDING.SNOWPARK_OUTPUT_STAGE",
    packages=["snowflake-snowpark-python"],
    comment="<description>",
)
```

## UDFs → `sources/definitions/functions.sql`

```sql
-- SQL UDF
CREATE OR REPLACE FUNCTION <DATABASE>.<SCHEMA>.<FUNCTION_NAME>(<param> <type>)
RETURNS <return_type> LANGUAGE SQL COMMENT = '<comment>'
AS $$ <function_body> $$;

-- Python UDF
CREATE OR REPLACE FUNCTION <DATABASE>.<SCHEMA>.<FUNCTION_NAME>(<param> <type>)
RETURNS <return_type> LANGUAGE PYTHON RUNTIME_VERSION = '3.11'
HANDLER = '<handler_function_name>' COMMENT = '<comment>'
AS $$
def <handler_function_name>(<param>):
    <python_body>
    return <result>
$$;
```

## DMFs → `sources/definitions/data_quality.sql`

```sql
CREATE OR REPLACE DATA METRIC FUNCTION <DATABASE>.<SCHEMA>.<DMF_NAME>(
    ARG_T TABLE(<column_name> <column_type>)
)
RETURNS NUMBER COMMENT = '<comment>'
AS $$ SELECT COUNT_IF(<column_name> IS NULL) FROM ARG_T $$;
```

DMF pattern selection by column type:
| Column Pattern | DMF Type | Condition |
|---|---|---|
| NOT NULL column | null_count | `COUNT_IF(col IS NULL)` |
| Unique/PK column | duplicate_count | `COUNT(*) - COUNT(DISTINCT col)` |
| Email column | invalid_email_count | `COUNT_IF(NOT RLIKE(col, '^[a-zA-Z0-9._%+-]+@...'))` |
| Numeric column | out_of_range_count | `COUNT_IF(col < min OR col > max)` |
| Date column | future_date_count | `COUNT_IF(col > CURRENT_DATE())` |
| FK column | orphan_count | `COUNT_IF(col NOT IN (SELECT pk FROM parent))` |
| Enum column | invalid_value_count | `COUNT_IF(col NOT IN ('VAL1', 'VAL2'))` |

## Dynamic Tables → `sources/definitions/dynamic_tables.sql`

```sql
CREATE OR REPLACE DYNAMIC TABLE <DATABASE>.<SCHEMA>.<DT_NAME>
    TARGET_LAG = '<lag>'    -- '1 hour', '5 minutes', or 'DOWNSTREAM'
    WAREHOUSE = <WAREHOUSE>
    COMMENT = '<comment>'
AS
    <SELECT statement>;
```

Use Dynamic Tables for near-real-time refresh without complex merge logic.
Use dbt incremental for complex merge, lineage, testing, and batch cadence.

## Alerts → `sources/definitions/alerts.sql`

```sql
-- NOTE: Alerts are SUSPENDED by default. Resume: ALTER ALERT <name> RESUME;
CREATE OR REPLACE ALERT <DATABASE>.<SCHEMA>.<ALERT_NAME>
    WAREHOUSE = <WAREHOUSE>
    SCHEDULE = '<schedule>'
    COMMENT = '<comment>'
    IF (EXISTS (<condition_query>))
THEN
    CALL SYSTEM$SEND_EMAIL(
        '<notification_integration>', '<recipients>', '<subject>', '<body>'
    );
```

## Policies → `sources/definitions/policies.sql`

```sql
-- Masking Policy
CREATE OR REPLACE MASKING POLICY <DATABASE>.<SCHEMA>.<POLICY_NAME>
AS (VAL <data_type>) RETURNS <data_type> ->
    CASE WHEN CURRENT_ROLE() IN ('<privileged_role>') THEN VAL ELSE '<masked>' END
COMMENT = '<comment>';
-- Apply: ALTER TABLE <t> ALTER COLUMN <col> SET MASKING POLICY <policy>;

-- Row Access Policy
CREATE OR REPLACE ROW ACCESS POLICY <DATABASE>.<SCHEMA>.<POLICY_NAME>
AS (<column_name> <data_type>) RETURNS BOOLEAN -> <condition>
COMMENT = '<comment>';
-- Apply: ALTER TABLE <t> ADD ROW ACCESS POLICY <policy> ON (<col>);
```

## Tags → `sources/definitions/tags.sql`

```sql
CREATE OR REPLACE TAG <DATABASE>.<SCHEMA>.<TAG_NAME>
    ALLOWED_VALUES = '<value1>', '<value2>'
    COMMENT = '<comment>';
-- Apply: ALTER TABLE <t> SET TAG <DATABASE>.<SCHEMA>.<TAG_NAME> = '<value>';
-- Apply column: ALTER TABLE <t> ALTER COLUMN <col> SET TAG <DATABASE>.<SCHEMA>.<TAG_NAME> = '<value>';
```

## Sequences → `sources/definitions/sequences.sql`

```sql
CREATE OR REPLACE SEQUENCE <DATABASE>.<SCHEMA>.<SEQUENCE_NAME>
    START = 1 INCREMENT = 1 COMMENT = '<comment>';
```

## Network Rules & Integrations → `sources/definitions/network.sql`

```sql
-- Requires ACCOUNTADMIN — deployed via CI with elevated role
CREATE OR REPLACE NETWORK RULE <RULE_NAME>
    TYPE = HOST_PORT MODE = EGRESS
    VALUE_LIST = ('<host1>:<port>', '<host2>') COMMENT = '<comment>';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION <EAI_NAME>
    ALLOWED_NETWORK_RULES = (<RULE_NAME>) ENABLED = TRUE COMMENT = '<comment>';

GRANT USAGE ON INTEGRATION <EAI_NAME> TO ROLE <role>;
```

## Integrations → `sources/definitions/integrations.sql`

```sql
CREATE OR REPLACE STORAGE INTEGRATION <INTEGRATION_NAME>
    TYPE = EXTERNAL_STAGE STORAGE_PROVIDER = 'S3'
    STORAGE_AWS_ROLE_ARN = '<arn>' ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = ('<s3_path>') COMMENT = '<comment>';

CREATE OR REPLACE NOTIFICATION INTEGRATION <INTEGRATION_NAME>
    TYPE = EMAIL ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('<email1>', '<email2>') COMMENT = '<comment>';
```

## Secrets → `sources/definitions/secrets.sql`

```sql
-- NEVER include actual secret values — always use empty placeholders.
CREATE OR REPLACE SECRET <DATABASE>.<SCHEMA>.<SECRET_NAME>
    TYPE = GENERIC_STRING
    SECRET_STRING = ''    -- PLACEHOLDER: set actual value in Snowsight UI
    COMMENT = '<comment>';

GRANT USAGE ON SECRET <DATABASE>.<SCHEMA>.<SECRET_NAME> TO ROLE <role>;
```
