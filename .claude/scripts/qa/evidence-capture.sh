#!/bin/bash
# Evidence Capture — orchestrates per-step evidence collection
# AD-3: Shell Wrapper Convention as Adapter Interface
# Usage: source this file and call the functions
# Depends on: axe-wrapper.sh, simctl-wrapper.sh (sourced below)
set -euo pipefail

# ---------------------------------------------------------------------------
# Source dependencies — locate relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/qa/axe-wrapper.sh
source "$SCRIPT_DIR/axe-wrapper.sh"
# shellcheck source=scripts/qa/simctl-wrapper.sh
source "$SCRIPT_DIR/simctl-wrapper.sh"

# Evidence root: .claude/qa/evidence/ (relative to repo root)
EVIDENCE_ROOT=".claude/qa/evidence"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _evidence_json_response <success> <error> <data>
_evidence_json_response() {
  local success="$1"
  local error="$2"
  local data="$3"

  if [ "$error" = "null" ]; then
    printf '{"success":%s,"error":null,"data":%s}\n' "$success" "$data"
  else
    local escaped_error
    escaped_error=$(printf '%s' "$error" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
    printf '{"success":%s,"error":"%s","data":%s}\n' "$success" "$escaped_error" "$data"
  fi
}

# _ensure_dir <path>
# Creates directory if it doesn't exist. Returns 0 on success, 1 on failure.
_ensure_dir() {
  local dir="$1"
  mkdir -p "$dir" 2>/dev/null && return 0 || return 1
}

# _extract_json_field <json_string> <field>
# Extracts a string field from a JSON object using python3.
_extract_json_field() {
  local json="$1"
  local field="$2"
  printf '%s' "$json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field','') or '')" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# Public wrapper functions
# ---------------------------------------------------------------------------

# capture_step_evidence <run_id> <step_n> [adapter] [udid]
# Captures screenshot + accessibility tree for a single test step.
# Creates directory: .claude/qa/evidence/{run_id}/step-{step_n}/
# Returns: {"success": true, "data": {"dir": "...", "screenshot": "...", "accessibility_tree": "..."}}
capture_step_evidence() {
  local run_id="${1:-}"
  local step_n="${2:-}"
  # $3 = adapter (reserved for future adapters, currently only 'axe')
  local udid="${4:-}"

  if [ -z "$run_id" ]; then
    _evidence_json_response false "run_id argument is required" null
    return 0
  fi
  if [ -z "$step_n" ]; then
    _evidence_json_response false "step_n argument is required" null
    return 0
  fi

  local step_dir="${EVIDENCE_ROOT}/${run_id}/step-${step_n}"
  if ! _ensure_dir "$step_dir"; then
    _evidence_json_response false "Failed to create evidence directory: $step_dir" null
    return 0
  fi

  local screenshot_path="${step_dir}/screenshot.png"
  local tree_path="${step_dir}/accessibility-tree.json"

  # Capture screenshot
  local screenshot_result
  screenshot_result=$(axe_screenshot "$screenshot_path" "$udid")
  local screenshot_success
  screenshot_success=$(printf '%s' "$screenshot_result" | python3 -c "import sys,json; print(json.load(sys.stdin)['success'])" 2>/dev/null || echo "False")
  if [ "$screenshot_success" != "True" ]; then
    local err
    err=$(printf '%s' "$screenshot_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','unknown'))" 2>/dev/null || echo "unknown")
    _evidence_json_response false "Screenshot failed: $err" null
    return 0
  fi

  # Capture accessibility tree
  local tree_result
  tree_result=$(axe_describe_ui "$udid")
  local tree_success
  tree_success=$(printf '%s' "$tree_result" | python3 -c "import sys,json; print(json.load(sys.stdin)['success'])" 2>/dev/null || echo "False")
  if [ "$tree_success" != "True" ]; then
    local err
    err=$(printf '%s' "$tree_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','unknown'))" 2>/dev/null || echo "unknown")
    _evidence_json_response false "Accessibility tree capture failed: $err" null
    return 0
  fi

  # Write accessibility tree to file
  printf '%s' "$tree_result" | python3 -c "
import sys, json
envelope = json.load(sys.stdin)
data = envelope.get('data', [])
with open('$tree_path', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null

  local escaped_dir escaped_ss escaped_tree
  escaped_dir=$(printf '%s' "$step_dir" | sed 's/"/\\"/g')
  escaped_ss=$(printf '%s' "$screenshot_path" | sed 's/"/\\"/g')
  escaped_tree=$(printf '%s' "$tree_path" | sed 's/"/\\"/g')

  _evidence_json_response true null \
    "{\"dir\":\"$escaped_dir\",\"screenshot\":\"$escaped_ss\",\"accessibility_tree\":\"$escaped_tree\"}"
}

# capture_before_after <run_id> <step_n> <action_type> <action_arg> [udid]
# Captures before-state, executes an action, then captures after-state.
#
# action_type: tap | tap_id | type | swipe
# action_arg: label (for tap), ax_id (for tap_id), text (for type), direction (for swipe)
#
# Returns: {
#   "success": true,
#   "data": {
#     "before": {"screenshot": "...", "accessibility_tree": "..."},
#     "action": {"type": "...", "arg": "...", "result": {...}},
#     "after":  {"screenshot": "...", "accessibility_tree": "..."}
#   }
# }
capture_before_after() {
  local run_id="${1:-}"
  local step_n="${2:-}"
  local action_type="${3:-}"
  local action_arg="${4:-}"
  local udid="${5:-}"

  if [ -z "$run_id" ] || [ -z "$step_n" ] || [ -z "$action_type" ] || [ -z "$action_arg" ]; then
    _evidence_json_response false "run_id, step_n, action_type, and action_arg are all required" null
    return 0
  fi

  local step_dir="${EVIDENCE_ROOT}/${run_id}/step-${step_n}"
  if ! _ensure_dir "$step_dir"; then
    _evidence_json_response false "Failed to create evidence directory: $step_dir" null
    return 0
  fi

  # --- Before state ---
  local before_ss="${step_dir}/before-screenshot.png"
  local before_tree="${step_dir}/before-accessibility-tree.json"

  local before_ss_result before_ss_ok
  before_ss_result=$(axe_screenshot "$before_ss" "$udid")
  before_ss_ok=$(printf '%s' "$before_ss_result" | python3 -c "import sys,json; print(json.load(sys.stdin)['success'])" 2>/dev/null || echo "False")
  if [ "$before_ss_ok" != "True" ]; then
    local err
    err=$(printf '%s' "$before_ss_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','?'))" 2>/dev/null || echo "?")
    _evidence_json_response false "Before screenshot failed: $err" null
    return 0
  fi

  local before_tree_result
  before_tree_result=$(axe_describe_ui "$udid")
  printf '%s' "$before_tree_result" | python3 -c "
import sys, json
envelope = json.load(sys.stdin)
data = envelope.get('data', [])
with open('$before_tree', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null

  # --- Execute action ---
  local action_result
  case "$action_type" in
    tap)
      action_result=$(axe_tap "$action_arg" "$udid")
      ;;
    tap_id)
      action_result=$(axe_tap_id "$action_arg" "$udid")
      ;;
    type)
      action_result=$(axe_type "$action_arg" "$udid")
      ;;
    swipe)
      action_result=$(axe_swipe "$action_arg" "$udid")
      ;;
    *)
      _evidence_json_response false "Unknown action_type: '$action_type'. Must be: tap, tap_id, type, swipe" null
      return 0
      ;;
  esac

  # --- After state ---
  local after_ss="${step_dir}/after-screenshot.png"
  local after_tree="${step_dir}/after-accessibility-tree.json"

  local after_ss_result after_ss_ok
  after_ss_result=$(axe_screenshot "$after_ss" "$udid")
  after_ss_ok=$(printf '%s' "$after_ss_result" | python3 -c "import sys,json; print(json.load(sys.stdin)['success'])" 2>/dev/null || echo "False")
  if [ "$after_ss_ok" != "True" ]; then
    local err
    err=$(printf '%s' "$after_ss_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','?'))" 2>/dev/null || echo "?")
    _evidence_json_response false "After screenshot failed: $err" null
    return 0
  fi

  local after_tree_result
  after_tree_result=$(axe_describe_ui "$udid")
  printf '%s' "$after_tree_result" | python3 -c "
