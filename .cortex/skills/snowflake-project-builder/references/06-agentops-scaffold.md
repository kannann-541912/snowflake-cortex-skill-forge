# AgentOps Scaffold Reference

## Cortex Agent Directory Layout

```
agent/agents/<AGENT_NAME>/
├── agent.yml                ← Agent spec (required)
├── system_prompt.md         ← Detailed system prompt
├── evals/
│   ├── basic_eval.json      ← Evaluation test cases
│   └── results/             ← (gitignored) eval run outputs
├── prompts/
│   └── user_queries.md      ← Example user queries and expected behavior
└── monitoring/
    └── alerts.yml           ← Alert definitions for agent health
```

## agent.yml

```yaml
name: <AGENT_NAME>
version: "1.0.0"
description: "<one-line description>"
model: snowflake-arctic
warehouse: <WAREHOUSE>
max_tokens: 4096
temperature: 0.1

tools:
  - name: execute_sql
    type: CORTEX_ANALYST
    warehouse: <WAREHOUSE>
    semantic_model: ""    # TODO: link semantic model YAML or stage path

instructions: |
  You are a <role> assistant for <project_name>.
  Answer questions about the data in <DATABASE>.<SCHEMA>.
  Always cite your sources and include row counts.
  If a query returns no rows, explain why rather than saying "no data".
```

## system_prompt.md

```markdown
# <AGENT_NAME> System Prompt

## Role
You are a specialized <role> AI assistant for <project_name>.

## Scope
You have access to the following schemas:
- `<DATABASE>.<SCHEMA>` — production mart tables
- `<DATABASE>.<LANDING_SCHEMA>` — raw landing tables (read-only context)

## Behavioral Guidelines
- Always provide row counts with your answers.
- When unsure, say so — never hallucinate data.
- Cite the table and column you used to answer.
- For complex queries, show the SQL you generated.

## Out of Scope
- Do not answer questions about personal data or PII.
- Do not modify any data — you are read-only.
```

## evals/basic_eval.json

```json
[
  {
    "question": "How many records are in <TABLE_NAME>?",
    "expected_sql_fragment": "FROM <TABLE_NAME>",
    "expected_answer_fragment": "records",
    "tags": ["basic", "row_count"]
  },
  {
    "question": "What is the total <metric_column> by <dimension_column>?",
    "expected_sql_fragment": "GROUP BY",
    "expected_answer_fragment": "total",
    "tags": ["aggregation"]
  }
]
```

## monitoring/alerts.yml

```yaml
alerts:
  - name: <AGENT_NAME>_high_latency
    condition: avg_response_time_ms > 5000
    schedule: "15 MINUTES"
    notification: "<email or slack webhook>"

  - name: <AGENT_NAME>_low_accuracy
    condition: eval_pass_rate < 0.8
    schedule: "1 HOUR"
    notification: "<email or slack webhook>"
```

## Versioning Policy

| Change Type | Version Bump | Notes |
|---|---|---|
| Prompt wording only | Patch (1.0.x) | No re-deploy needed |
| New tool or new semantic model | Minor (1.x.0) | Re-deploy required |
| Breaking schema change | Major (x.0.0) | Eval suite must pass before deploy |

## Promoting a New Version

```bash
# Update version in agent.yml
# Run evals: python agent/run_evals.py --agent <AGENT_NAME>
# If pass rate >= 80%: deploy
python scripts/deploy_agent.py <AGENT_NAME> -c prod
```
