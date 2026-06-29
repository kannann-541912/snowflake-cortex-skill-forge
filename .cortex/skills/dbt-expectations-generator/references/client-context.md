# Client Context — dbt-expectations-generator

> **Placeholder file.** Fill in the values for your client engagement and commit it.
> The `$dbt-expectations-generator` skill reads this file first and applies these settings
> as overrides over its built-in defaults.
>
> Parameters left as `~` fall through to the skill's built-in defaults.
>
> **Do NOT commit credentials or secrets to this file.**

---

## dbt Project

```yaml
client_name: ~                        # e.g. "Acme Corp"
dbt:
  project_path: ./dbt                 # Path to dbt project root (relative to CWD)
  profile_name: ~                     # Profile name in profiles.yml (~ = project name)

  # Must match dbt_project.yml +schema settings per layer
  staging_schema: staging
  intermediate_schema: intermediate
  mart_schema: marts

  # Schema YAML filenames per layer
  schema_files:
    staging: _staging.yml
    intermediate: _intermediate.yml
    marts: _marts.yml

  # dbt timezone var (required by dbt-expectations)
  # Must be set in dbt_project.yml: vars: 'dbt_date:time_zone': 'UTC'
  time_zone: UTC
```

---

## Test Coverage Tier

```yaml
test_coverage:
  tier: tier1_tier2                   # tier1 | tier1_tier2 | all
  # tier1       — Tier 1 only: PKs, timestamps, status enums (highest-value tests)
  # tier1_tier2 — Tier 1 + 2: also numeric bounds, pattern formats, high-null cols
  # all         — All tiers including noisy/low-value tests (use with caution)
```

---

## Thresholds and Tolerances

```yaml
thresholds:
  row_count_tolerance_pct: 20         # Row count window: baseline ± N%
  numeric_range_tolerance_pct: 5      # P01/P99 buffer: ± N%
  mostly_default: 0.99                # "mostly" parameter for non-strict tests
  # Raise to 1.0 for zero-tolerance (financial, regulated data)
  # Lower to 0.95 for dirty source data (legacy migration)

  freshness_warn_hours: 48            # Freshness WARN threshold
  freshness_error_hours: 96           # Freshness ERROR threshold (null = no error threshold)
  value_set_max_distinct: 30          # Only generate accepted_values when distinct count ≤ N
```

---

## Column Skip Rules

```yaml
skip_columns:
  metadata_columns: true              # Skip: _loaded_at, _fivetran_synced, dbt_updated_at
  high_cardinality_text: true         # Skip: free-text cols with >1000 distinct values
  zero_non_null: true                 # Skip: columns with 0 non-null values
  
  additional_skip_patterns:           # Additional column name patterns to skip
    []
  # Example:
  # additional_skip_patterns:
  #   - "*_comment"        # Skip all comment columns
  #   - "*_note"           # Skip all note columns
  #   - "raw_*"            # Skip raw/unparsed columns
```

---

## YAML Merge Behavior

```yaml
yaml_merge:
  preserve_existing: true             # Never remove or modify existing tests
  append_only: true                   # Only ADD new tests; never overwrite
  sort_columns_alphabetically: true   # Sort column entries in schema YAML
  indentation: 2                      # Spaces for YAML indentation
```

---

## dbt-expectations Package

```yaml
package:
  name: calogica/dbt_expectations
  version_range: [">=0.10.0", "<1.0.0"]
  auto_add_to_packages_yml: true      # Add to packages.yml if missing
```

---

## Static / Seed Tables

```yaml
static_tables:
  skip_freshness_tests: true          # Never add freshness tests to seed/static tables
  patterns:                           # Patterns that identify static tables
    - "seed_*"
    - "ref_*"
    - "dim_date*"
    - "dim_calendar*"
```

---

## Client Notes

```
# Add any client-specific test generation preferences here.
# Example:
#   - Financial data: use tier: all AND mostly_default: 1.0 (zero tolerance)
#   - Legacy migration: use tier: tier1 AND mostly_default: 0.95 (allow some dirty data)
#   - Skip all numeric range tests on price columns (known high variance from source)
#   - freshness error threshold is 24h (not 96h) — tight SLA
#   - dbt-expectations version must be >=0.10.4 (client has compatibility requirement)
#   - All generated tests must include a meta.owner field: owner: "data-engineering"
```
