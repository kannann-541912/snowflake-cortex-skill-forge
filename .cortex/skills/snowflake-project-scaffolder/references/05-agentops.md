# AgentOps Reference

## agent/deploy_all.py

```python
"""agent/deploy_all.py — Deploy or list all Snowflake Cortex Agents."""
import argparse, glob, subprocess, sys
from pathlib import Path


def get_agents():
    return [Path(p).parent for p in glob.glob("agent/agents/*/agent.yml")]


def deploy(agent_dir: Path, dry_run: bool, connection: str):
    cmd = ["snow", "cortex", "agent", "deploy",
           "--spec", str(agent_dir / "agent.yml"),
           "--connection", connection]
    if dry_run:
        cmd.append("--dry-run")
    print(f"{'[DRY-RUN] ' if dry_run else ''}Deploying {agent_dir.name}...")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  FAILED: {result.stderr.strip()}", file=sys.stderr)
        return False
    print(f"  OK: {result.stdout.strip()}")
    return True


def main():
    parser = argparse.ArgumentParser(description="Deploy all Cortex Agents")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("-c", "--connection", default="default")
    args = parser.parse_args()

    agents = get_agents()
    if not agents:
        print("No agents found in agent/agents/")
        return

    if args.list:
        for a in agents:
            print(f"  {a.name}")
        return

    failed = [a for a in agents if not deploy(a, args.dry_run, args.connection)]
    if failed:
        print(f"\n{len(failed)} agent(s) failed to deploy.", file=sys.stderr)
        sys.exit(1)
    print(f"\nAll {len(agents)} agent(s) deployed successfully.")


if __name__ == "__main__":
    main()
```

## agent/run_evals.py

```python
"""agent/run_evals.py — Run evaluation suites for all agents."""
import argparse, json, subprocess, sys
from pathlib import Path


def run_evals(agent_dir: Path, connection: str) -> dict:
    eval_dir = agent_dir / "evals"
    if not eval_dir.exists():
        return {"agent": agent_dir.name, "skipped": True, "reason": "no evals directory"}

    results = []
    for test_file in sorted(eval_dir.glob("*.json")):
        cmd = ["snow", "cortex", "agent", "eval",
               "--agent", agent_dir.name,
               "--test", str(test_file),
               "--connection", connection]
        result = subprocess.run(cmd, capture_output=True, text=True)
        results.append({
            "test": test_file.name,
            "passed": result.returncode == 0,
            "output": result.stdout.strip()
        })

    passed = sum(1 for r in results if r["passed"])
    return {"agent": agent_dir.name, "passed": passed, "total": len(results), "results": results}


def main():
    parser = argparse.ArgumentParser(description="Run agent evals")
    parser.add_argument("-c", "--connection", default="default")
    parser.add_argument("--agent", help="Run evals for a specific agent only")
    args = parser.parse_args()

    agents = [Path(p).parent for p in Path("agent/agents").glob("*/agent.yml")]
    if args.agent:
        agents = [a for a in agents if a.name == args.agent]

    all_results = [run_evals(a, args.connection) for a in agents]
    print(json.dumps(all_results, indent=2))

    failed = [r for r in all_results if not r.get("skipped") and r["passed"] < r["total"]]
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
```

## Agent Stub — agent/agents/{AGENT_NAME}/agent.yml

Only generate this if the user requested an initial agent stub in the wizard.

```yaml
# agent/agents/{AGENT_NAME}/agent.yml
name: {AGENT_NAME}
version: "1.0.0"
description: "{AGENT_DESCRIPTION}"
model: snowflake-arctic
warehouse: {WAREHOUSE}
max_tokens: 4096

tools:
  - name: execute_sql
    type: CORTEX_ANALYST
    warehouse: {WAREHOUSE}
    semantic_model: ""   # TODO: link your semantic model

instructions: |
  You are a data analyst assistant for {PROJECT_NAME_TITLE}.
  Answer questions about the data in {DATABASE}.{SCHEMA}.
  Always cite your sources and include row counts in your response.
```

## Agent Stub — agent/agents/{AGENT_NAME}/evals/sample_eval.json

```json
[
  {
    "question": "How many records are in {TABLE_NAME}?",
    "expected_sql_fragment": "FROM {TABLE_NAME}",
    "expected_answer_fragment": "records"
  }
]
```
