---
name: de-share
description: "Phase 7 — Configure role-based access and data sharing by default: RBAC grants, row access policies, data shares, and a governance summary report"
parent_skill: de-workflow
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Read
  - Write
---

# Client Context
Read `references/client-context.md` at the start of every invocation. Apply any values it
defines as overrides: RBAC role prefix and hierarchy, consumer personas, PII governance
level, Row Access Policy settings, cross-account share configuration, and warehouse grants.
If the file is absent or a value is unset (`~`), use the built-in defaults. Never fail if
the file is missing.

# Safety
- Source is `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10` — read-only. Never grant RBAC roles on it.
- All GRANT statements target `SANDBOX.TPCH` objects only.

# TPCH Governance Notes
- TPCH is synthetic benchmark data — no real PII. Masking policies are not required but
  are still generated as good practice templates for when real data is added.
- Row Access Policies are optional for TPCH (no multi-tenant rows), but the N_NATIONKEY /
  R_REGIONKEY columns can demonstrate region-based row filtering if requested.

# Domain Context
You are a Snowflake data governance specialist. You implement least-privilege RBAC, masking
policies, and row access policies — applied at the object level, not afterthought grants.
You produce a `governance_report.md` that documents every access decision.

# When to Use
- Data is transformed and ready for consumption
- User says "share this data", "set up access", "configure RBAC", "create a data share"
- Replacing access tickets and manual masking with governed-by-default access

# When NOT to Use
- Data hasn't been transformed yet → run `de-transform` first
- User only needs to add a single GRANT → handle directly without this skill
- User wants row-level security on TPCH specifically (no multi-tenant data, RAP optional)

# Gotchas
- Always use `GRANT SELECT ON FUTURE TABLES` — point-in-time grants break when new tables are added.
- Never grant PRIVILEGE directly to users — always assign through functional roles.
- For TPCH, masking policies are generated as templates (no real PII), but still apply them as good practice.
- Row Access Policies on views are not supported — only on tables. Apply RAPs to the staging table, not the view.
- Governance report must be committed to Git — it's the audit trail.

# Standalone Quality Gate
```sql
-- Verify role grants are applied
SHOW GRANTS TO ROLE DE_CONSUMER_ROLE;

-- Verify masking policies are applied
SELECT object_name, column_name, policy_name
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.POLICY_REFERENCES(
    REF_ENTITY_NAME => 'SANDBOX.TPCH.STG_{table_name}',
    REF_ENTITY_DOMAIN => 'TABLE'
));
```

# What This Skill Provides
Replaces access tickets and manual masking with automated, least-privilege RBAC applied at
object creation. Produces a complete access model: roles, grants, row access policies, and
optionally a Snowflake data share for cross-account access.

# Instructions

## Step 0 — Load client context
Read `references/client-context.md`. If present, apply:
- `rbac.role_prefix` → override DE_ prefix (e.g. "ACME_" → ACME_CONSUMER_ROLE)
- `rbac.role_hierarchy` → replace default 3-tier model with client roles
- `rbac.additional_roles` → append extra roles (SCIENTIST, AUDITOR, etc.)
- `pii_governance.level` → strict | standard | minimal masking application
- `row_access_policy.*` → enable RAP and configure filter column and mapping table
- `cross_account_share.*` → enable and configure cross-account data shares

## Step 1 — Define the access model
Ask user (or infer from schema_design.md) which consumer personas need access:
- **DATA_CONSUMER**: read-only, masked PII, no sensitive columns
- **DATA_ANALYST**: read-only, unmasked PII, no DDL
- **DATA_ENGINEER**: read-write, unmasked PII, DDL on staging
- **DATA_SCIENTIST**: read-only + Snowpark compute, unmasked for approved datasets

## Step 2 — Create functional roles
```sql
-- Create roles if they don't exist
CREATE ROLE IF NOT EXISTS DE_CONSUMER_ROLE
  COMMENT = 'Read-only consumers — masked PII';
CREATE ROLE IF NOT EXISTS DE_ANALYST_ROLE
  COMMENT = 'Analysts — full read, unmasked PII where approved';
CREATE ROLE IF NOT EXISTS DE_ENGINEER_ROLE
  COMMENT = 'Data engineers — read/write staging, DDL on owned schemas';

-- Build role hierarchy
GRANT ROLE DE_CONSUMER_ROLE TO ROLE DE_ANALYST_ROLE;
GRANT ROLE DE_ANALYST_ROLE  TO ROLE DE_ENGINEER_ROLE;
GRANT ROLE DE_ENGINEER_ROLE TO ROLE SYSADMIN;
```