import sys, json
envelope = json.load(sys.stdin)
data = envelope.get('data', [])
with open('$after_tree', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null

  # --- Assemble result JSON ---
  local escaped_step_dir
  escaped_step_dir=$(printf '%s' "$step_dir" | sed 's/"/\\"/g')
  local escaped_action_type escaped_action_arg
  escaped_action_type=$(printf '%s' "$action_type" | sed 's/"/\\"/g')
  escaped_action_arg=$(printf '%s' "$action_arg" | sed 's/"/\\"/g')

  # Inline action_result (already valid JSON)
  printf '{"success":true,"error":null,"data":{"dir":"%s","before":{"screenshot":"%s","accessibility_tree":"%s"},"action":{"type":"%s","arg":"%s","result":%s},"after":{"screenshot":"%s","accessibility_tree":"%s"}}}\n' \
    "$escaped_step_dir" \
    "${step_dir}/before-screenshot.png" \
    "${step_dir}/before-accessibility-tree.json" \
    "$escaped_action_type" \
    "$escaped_action_arg" \
    "$action_result" \
    "${step_dir}/after-screenshot.png" \
    "${step_dir}/after-accessibility-tree.json"
}

# cleanup_old_evidence <retention_count>
# Removes oldest evidence run directories beyond the retention count.
# Returns: {"success": true, "data": {"removed": N, "retained": N}}
cleanup_old_evidence() {
  local retention_count="${1:-}"

  if [ -z "$retention_count" ]; then
    _evidence_json_response false "retention_count argument is required" null
    return 0
  fi

  if ! [[ "$retention_count" =~ ^[0-9]+$ ]]; then
    _evidence_json_response false "retention_count must be a non-negative integer" null
    return 0
  fi

  if [ ! -d "$EVIDENCE_ROOT" ]; then
    _evidence_json_response true null '{"removed":0,"retained":0}'
    return 0
  fi

  # List run directories sorted by modification time (oldest first)
  local all_dirs
  mapfile -t all_dirs < <(find "$EVIDENCE_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 stat -f "%m %N" 2>/dev/null | sort -n | awk '{print $2}' || find "$EVIDENCE_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)

  local total_count=${#all_dirs[@]}
  local to_remove=$(( total_count - retention_count ))

  if [ "$to_remove" -le 0 ]; then
    _evidence_json_response true null "{\"removed\":0,\"retained\":$total_count}"
    return 0
  fi

  local removed=0
  for (( i=0; i<to_remove; i++ )); do
    local dir="${all_dirs[$i]}"
    if [ -d "$dir" ]; then
      rm -rf "$dir" 2>/dev/null && (( removed++ )) || true
    fi
  done

  local retained=$(( total_count - removed ))
  _evidence_json_response true null "{\"removed\":$removed,\"retained\":$retained}"
}
