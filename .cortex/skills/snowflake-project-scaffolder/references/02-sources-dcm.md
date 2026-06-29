# Sources and DCM Definitions Reference

## sources/definitions/tables.yml

```yaml
# sources/definitions/tables.yml
tables:
  - name: {TABLE_NAME}
    description: "Landing table for {TABLE_NAME} raw data"
    columns:
      - name: id
        description: "Primary key"
        policy_refs: []

  - name: {TABLE_NAME}_QUARANTINE
    description: "Rejected rows that failed quality checks"
    columns:
      - name: id
        description: "Original row identifier"
      - name: REJECTION_REASON
        description: "Human-readable reason for rejection"
      - name: RAW_ROW
        description: "Full original row as VARIANT"
```

## sources/definitions/views.yml

```yaml
# sources/definitions/views.yml
views:
  - name: VW_{TABLE_NAME}
    description: "Read-optimized view over {TABLE_NAME} landing table"
    source_table: "{DATABASE}.{SCHEMA}.{TABLE_NAME}"
    columns: []
```

## sources/definitions/infra.yml — Warehouses

```yaml
# sources/definitions/infra.yml
warehouses:
  - name: "{WAREHOUSE}{{env_suffix}}"
    description: "Primary compute warehouse"
    size: "{{wh_size}}"
    auto_suspend_seconds: 60
    auto_resume: true
    initially_suspended: true
    resource_monitor: "{WAREHOUSE}_MONITOR"

  - name: "TRANSFORM_WH{{env_suffix}}"
    description: "Transform and dbt compute"
    size: "{{wh_size}}"
    auto_suspend_seconds: 60
    auto_resume: true
    initially_suspended: true
```

## sources/definitions/access.yml — RBAC

```yaml
# sources/definitions/access.yml
roles:
  - name: {DEFAULT_ROLE}
    description: "Infrastructure DBA role — Snowflake infrastructure only"
    grants: []

  - name: {READER_ROLE}
    description: "Data reader — SELECT on mart tables"
    grants:
      - privilege: SELECT
        on: future tables in schema {DATABASE}.{SCHEMA}
      - privilege: USAGE
        on: database {DATABASE}
      - privilege: USAGE
        on: schema {DATABASE}.{SCHEMA}
      - privilege: USAGE
        on: warehouse {WAREHOUSE}

users:
  - name: {SERVICE_USER}
    description: "CI/CD service user"
    roles:
      - {DEFAULT_ROLE}
```

## sources/definitions/masking.yml (optional, generated as template)

```yaml
# sources/definitions/masking.yml
masking_policies:
  - name: MASK_PII_HASH
    description: "SHA2-256 hash of PII strings for non-approved roles"
    body: |
      CASE
        WHEN CURRENT_ROLE() IN ('DATA_ENGINEER_ROLE', 'DE_ANALYST_ROLE') THEN val
        ELSE SHA2(val, 256)
      END
    data_types:
      - VARCHAR

  - name: MASK_EMAIL
    description: "Show only domain part for non-approved roles"
    body: |
      CASE
        WHEN CURRENT_ROLE() IN ('DATA_ENGINEER_ROLE') THEN val
        ELSE CONCAT('***@', SPLIT_PART(val, '@', 2))
      END
    data_types:
      - VARCHAR
```
