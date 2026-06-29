#!/usr/bin/env bash
# pipeline-state.sh — State machine for de-pipeline-plugin
#
# Usage: bash hooks/pipeline-state.sh <command>
# Commands: init | resume | check-order | check-refs | advance | status | mark-refs-read | reset
#
# Compatible with bash 3.x (macOS system bash)
# Requires: jq
# State file: state/pipeline_state.json (gitignored)

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${PLUGIN_DIR}/state/pipeline_state.json"

# ─────────────────────────────────────────────
# Phase metadata (case-statement based, bash 3 compatible)
# ─────────────────────────────────────────────

phase_index() {
  case "$1" in
    de-profile)           echo 0 ;;
    de-schema-design)     echo 1 ;;
    de-schema-setup)      echo 2 ;;
    de-transform-setup)   echo 3 ;;
    de-load-validate)     echo 4 ;;
    de-transform)         echo 5 ;;
    de-share)             echo 6 ;;
    *)                    echo -1 ;;
  esac
}

phase_name_at() {
  case "$1" in
    0) echo "de-profile" ;;
    1) echo "de-schema-design" ;;
    2) echo "de-schema-setup" ;;
    3) echo "de-transform-setup" ;;
    4) echo "de-load-validate" ;;
    5) echo "de-transform" ;;
    6) echo "de-share" ;;
    *) echo "" ;;
  esac
}

phase_artifact() {
  case "$1" in
    de-profile)           echo "profile_report.md" ;;
    de-schema-design)     echo "schema_design.md" ;;
    de-schema-setup)      echo "schema_setup.sql" ;;
    de-transform-setup)   echo "transform_mappings.yml" ;;
    de-load-validate)     echo "(rows loaded + alert active)" ;;
    de-transform)         echo "(mart table running)" ;;
    de-share)             echo "governance_report.md" ;;
    *)                    echo "" ;;
  esac
}

is_phase_skill() {
  local idx
  idx=$(phase_index "$1")
  [ "$idx" -ge 0 ]
}

# ─────────────────────────────────────────────
# State file helpers
# ─────────────────────────────────────────────

ensure_state_file() {
  mkdir -p "${PLUGIN_DIR}/state"
  if [ ! -f "${STATE_FILE}" ]; then
    init_state_file
  fi
}

init_state_file() {
  jq -n '{
    current_phase: 0,
    phases_completed: [],
    refs_read: false,
    session_started_at: null,
    artifacts: {}
  }' > "${STATE_FILE}"
}

get_current_phase() {
  jq -r '.current_phase' "${STATE_FILE}"
}

get_refs_read() {
  jq -r '.refs_read' "${STATE_FILE}"
}

get_completed_count() {
  jq '.phases_completed | length' "${STATE_FILE}"
}

# ─────────────────────────────────────────────
# Commands
# ─────────────────────────────────────────────

cmd_init() {
  mkdir -p "${PLUGIN_DIR}/state"
  init_state_file
  echo "[de-pipeline] State initialised. Run \$de-profile to begin Phase 1."
}

cmd_resume() {
  ensure_state_file

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Stamp session start
  local tmp
  tmp=$(jq --arg t "$now" '.session_started_at = $t' "${STATE_FILE}")
  echo "$tmp" > "${STATE_FILE}"

  local phase
  phase=$(get_current_phase)
  local completed_count
  completed_count=$(get_completed_count)
  local total=7

  if [ "$completed_count" -eq 0 ]; then
    echo "[de-pipeline] New session. No phases completed yet."
    echo "[de-pipeline] Start with: \$de-profile"
  else
    local completed_list
    completed_list=$(jq -r '.phases_completed[]' "${STATE_FILE}" | paste -sd ',' -)
    echo "[de-pipeline] Session resumed."
    echo "[de-pipeline] Phases completed (${completed_count}/${total}): ${completed_list}"

    if [ "$phase" -lt "$total" ]; then
      local next_skill
      next_skill=$(phase_name_at "$phase")
      echo "[de-pipeline] Next phase: \$${next_skill}"
    else
      echo "[de-pipeline] All 7 phases complete. Pipeline done."
    fi

    # Print artifact chain
    local artifacts_count
    artifacts_count=$(jq '.artifacts | length' "${STATE_FILE}")
    if [ "$artifacts_count" -gt 0 ]; then
      echo "[de-pipeline] Artifact chain:"
      jq -r '.artifacts | to_entries[] | "  - \(.key): \(.value)"' "${STATE_FILE}"
    fi
  fi
}

