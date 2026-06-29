# Utility Scripts Reference

## scripts/check_naming.py

```python
"""scripts/check_naming.py — Lint Snowflake SQL files for naming convention violations."""
import re, sys
from pathlib import Path

ERRORS = []

def check(path: Path, pattern: re.Pattern, rule: str):
    text = path.read_text()
    for i, line in enumerate(text.splitlines(), 1):
        if pattern.search(line):
            ERRORS.append(f"{path}:{i}: {rule}  →  {line.strip()}")


for sql_file in Path(".").rglob("*.sql"):
    # Tables must be UPPER_SNAKE_CASE
    for m in re.finditer(r'\bCREATE\s+(?:OR\s+REPLACE\s+)?(?:TABLE|VIEW|STREAM|TASK)\s+(\w+)', sql_file.read_text(), re.IGNORECASE):
        name = m.group(1)
        if name != name.upper():
            ERRORS.append(f"{sql_file}: Object name '{name}' must be UPPER_SNAKE_CASE")

    # No CREATE OR REPLACE on tables (data loss risk)
    if re.search(r'CREATE\s+OR\s+REPLACE\s+TABLE', sql_file.read_text(), re.IGNORECASE):
        ERRORS.append(f"{sql_file}: CREATE OR REPLACE TABLE is forbidden — use CREATE TABLE IF NOT EXISTS")

    # No SELECT * in production SQL (except staging views)
    if 'staging' not in str(sql_file) and re.search(r'SELECT\s+\*\s+FROM', sql_file.read_text(), re.IGNORECASE):
        ERRORS.append(f"{sql_file}: SELECT * detected in non-staging SQL — enumerate columns explicitly")

if ERRORS:
    print(f"\n{len(ERRORS)} naming/convention violation(s):\n")
    for e in ERRORS:
        print(f"  ✗ {e}")
    sys.exit(1)
else:
    print("✓ All naming conventions pass")
```

## scripts/deploy_agent.py

```python
"""scripts/deploy_agent.py — Deploy a single agent by name."""
import argparse, subprocess, sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Deploy a single Cortex Agent")
    parser.add_argument("agent", help="Agent directory name under agent/agents/")
    parser.add_argument("-c", "--connection", default="default")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    spec = Path("agent", "agents", args.agent, "agent.yml")
    if not spec.exists():
        print(f"ERROR: {spec} not found", file=sys.stderr)
        sys.exit(1)

    cmd = ["snow", "cortex", "agent", "deploy", "--spec", str(spec), "--connection", args.connection]
    if args.dry_run:
        cmd.append("--dry-run")

    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
```

## scripts/validate_agent_spec.py

```python
"""scripts/validate_agent_spec.py — Validate all agent.yml specs before deploy."""
import sys
from pathlib import Path
import yaml

REQUIRED_FIELDS = {"name", "version", "model", "warehouse", "instructions"}
ERRORS = []

for spec_path in sorted(Path("agent/agents").rglob("agent.yml")):
    try:
        spec = yaml.safe_load(spec_path.read_text())
    except yaml.YAMLError as e:
        ERRORS.append(f"{spec_path}: YAML parse error — {e}")
        continue

    missing = REQUIRED_FIELDS - set(spec.keys())
    if missing:
        ERRORS.append(f"{spec_path}: Missing required fields: {sorted(missing)}")

    if spec.get("instructions", "").strip().startswith("TODO"):
        ERRORS.append(f"{spec_path}: instructions field starts with TODO — fill it in")

if ERRORS:
    print(f"\n{len(ERRORS)} validation error(s):\n")
    for e in ERRORS:
        print(f"  ✗ {e}")
    sys.exit(1)
else:
    print(f"✓ All agent specs valid ({len(list(Path('agent/agents').rglob('agent.yml')))} agents)")
```
