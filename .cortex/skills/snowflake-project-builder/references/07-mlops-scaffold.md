# MLOps Scaffold Reference

## ML Model Directory Layout

```
custom-ml-models/<MODEL_NAME>-v<VERSION>/
├── spec.yml                  ← Model specification
├── model_card.md             ← Risk/fairness documentation
├── snowflake/
│   └── sql/
│       ├── register.sql      ← REGISTER MODEL statement
│       └── deploy_function.sql ← CREATE FUNCTION wrapper
├── lifecycle/
│   └── release_notes.md      ← What changed in this version
└── runbooks/
    ├── rollback.md           ← Steps to revert to previous version
    └── approvals.md          ← Dual-control approval log (required for high-risk)
```

## spec.yml

```yaml
name: <MODEL_NAME>
version: "v<VERSION>"
description: "<model purpose>"
model_type: <sklearn_pipeline | pytorch | tensorflow | xgboost>
artifact_type: <SKLEARN_PIPELINE | PYTORCH_MODEL | ONNX_MODEL>
schema: <DATABASE>.<SCHEMA>
warehouse: <WAREHOUSE>

inputs:
  - name: <feature_col>
    type: <NUMBER | VARCHAR | BOOLEAN>

output:
  name: prediction
  type: FLOAT

thresholds:
  min_accuracy: 0.85
  max_latency_ms: 200
  dual_control_required: <true | false>
```

## snowflake/sql/register.sql

```sql
-- Register ML model artifact from internal stage
USE ROLE <DEFAULT_ROLE>;
USE DATABASE <DATABASE>;
USE SCHEMA <SCHEMA>;

CREATE STAGE IF NOT EXISTS <MODEL_NAME>_STAGE
  COMMENT = 'Artifact store for <MODEL_NAME>';

-- Run before this SQL: snow stage put local/<model>.pkl @<MODEL_NAME>_STAGE
CREATE MODEL IF NOT EXISTS <MODEL_NAME>
  VERSION 'v<VERSION>'
  FROM @<MODEL_NAME>_STAGE/<model_file>.pkl
  ARTIFACT_TYPE = '<ARTIFACT_TYPE>'
  COMMENT = 'Registered v<VERSION>';
```

## snowflake/sql/deploy_function.sql

```sql
CREATE OR REPLACE FUNCTION <MODEL_NAME>_PREDICT(input VARIANT)
RETURNS FLOAT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
HANDLER = 'predict'
PACKAGES = ('snowflake-ml-python')
AS $$
from snowflake.ml.model import Model
def predict(input):
    model = Model.load('<DATABASE>.<SCHEMA>.<MODEL_NAME>', version='v<VERSION>')
    return model.predict(input)
$$;
```

## model_card.md

```markdown
# Model Card: <MODEL_NAME> v<VERSION>

## Overview
**Purpose**: <what this model predicts>
**Training data**: <source table/period>
**Target variable**: <column name>

## Performance
| Metric | Dev | Staging | Prod Threshold |
|---|---|---|---|
| Accuracy | - | - | ≥ 0.85 |
| F1 Score | - | - | ≥ 0.80 |
| Latency p99 | - | - | ≤ 200ms |

## Risk & Fairness
- [ ] Bias audit completed
- [ ] Demographic parity checked
- Known risks: <describe>

## Scope
- IN scope: <use cases>
- OUT of scope: <excluded use cases>

## Required Approvals (high-risk models only)
| Approver | Role | Signed |
|---|---|---|
| | Data Science Lead | |
| | Data Governance Lead | |
```

## lifecycle/release_notes.md

```markdown
# Release Notes: <MODEL_NAME> v<VERSION>

Released: <date>
Author: <name>

## Changes from v<PREVIOUS_VERSION>
- <change 1>

## Eval Results
- Dev pass rate: <N>%
- Staging pass rate: <N>%

## Rollback Procedure
See runbooks/rollback.md
```

## runbooks/rollback.md

```markdown
# Rollback Runbook: <MODEL_NAME>

## When to Rollback
- Accuracy drops below threshold in PROD monitoring
- Latency exceeds 200ms p99 for > 5 minutes
- Approvals revoked

## Rollback Steps

1. Identify last good version: `SHOW VERSIONS IN MODEL <DATABASE>.<SCHEMA>.<MODEL_NAME>;`
2. Update the UDF to point to the previous version:
```sql
CREATE OR REPLACE FUNCTION <MODEL_NAME>_PREDICT(input VARIANT) ...
-- Change version to 'v<PREV_VERSION>'
```
3. Notify stakeholders.
4. Log the rollback in approvals.md with reason and timestamp.
```
