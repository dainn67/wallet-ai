#!/usr/bin/env bash
# Reflection generator for ace-learning: creates structured reflection files on verify-run failure.
#
# Usage:
#   source .claude/scripts/pm/reflection-generate.sh
#   get_attempt_number <epic_name> <issue_number>
#   get_reflection_history <epic_name> <issue_number>
#   generate_reflection <epic_name> <issue_number>
#
# Or run as standalone:
#   bash .claude/scripts/pm/reflection-generate.sh get-attempt-number <epic> <issue>
#   bash .claude/scripts/pm/reflection-generate.sh get-reflection-history <epic> <issue>
#   bash .claude/scripts/pm/reflection-generate.sh generate-reflection <epic> <issue>

if [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
  set -euo pipefail
else
  set -uo pipefail
fi

_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"

# Source lifecycle helpers for ace_feature_enabled, ace_log, read_verify_state
_LH="$_CCPM_ROOT/scripts/pm/lifecycle-helpers.sh"
if [ -f "$_LH" ]; then
  # shellcheck source=lifecycle-helpers.sh
  source "$_LH" 2>/dev/null || true
fi

# Return the NEXT attempt number for a given task (count existing + 1).
# Args: epic_name issue_number
# Output: integer to stdout (minimum 1)
get_attempt_number() {
  local epic="${1:?Usage: get_attempt_number <epic_name> <issue_number>}"
  local issue="${2:?Usage: get_attempt_number <epic_name> <issue_number>}"
  local reflections_dir="$_CCPM_ROOT/epics/${epic}/reflections"
  local count=0

  if [ -d "$reflections_dir" ]; then
    count=$(find "$reflections_dir" -maxdepth 1 -name "task-${issue}-attempt-*.md" 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo $(( count + 1 ))
}

# Return concatenated content of all reflection files for a task in order.
# Args: epic_name issue_number
# Output: combined markdown to stdout, or empty string if none exist
get_reflection_history() {
  local epic="${1:?Usage: get_reflection_history <epic_name> <issue_number>}"
  local issue="${2:?Usage: get_reflection_history <epic_name> <issue_number>}"
  local reflections_dir="$_CCPM_ROOT/epics/${epic}/reflections"

  if [ ! -d "$reflections_dir" ]; then
    return 0
  fi

  local files
  files=$(find "$reflections_dir" -maxdepth 1 -name "task-${issue}-attempt-*.md" 2>/dev/null | sort)

  if [ -z "$files" ]; then
    return 0
  fi

  local first=true
  while IFS= read -r f; do
    if [ -f "$f" ]; then
      if [ "$first" = "true" ]; then
        first=false
      else
        echo ""
        echo "---"
        echo ""
      fi
      cat "$f"
    fi
  done <<< "$files"
}

# Generate a structured reflection file after a verify-run failure.
# Args: epic_name issue_number
# Output: path to generated reflection file on stdout
# Returns: 0 on success or skipped, 1 on error
generate_reflection() {
  local epic="${1:?Usage: generate_reflection <epic_name> <issue_number>}"
  local issue="${2:?Usage: generate_reflection <epic_name> <issue_number>}"

  # Check if reflection feature is enabled
  if command -v ace_feature_enabled &>/dev/null; then
    if ! ace_feature_enabled "reflection"; then
      return 0
    fi
  fi

  local attempt
  attempt=$(get_attempt_number "$epic" "$issue")

  # Gather inputs
  local verify_log="$_CCPM_ROOT/context/verify/results/task-${issue}-verify.log"
  local task_file="$_CCPM_ROOT/epics/${epic}/${issue}.md"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Verify report section
  local what_failed
  if [ -f "$verify_log" ]; then
    # Extract failure signals — last 50 lines to keep it focused
    what_failed=$(tail -50 "$verify_log" 2>/dev/null || echo "")
    if [ -z "$what_failed" ]; then
      what_failed="Verify log exists but is empty — check task manually."
    fi
  else
    what_failed="Verify log unavailable — check task manually."
  fi

  # Git diff section — recent changes
  local git_diff
  git_diff=$(cd "$_CCPM_ROOT" && git diff HEAD~3 HEAD --name-only 2>/dev/null || echo "")
  if [ -z "$git_diff" ]; then
    git_diff="No changes detected in last 3 commits."
  fi

  # Acceptance criteria from task file
  local acceptance_criteria
  if [ -f "$task_file" ]; then
    acceptance_criteria=$(grep -A 999 '## Acceptance Criteria' "$task_file" 2>/dev/null | grep -B 999 '## ' | head -30 | tail -n +2 | sed '/^## /d' || echo "")
    if [ -z "$acceptance_criteria" ]; then
      acceptance_criteria="Acceptance criteria section not found in task file."
    fi
  else
    acceptance_criteria="Task file not found: epics/${epic}/${issue}.md"
  fi

  # Current verify iteration from state.json
  local current_iteration="unknown"
  if command -v read_verify_state &>/dev/null; then
    local state_json
    state_json=$(read_verify_state 2>/dev/null || echo '{"active_task":null}')
    current_iteration=$(echo "$state_json" | python3 -c "
import json, sys
try:
  d = json.load(sys.stdin)
  at = d.get('active_task') or {}
  print(at.get('current_iteration', 'unknown'))
except:
  print('unknown')
" 2>/dev/null || echo "unknown")
  fi

  # Create reflections directory
  local reflections_dir="$_CCPM_ROOT/epics/${epic}/reflections"
  mkdir -p "$reflections_dir" 2>/dev/null || true

  local out_file="$reflections_dir/task-${issue}-attempt-${attempt}.md"

  # Generate structured reflection content
  cat > "$out_file" <<REFLECTION
# Attempt ${attempt} Reflection
**Task:** epic/${epic}#${issue}
**Date:** ${ts}
**Verify iteration:** ${current_iteration}

## What failed
\`\`\`
${what_failed}
\`\`\`

## Root cause analysis
Based on recent changes and error signals above, identify what likely caused the failure.

Files changed in last 3 commits:
\`\`\`
${git_diff}
\`\`\`

## Approach change for next attempt
- Review each failing acceptance criterion above individually
- Cross-check changed files against task requirements
- Ensure all acceptance criteria have explicit test coverage or manual verification

## Files to focus on
Task acceptance criteria (from task file):
${acceptance_criteria}

Changed files listed above under "Root cause analysis".
REFLECTION

  # Log the reflection event
  if command -v ace_log &>/dev/null; then
    ace_log "REFLECT" "attempt=${attempt} task=epic/${epic}#${issue} file=epics/${epic}/reflections/task-${issue}-attempt-${attempt}.md"
  fi

  echo "$out_file"
}

# CLI interface — run commands directly
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    get-attempt-number)    get_attempt_number "$@" ;;
    get-reflection-history) get_reflection_history "$@" ;;
    generate-reflection)   generate_reflection "$@" ;;
    *)
      echo "Usage: $0 <command> [args...]"
      echo "Commands: get-attempt-number, get-reflection-history, generate-reflection"
      exit 1
      ;;
  esac
fi
