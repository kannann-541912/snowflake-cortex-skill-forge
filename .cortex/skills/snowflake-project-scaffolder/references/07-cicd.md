# CI/CD Workflows Reference

## .github/workflows/validate.yml

```yaml
# .github/workflows/validate.yml — PR validation
name: Validate

on:
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: pip install snowflake-cli dbt-snowflake pyyaml toml gitleaks

      - name: Security scan (gitleaks)
        run: gitleaks detect --source . --config .gitleaks.toml

      - name: Naming lint
        run: python scripts/check_naming.py

      - name: Validate agent specs
        run: python scripts/validate_agent_spec.py

      - name: DCM plan (dry-run)
        env:
          SNOWFLAKE_PAT: ${{ secrets.SNOWFLAKE_CI_PAT }}
        run: |
          snow connection set-token --connection ci --token "$SNOWFLAKE_PAT"
          snow dcm plan --target CI -c ci

      - name: dbt compile
        env:
          DBT_SNOWFLAKE_PAT: ${{ secrets.SNOWFLAKE_CI_PAT }}
        run: |
          cd dbt
          pip install dbt-snowflake -q
          dbt deps
          dbt compile
```

## .github/workflows/deploy.yml

```yaml
# .github/workflows/deploy.yml — Merge to main → PROD deploy
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      target:
        description: 'DCM target (DEV or PROD)'
        required: true
        default: 'PROD'

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: pip install snowflake-cli dbt-snowflake pyyaml toml

      - name: DCM deploy
        env:
          SNOWFLAKE_PAT: ${{ secrets.SNOWFLAKE_PROD_PAT }}
          TARGET: ${{ github.event.inputs.target || 'PROD' }}
        run: |
          snow connection set-token --connection prod --token "$SNOWFLAKE_PAT"
          snow dcm deploy --target "$TARGET" -c prod

      - name: dbt run
        env:
          DBT_SNOWFLAKE_PAT: ${{ secrets.SNOWFLAKE_PROD_PAT }}
        run: |
          cd dbt
          pip install dbt-snowflake -q
          dbt deps
          dbt run --target prod
          dbt test --target prod

      - name: Deploy agents
        env:
          SNOWFLAKE_PAT: ${{ secrets.SNOWFLAKE_PROD_PAT }}
        run: |
          snow connection set-token --connection prod --token "$SNOWFLAKE_PAT"
          python agent/deploy_all.py -c prod
```