## Step 3 — Grant minimum required privileges
```sql
-- Database usage
GRANT USAGE ON DATABASE {database} TO ROLE DE_CONSUMER_ROLE;
GRANT USAGE ON SCHEMA {database}.{schema} TO ROLE DE_CONSUMER_ROLE;

-- Table access — consumers: SELECT only on mart tables
GRANT SELECT ON ALL TABLES IN SCHEMA {database}.{schema} TO ROLE DE_CONSUMER_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA {database}.{schema} TO ROLE DE_CONSUMER_ROLE;

-- Analysts: also grant access to views and dynamic tables
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA {database}.{schema} TO ROLE DE_ANALYST_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA {database}.{schema} TO ROLE DE_ANALYST_ROLE;

-- Engineers: INSERT/UPDATE/DELETE on staging schema only
GRANT INSERT, UPDATE, DELETE ON ALL TABLES
  IN SCHEMA {database}.STAGING TO ROLE DE_ENGINEER_ROLE;

-- Warehouse access
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DE_CONSUMER_ROLE;
```

## Step 4 — Apply Row Access Policy (if row-level filtering needed)
```sql
-- Example: users only see rows for their own region
CREATE ROW ACCESS POLICY IF NOT EXISTS {database}.{schema}.RAP_REGION_FILTER
  AS (region_col VARCHAR) RETURNS BOOLEAN ->
    CURRENT_ROLE() IN ('DE_ENGINEER_ROLE', 'SYSADMIN')  -- engineers see all
    OR EXISTS (
        SELECT 1
        FROM {database}.{schema}.USER_REGION_MAP
        WHERE user_name = CURRENT_USER()
          AND region    = region_col
    );

-- Apply to target table
ALTER TABLE {database}.{schema}.{target_table}
  ADD ROW ACCESS POLICY {database}.{schema}.RAP_REGION_FILTER
  ON (region);
```

## Step 5 — Verify masking policies are active
```sql
SELECT
    policy_name,
    ref_entity_name,
    ref_column_name,
    policy_status
FROM TABLE(
    INFORMATION_SCHEMA.POLICY_REFERENCES(
        ref_entity_name => '{database}.{schema}.{target_table}',
        ref_entity_domain => 'TABLE'
    )
);
```

## Step 6 — Create Snowflake Data Share (cross-account, if requested)
```sql
-- Create share
CREATE SHARE IF NOT EXISTS {share_name}
  COMMENT = 'Governed data share for {consumer_account}';

-- Grant objects to share
GRANT USAGE ON DATABASE {database} TO SHARE {share_name};
GRANT USAGE ON SCHEMA {database}.{schema} TO SHARE {share_name};
GRANT SELECT ON TABLE {database}.{schema}.{target_table} TO SHARE {share_name};

-- Add consumer account
ALTER SHARE {share_name} ADD ACCOUNTS = {consumer_account_locator};

-- Verify share
SHOW GRANTS TO SHARE {share_name};
```

## Step 7 — Generate governance summary report
Write `governance_report.md`:

```markdown
# Governance Report
**Pipeline:** {source_name} → {target_db}.{target_schema}.{target_table}
**Generated at:** {timestamp}

## Access Model
| Role | Privileges | PII Visible | Row Filter |
|------|-----------|-------------|------------|
| DE_CONSUMER_ROLE | SELECT | Masked | {region filter if applicable} |
| DE_ANALYST_ROLE | SELECT | Unmasked | None |
| DE_ENGINEER_ROLE | SELECT, INSERT, UPDATE, DELETE | Unmasked | None |

## Masking Policies Applied
| Column | Policy | Visible To |
|--------|--------|-----------|
| CUSTOMER_EMAIL | MASK_EMAIL | ENGINEER, SYSADMIN |

## Row Access Policies Applied
| Policy | Column | Condition |
|--------|--------|-----------|
| RAP_REGION_FILTER | REGION | User-region mapping table |

## Data Shares
| Share Name | Consumer Account | Objects |
|-----------|-----------------|---------|
| {share_name} | {consumer_account} | {target_table} |

## Next Steps
- Review access grants with data owner
- Schedule quarterly privilege audit
- Run `$de-profile` again after 30 days to detect schema drift
```

## Best Practices
- Always use functional roles — never grant privileges directly to users
- `GRANT SELECT ON FUTURE TABLES` — so new tables are automatically accessible
- Verify masking policies via POLICY_REFERENCES — policies can silently become inactive
- Row Access Policies perform best with indexed mapping tables

## Common Patterns

### Pattern 1: Internal sharing
RBAC roles + grants to internal users/groups — most common case

### Pattern 2: Cross-account sharing
Snowflake Data Share for zero-copy sharing to partner or customer accounts

# Examples

## Example 1: TPCH access setup
User: `$de-share Set up access for SANDBOX.TPCH mart tables`
Assistant: Creates DE_CONSUMER_ROLE / DE_ANALYST_ROLE / DE_ENGINEER_ROLE, grants SELECT
on all SANDBOX.TPCH tables + future tables to consumer role, notes no PII masking needed
for TPCH synthetic data (policies still generated as templates), writes governance_report.md.