cmd_check_order() {
  ensure_state_file

  # CoCo runtime sets COCO_SKILL_NAME for the currently invoked skill
  local requested_skill="${COCO_SKILL_NAME:-}"
  if [ -z "$requested_skill" ]; then
    exit 0  # unknown invocation — fail open
  fi

  # Strip plugin namespace prefix if present (e.g. "de-pipeline-plugin/de-profile" → "de-profile")
  requested_skill="${requested_skill##*/}"

  # Check if it's a governed phase skill
  if ! is_phase_skill "$requested_skill"; then
    exit 0  # not a phase skill — allow through
  fi

  local requested_idx
  requested_idx=$(phase_index "$requested_skill")
  local current
  current=$(get_current_phase)

  if [ "$requested_idx" -gt "$current" ]; then
    local blocker
    blocker=$(phase_name_at "$current")
    echo "[de-pipeline] BLOCKED: Cannot run \$${requested_skill} (Phase $((requested_idx + 1))) before completing \$${blocker} (Phase $((current + 1)))."
    echo "[de-pipeline] Complete Phase $((current + 1)) first: \$${blocker}"
    echo "[de-pipeline] Check current state: bash hooks/pipeline-state.sh status"
    exit 2
  fi

  exit 0
}

cmd_check_refs() {
  ensure_state_file

  local refs_status
  refs_status=$(get_refs_read)

  if [ "$refs_status" != "true" ]; then
    echo "[de-pipeline] BLOCKED: Cannot write files before reading client context."
    echo "[de-pipeline] Action: Read ../../references/client-context.md first."
    echo "[de-pipeline] Then run: bash hooks/pipeline-state.sh mark-refs-read"
    exit 2
  fi

  exit 0
}

cmd_advance() {
  ensure_state_file

  local skill="${COCO_SKILL_NAME:-}"
  skill="${skill##*/}"

  if [ -z "$skill" ] || ! is_phase_skill "$skill"; then
    exit 0
  fi

  local phase_idx
  phase_idx=$(phase_index "$skill")
  local current
  current=$(get_current_phase)

  # Only advance forward if this is the current phase
  if [ "$phase_idx" -eq "$current" ]; then
    local next=$((current + 1))
    local artifact
    artifact=$(phase_artifact "$skill")
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp
    tmp=$(jq \
      --arg skill "$skill" \
      --arg artifact "$artifact" \
      --arg ts "$now" \
      --argjson next "$next" \
      '.current_phase = $next
       | .phases_completed += [$skill]
       | .artifacts[$skill] = $artifact
       | .refs_read = true' \
      "${STATE_FILE}")
    echo "$tmp" > "${STATE_FILE}"

    echo "[de-pipeline] Phase $((phase_idx + 1))/7 complete: \$${skill} → ${artifact}"

    if [ "$next" -lt 7 ]; then
      local next_skill
      next_skill=$(phase_name_at "$next")
      echo "[de-pipeline] Next: \$${next_skill}"
    else
      echo "[de-pipeline] All 7 phases complete. Run \$de-workflow to generate pipeline_summary.md."
    fi
  else
    # Re-run of a past phase — just mark refs as read
    local tmp
    tmp=$(jq '.refs_read = true' "${STATE_FILE}")
    echo "$tmp" > "${STATE_FILE}"
  fi

  exit 0
}

cmd_status() {
  ensure_state_file

  local phase
  phase=$(get_current_phase)
  local total=7
  local completed_count
  completed_count=$(get_completed_count)

  local next_label="done"
  if [ "$phase" -lt "$total" ]; then
    local next_skill
    next_skill=$(phase_name_at "$phase")
    next_label="\$${next_skill}"
  fi

  printf "[de-pipeline] Phase: %d/%d | Completed: %d | Next: %s\n" \
    "$phase" "$total" "$completed_count" "$next_label"
}

cmd_mark_refs_read() {
  ensure_state_file
  local tmp
  tmp=$(jq '.refs_read = true' "${STATE_FILE}")
  echo "$tmp" > "${STATE_FILE}"
  echo "[de-pipeline] Client context marked as read. Write gate is now open."
}

# ─────────────────────────────────────────────
# Dispatch
# ─────────────────────────────────────────────

COMMAND="${1:-status}"

case "$COMMAND" in
  init)            cmd_init ;;
  resume)          cmd_resume ;;
  check-order)     cmd_check_order ;;
  check-refs)      cmd_check_refs ;;
  advance)         cmd_advance ;;
  status)          cmd_status ;;
  mark-refs-read)  cmd_mark_refs_read ;;
  reset)
    rm -f "${STATE_FILE}"
    cmd_init
    echo "[de-pipeline] State reset to Phase 0."
    ;;
  *)
    echo "Usage: bash hooks/pipeline-state.sh <command>"
    echo "Commands: init | resume | check-order | check-refs | advance | status | mark-refs-read | reset"
    exit 1
    ;;
esac
