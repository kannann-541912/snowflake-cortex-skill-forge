# Client Context — de-schema-setup

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$de-schema-setup` skill reads this file first and applies these settings as overrides.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## Snowflake Environment

```yaml
client_name: ~                        # e.g. "Acme Corp"
target_database: SANDBOX              # REQUIRED — e.g. "ANALYTICS_DB"
target_schema: TPCH                   # REQUIRED — e.g. "CORE"
warehouse: ANALYTICS_WH
```

---

## DDL Conventions

```yaml
ddl:
  create_mode: IF_NOT_EXISTS          # IF_NOT_EXISTS | OR_REPLACE
  # IF_NOT_EXISTS — safe for production; never drops existing data
  # OR_REPLACE    — use only on dev/sandbox; destroys and recreates objects

  deploy_order:                       # Sequence for DDL execution (do not reorder lightly)
    - tags
    - masking_policies
    - file_formats
    - stages
    - tables
    - views
    - row_access_policies

  clustering_enabled: true            # Whether to add CLUSTER BY on recommended columns
  add_table_comments: true            # Whether to add COMMENT = '...' on every table
```

---

## Naming Conventions

> These must be consistent with what was used in `de-schema-design`.

```yaml
naming:
  staging_prefix: STG_                # e.g. STG_, RAW_, LANDING_
  mart_prefix: MART_                  # e.g. MART_, DM_, GOLD_
  fact_prefix: FCT_
  dim_prefix: DIM_

  # Data Vault naming (only if modeling_paradigm = data_vault in schema-design context)
  hub_prefix: HUB_
  link_prefix: LNK_
  satellite_prefix: SAT_

  tag_name: SOURCE_LINEAGE            # Tag applied to every generated table
  tag_comment: "Tracks origin system for data governance"
```

---

## Masking Policies

```yaml
masking_policies:
  visible_to_roles:                   # Roles that see raw/unmasked values
    - DATA_ENGINEER
    - SYSADMIN
  # Add client-specific roles:
  # - ACME_PII_READER_ROLE

  policy_definitions:
    email:
      name: MASK_EMAIL
      behavior: "show_domain_only"    # show_domain_only | sha2 | null
    generic_pii:
      name: MASK_PII_HASH
      behavior: "sha2"                # sha2 | null | partial
    # Add additional policy types as needed:
    # phone:
    #   name: MASK_PHONE
    #   behavior: "partial"           # e.g. show last 4 digits
```

---

## Verification Queries

```yaml
verification:
  run_after_deploy: true              # Whether to run SHOW TABLES / SHOW MASKING POLICIES
  verify_masking_applied: true        # Check POLICY_REFERENCES after ALTER COLUMN
  save_ddl_to_file: true             # Write all DDL to schema_setup.sql
  ddl_filename: schema_setup.sql
```

---

## Client Notes

```
# Add any client-specific DDL constraints or deployment policies here.
# Example:
#   - All tables must have DATA_RETENTION_TIME_IN_DAYS = 90 (data retention policy)
#   - No CLUSTER BY on tables < 10M rows (cost control policy)
#   - All CREATE statements must use the ANALYTICS_ENGINEER role, not SYSADMIN
#   - Tag SOURCE_LINEAGE must also be applied at the column level for PII columns
```
