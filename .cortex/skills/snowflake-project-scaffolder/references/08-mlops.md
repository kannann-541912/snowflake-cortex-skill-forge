# MLOps Pillar Reference (Optional)

Only generate this section when the user chose "yes" for the MLOps pillar in the setup wizard.

## Directory Structure

```
custom-ml-models/
├── snowflake/
│   └── sql/
│       └── {MODEL_NAME}/
│           ├── register.sql        ← REGISTER MODEL from stage
│           └── deploy_function.sql ← CREATE FUNCTION wrapper
├── templates/
│   └── model_spec.yml              ← Spec template for new models
├── lifecycle/
│   └── promotion_workflow.md       ← DEV → STAGING → PROD gate checklist
├── environments/
│   └── env_config.yml              ← Environment-specific settings
└── runbooks/
    ├── rollback.md                 ← Steps to roll back a bad model version
    └── approvals.md                ← Dual-control approval checklist (required for high-risk models)
```

## custom-ml-models/snowflake/sql/{MODEL_NAME}/register.sql

```sql
-- register.sql — Register ML model from internal stage
-- Replace placeholders before running

USE ROLE {DEFAULT_ROLE};
USE DATABASE {DATABASE};
USE SCHEMA {SCHEMA};

-- Stage the model artifact
PUT file://local/path/to/{model_name_lower}_v{VERSION}.pkl
    @{MODEL_NAME}_STAGE
    OVERWRITE = TRUE;

-- Register model version
CREATE MODEL IF NOT EXISTS {MODEL_NAME}
  VERSION 'v{VERSION}'
  FROM @{MODEL_NAME}_STAGE/{model_name_lower}_v{VERSION}.pkl
  ARTIFACT_TYPE = 'SKLEARN_PIPELINE'
  COMMENT = 'Registered {datetime.utcnow().isoformat()} by CI';
```

## custom-ml-models/snowflake/sql/{MODEL_NAME}/deploy_function.sql

```sql
-- deploy_function.sql — Create UDF wrapper around registered model

CREATE OR REPLACE FUNCTION {MODEL_NAME}_PREDICT(input VARIANT)
RETURNS FLOAT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
HANDLER = 'predict'
PACKAGES = ('snowflake-ml-python')
AS $$
from snowflake.ml.model import Model

def predict(input):
    model = Model.load('{DATABASE}.{SCHEMA}.{MODEL_NAME}', version='v{VERSION}')
    return model.predict(input)
$$;
```

## custom-ml-models/lifecycle/promotion_workflow.md

```markdown
# Model Promotion Checklist

## DEV → STAGING
- [ ] Unit tests pass (pytest) on training data subset
- [ ] Model spec validated (validate_agent_spec.py analogue for ML)
- [ ] F1 / RMSE / AUC meets minimum threshold defined in env_config.yml
- [ ] Bias audit completed (check for demographic parity if applicable)

## STAGING → PROD
- [ ] A/B or shadow evaluation on 1% of live traffic for ≥ 7 days
- [ ] Approval from data science lead (sign off in approvals.md)
- [ ] Approval from data governance lead (sign off in approvals.md)
- [ ] Rollback plan confirmed (see runbooks/rollback.md)
- [ ] Monitor alert configured (accuracy drift alert in Snowflake)
```

## custom-ml-models/runbooks/approvals.md

```markdown
# Dual-Control Approvals for High-Risk ML Model Deployments

| Model | Version | Approver 1 (DS Lead) | Approver 2 (Governance Lead) | Date | Deployed By |
|---|---|---|---|---|---|
| {MODEL_NAME} | v{VERSION} | | | | |

⚠️ Both approvers must sign off before any PROD deployment of a high-risk model.
```

## custom-ml-models/environments/env_config.yml

```yaml
environments:
  dev:
    min_accuracy: 0.75
    max_latency_ms: 500
    warehouse: {WAREHOUSE}
  staging:
    min_accuracy: 0.80
    max_latency_ms: 300
    warehouse: {WAREHOUSE}
  prod:
    min_accuracy: 0.85
    max_latency_ms: 200
    warehouse: {WAREHOUSE}
    dual_control_required: true
```
