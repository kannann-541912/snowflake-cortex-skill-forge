# Client Context — de-share

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$de-share` skill reads this file first and applies these settings as overrides.
>
> This file defines the client's RBAC model, consumer personas, and data governance policy.
> Different clients may have radically different access structures — a regulated financial
> firm may require strict PII governance + audit roles, while an internal analytics team
> may have a simpler three-tier model.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## Snowflake Environment

```yaml
client_name: ~                        # e.g. "Acme Corp"
target_database: SANDBOX
target_schema: TPCH
```

---

## RBAC Role Model

```yaml
rbac:
  role_prefix: DE_                    # Prefix applied to all generated functional roles
                                      # e.g. "DE_" → DE_CONSUMER_ROLE
                                      # e.g. "ACME_" → ACME_CONSUMER_ROLE
                                      # e.g. "" → CONSUMER_ROLE (no prefix)

  role_hierarchy:                     # Ordered from least to most privilege
    - role: CONSUMER
      suffix: CONSUMER_ROLE
      description: "Read-only; masked PII; no DDL"
      can_see_pii: false
      can_write: false

    - role: ANALYST
      suffix: ANALYST_ROLE
      description: "Read-only; unmasked PII where approved; no DDL"
      can_see_pii: true
      can_write: false

    - role: ENGINEER
      suffix: ENGINEER_ROLE
      description: "Read/write staging; DDL on owned schemas; full PII access"
      can_see_pii: true
      can_write: true

  # Optional additional roles — add as many as needed
  additional_roles: []
  # Example:
  # additional_roles:
  #   - role: SCIENTIST
  #     suffix: SCIENTIST_ROLE
  #     description: "Read + Snowpark compute; approved unmasked datasets"
  #     can_see_pii: false
  #     can_write: false
  #     snowpark_access: true
  #
  #   - role: AUDITOR
  #     suffix: AUDITOR_ROLE
  #     description: "Read all tables including audit columns; masked PII"
  #     can_see_pii: false
  #     can_write: false

  parent_role: SYSADMIN               # Top of the role hierarchy grants up to this role
```

---

## PII Governance Level

```yaml
pii_governance:
  level: standard                     # strict | standard | minimal
  # strict   — All PII columns masked for all roles except ENGINEER + SYSADMIN.
  #            Row Access Policies applied on all tables.
  #            Audit logging mandatory.
  # standard — PII masked for CONSUMER; unmasked for ANALYST+.
  #            Row Access Policies optional.
  # minimal  — PII columns identified but masking policies generated as templates only.
  #            Apply manually after review.

  apply_masking_policies: true        # Apply masking policy ALTER statements at deploy time
  verify_masking_after_apply: true    # Run POLICY_REFERENCES query to confirm attachment
  generate_policies_even_without_pii: true
  # true = always generate masking policy templates (good practice even for non-PII data)
```

---

## Row Access Policy

```yaml
row_access_policy:
  enabled: false                      # true = generate and apply RAP
  # Common use cases:
  # - Region-based row filtering (regional teams see only their region's data)
  # - Tenant-based filtering (multi-tenant datasets)
  # - Department-based filtering (CUSTOMER data scoped to account managers)

  filter_column: ~                    # Column used for row-level filtering, e.g. "REGION"
  mapping_table: ~                    # Table that maps users to allowed filter values
                                      # e.g. "SANDBOX.TPCH.USER_REGION_MAP"
  admin_bypass_roles:                 # Roles that bypass the RAP and see all rows
    - DE_ENGINEER_ROLE
    - SYSADMIN
```

---

## Cross-Account Data Share

```yaml
cross_account_share:
  enabled: false
  share_name: ~                       # e.g. "ACME_ANALYTICS_SHARE"
  consumer_account_locator: ~         # e.g. "ABC12345" (target account locator)
  objects_to_share: []               # Tables/views to include in the share
  # Example:
  # objects_to_share:
  #   - SANDBOX.TPCH.MART_ORDERS_ENRICHED
  #   - SANDBOX.TPCH.MART_CUSTOMER_SUMMARY
```

---

## Warehouse Access

```yaml
warehouse_grants:
  warehouse: ANALYTICS_WH
  grant_to_roles:                     # These roles get USAGE on the warehouse
    - "{{role_prefix}}CONSUMER_ROLE"  # Resolved using role_prefix above
    - "{{role_prefix}}ANALYST_ROLE"
```

---

## Governance Report

```yaml
governance_report:
  filename: governance_report.md
  commit_to_git: true                 # Remind user to commit the report (audit trail)
  include_masking_verification: true
  include_access_matrix: true
```

---

## Client Notes

```
# Add any client-specific access model requirements here.
# Example (regulated financial client):
#   - Separate AUDITOR_ROLE must have read access to ALL tables but with masking
#   - PII columns must NEVER be visible to ANALYST_ROLE (override standard policy)
#   - Cross-account share is required for the BI team in a separate Snowflake account
#   - Row Access Policy required on ORDERS table filtered by SALES_REGION column
#
# Example (internal analytics client):
#   - No masking policies needed (all users are internal, all roles trust each other)
#   - Three roles: CONSUMER, ENGINEER, SYSADMIN only — no ANALYST tier
#   - No cross-account share — all access is internal
```
