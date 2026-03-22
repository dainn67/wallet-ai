#!/bin/bash
# AXe CLI Wrapper — normalizes all AXe CLI output to standardized JSON API
# AD-3: Shell Wrapper Convention as Adapter Interface
# Usage: source this file and call the functions
# Requires: axe (brew tap cameroncooke/axe && brew install cameroncooke/axe/axe)
#           xcrun simctl (Xcode Command Line Tools)
set -euo pipefail

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _json_response <success: true|false> <error: string|null> <data: json|null>
# Outputs a standardized JSON response object.
_json_response() {
  local success="$1"
  local error="$2"
  local data="$3"

  if [ "$error" = "null" ]; then
    printf '{"success":%s,"error":null,"data":%s}\n' "$success" "$data"
  else
    # Escape double quotes in error string
    local escaped_error
    escaped_error=$(printf '%s' "$error" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
    printf '{"success":%s,"error":"%s","data":%s}\n' "$success" "$escaped_error" "$data"
  fi
}

# _check_axe_installed — returns JSON error if axe is not in PATH
_check_axe_installed() {
  if ! command -v axe &>/dev/null; then
    _json_response false "AXe CLI not found. Install with: brew tap cameroncooke/axe && brew install cameroncooke/axe/axe" null
    return 1
  fi
  return 0
}

# _get_booted_udid — finds first booted simulator UDID via xcrun simctl
# Outputs UDID string or empty string if none booted.
_get_booted_udid() {
  xcrun simctl list devices booted 2>/dev/null \
    | grep -E '^\s+.+\(.+\) \(Booted\)' \
    | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' \
    | head -1
}

# ---------------------------------------------------------------------------
# Public wrapper functions
# ---------------------------------------------------------------------------

# axe_screenshot <output_path> [udid]
# Captures a screenshot from the booted simulator.
# Returns: {"success": true, "data": {"path": "/abs/path.png"}}
axe_screenshot() {
  local output_path="${1:-}"
  local udid="${2:-}"

  _check_axe_installed || return 0

  if [ -z "$output_path" ]; then
    _json_response false "output_path argument is required" null
    return 0
  fi

  # Resolve UDID if not provided
  if [ -z "$udid" ]; then
    udid="$(_get_booted_udid)"
    if [ -z "$udid" ]; then
      _json_response false "No booted simulator found. Run: xcrun simctl boot <device>" null
      return 0
    fi
  fi

  local raw_output exit_code
  raw_output=$(axe screenshot --udid "$udid" --output "$output_path" 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    _json_response false "$raw_output" null
    return 0
  fi

  # Parse path from output — second line is the absolute path
  local saved_path
  saved_path=$(printf '%s' "$raw_output" | tail -1)
  if [ -z "$saved_path" ]; then
    saved_path="$output_path"
  fi

  _json_response true null "{\"path\":\"$saved_path\"}"
}

# axe_describe_ui [udid]
# Returns the full accessibility tree of the foreground app.
# Returns: {"success": true, "data": [...]}
axe_describe_ui() {
  local udid="${1:-}"

  _check_axe_installed || return 0

  if [ -z "$udid" ]; then
    udid="$(_get_booted_udid)"
    if [ -z "$udid" ]; then
      _json_response false "No booted simulator found. Run: xcrun simctl boot <device>" null
      return 0
    fi
  fi

  local raw_output exit_code
  raw_output=$(axe describe-ui --udid "$udid" 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    _json_response false "$raw_output" null
    return 0
  fi

  # Raw output is already a JSON array — wrap in success envelope
  printf '{"success":true,"error":null,"data":%s}\n' "$raw_output"
}

# axe_tap <label> [udid]
# Taps an element by its accessibility label.
# Returns: {"success": true, "data": {"x": N, "y": N}}
axe_tap() {
  local label="${1:-}"
  local udid="${2:-}"

  _check_axe_installed || return 0

  if [ -z "$label" ]; then
    _json_response false "label argument is required" null
    return 0
  fi

  if [ -z "$udid" ]; then
    udid="$(_get_booted_udid)"
    if [ -z "$udid" ]; then
      _json_response false "No booted simulator found. Run: xcrun simctl boot <device>" null
      return 0
    fi
  fi

  local raw_output exit_code
  raw_output=$(axe tap --label "$label" --udid "$udid" 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    # Extract error from "Error: ..." line
    local error_msg
    error_msg=$(printf '%s' "$raw_output" | grep '^Error:' | sed 's/^Error: //' | head -1)
    [ -z "$error_msg" ] && error_msg="$raw_output"
    _json_response false "$error_msg" null
    return 0
  fi

  # Parse "✓ Tap at (X, Y) completed successfully" for coordinates
  local x y
  x=$(printf '%s' "$raw_output" | grep -oE 'Tap at \([0-9.]+,' | grep -oE '[0-9.]+' | head -1)
  y=$(printf '%s' "$raw_output" | grep -oE ', [0-9.]+\)' | grep -oE '[0-9.]+' | head -1)

  if [ -n "$x" ] && [ -n "$y" ]; then
    _json_response true null "{\"x\":$x,\"y\":$y}"
  else
    _json_response true null "null"
  fi
}

# axe_tap_id <ax_unique_id> [udid]
# Taps an element by its AXUniqueId.
axe_tap_id() {
  local ax_id="${1:-}"
  local udid="${2:-}"

  _check_axe_installed || return 0

  if [ -z "$ax_id" ]; then
    _json_response false "ax_unique_id argument is required" null
    return 0
  fi

  if [ -z "$udid" ]; then
    udid="$(_get_booted_udid)"
    if [ -z "$udid" ]; then
      _json_response false "No booted simulator found. Run: xcrun simctl boot <device>" null
      return 0
    fi
  fi

  local raw_output exit_code
  raw_output=$(axe tap --id "$ax_id" --udid "$udid" 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    local error_msg
    error_msg=$(printf '%s' "$raw_output" | grep '^Error:' | sed 's/^Error: //' | head -1)
    [ -z "$error_msg" ] && error_msg="$raw_output"
    _json_response false "$error_msg" null
    return 0
  fi

  local x y
  x=$(printf '%s' "$raw_output" | grep -oE 'Tap at \([0-9.]+,' | grep -oE '[0-9.]+' | head -1)
  y=$(printf '%s' "$raw_output" | grep -oE ', [0-9.]+\)' | grep -oE '[0-9.]+' | head -1)

  if [ -n "$x" ] && [ -n "$y" ]; then
    _json_response true null "{\"x\":$x,\"y\":$y}"
  else
    _json_response true null "null"
  fi
}

# axe_type <text> [udid]
# Types text into the currently focused element.
# Note: Silent on success — type is always exit 0; text may be discarded if no field is focused.
# Returns: {"success": true}
axe_type() {
  local text="${1:-}"
  local udid="${2:-}"

  _check_axe_installed || return 0

  if [ -z "$text" ]; then
    _json_response false "text argument is required" null
    return 0
  fi

  if [ -z "$udid" ]; then
    udid="$(_get_booted_udid)"
    if [ -z "$udid" ]; then
      _json_response false "No booted simulator found. Run: xcrun simctl boot <device>" null
      return 0
    fi
  fi

  local raw_output exit_code
  raw_output=$(axe type "$text" --udid "$udid" 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    _json_response false "$raw_output" null
    return 0
  fi

  _json_response true null "null"
}

# axe_swipe <direction: up|down|left|right> [udid]
# Swipes in the specified direction using center-of-screen coordinates.
# Translates direction words to coordinate pairs for the 402x874pt logical screen.
# Returns: {"success": true}
axe_swipe() {
  local direction="${1:-}"
  local udid="${2:-}"

  _check_axe_installed || return 0

  # Validate direction
  case "$direction" in
    up|down|left|right) ;;
    *)
      _json_response false "Invalid swipe direction: '$direction'. Must be one of: up, down, left, right" null
      return 0
      ;;
  esac

  if [ -z "$udid" ]; then
    udid="$(_get_booted_udid)"
    if [ -z "$udid" ]; then
      _json_response false "No booted simulator found. Run: xcrun simctl boot <device>" null
      return 0
    fi
  fi

  # Translate direction to screen coordinates (402x874 logical points, center x=201)
  local start_x start_y end_x end_y
  case "$direction" in
    up)
      start_x=201; start_y=600; end_x=201; end_y=200
      ;;
    down)
      start_x=201; start_y=200; end_x=201; end_y=600
      ;;
    left)
      start_x=350; start_y=437; end_x=50; end_y=437
      ;;
    right)
      start_x=50; start_y=437; end_x=350; end_y=437
      ;;
  esac

  local raw_output exit_code
  raw_output=$(axe swipe \
    --start-x "$start_x" --start-y "$start_y" \
    --end-x "$end_x" --end-y "$end_y" \
    --udid "$udid" 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    _json_response false "$raw_output" null
    return 0
  fi

  _json_response true null "{\"direction\":\"$direction\"}"
}

# axe_batch <actions_json> [udid]
# Executes multiple non-dependent actions in sequence, returns array of results.
# Input: JSON array of actions: [{"type":"tap","target":"X"}, {"type":"screenshot","path":"/tmp/s.png"}]
# Returns: {"success": true, "data": {"results": [{...}, {...}], "total": N, "passed": M}}
# On individual action failure: continues remaining actions, marks failed ones in results.
axe_batch() {
  local actions_json="${1:-}"
  local udid="${2:-}"

  _check_axe_installed || return 0

  if [ -z "$actions_json" ]; then
    _json_response false "actions_json argument is required" null
    return 0
  fi

  if [ -z "$udid" ]; then
    udid="$(_get_booted_udid)"
    if [ -z "$udid" ]; then
      _json_response false "No booted simulator found. Run: xcrun simctl boot <device>" null
      return 0
    fi
  fi

  # Parse action count — number of objects in JSON array (one per line assumed after formatting)
  # Use python3 for reliable JSON parsing if available, else fall back to grep counting
  local action_count
  if command -v python3 &>/dev/null; then
    action_count=$(python3 -c "import json,sys; data=json.loads(sys.argv[1]); print(len(data))" "$actions_json" 2>/dev/null) || action_count=0
  else
    action_count=$(printf '%s' "$actions_json" | grep -o '"type"' | wc -l | tr -d ' ')
  fi

  if [ "$action_count" -eq 0 ]; then
    _json_response true null '{"results":[],"total":0,"passed":0}'
    return 0
  fi

  # Execute actions sequentially via python3 JSON parsing
  if command -v python3 &>/dev/null; then
    # Use python3 to parse each action and dispatch to wrapper functions
    local batch_result
    local py_exit=0
    batch_result=$(python3 - "$actions_json" "$udid" <<'PYEOF'
import json, subprocess, sys

actions = json.loads(sys.argv[1])
udid = sys.argv[2]
results = []
passed = 0

for i, action in enumerate(actions):
    action_type = action.get("type", "")
    result = {"index": i, "type": action_type, "success": False, "data": None, "error": None}

    try:
        if action_type == "tap":
            target = action.get("target", "")
            cmd = f"source scripts/qa/axe-wrapper.sh && axe_tap '{target}' '{udid}'"
            proc = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=30)
            resp = json.loads(proc.stdout.strip()) if proc.stdout.strip() else {"success": False, "error": "no output"}
        elif action_type == "tap_id":
            ax_id = action.get("id", "")
            cmd = f"source scripts/qa/axe-wrapper.sh && axe_tap_id '{ax_id}' '{udid}'"
            proc = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=30)
            resp = json.loads(proc.stdout.strip()) if proc.stdout.strip() else {"success": False, "error": "no output"}
        elif action_type == "type":
            text = action.get("text", "")
            cmd = f"source scripts/qa/axe-wrapper.sh && axe_type '{text}' '{udid}'"
            proc = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=30)
            resp = json.loads(proc.stdout.strip()) if proc.stdout.strip() else {"success": False, "error": "no output"}
        elif action_type == "swipe":
            direction = action.get("direction", "up")
            cmd = f"source scripts/qa/axe-wrapper.sh && axe_swipe '{direction}' '{udid}'"
            proc = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=30)
            resp = json.loads(proc.stdout.strip()) if proc.stdout.strip() else {"success": False, "error": "no output"}
        elif action_type == "screenshot":
            path = action.get("path", f"/tmp/screenshot_{i}.png")
            cmd = f"source scripts/qa/axe-wrapper.sh && axe_screenshot '{path}' '{udid}'"
            proc = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=30)
            resp = json.loads(proc.stdout.strip()) if proc.stdout.strip() else {"success": False, "error": "no output"}
        elif action_type == "describe_ui":
            cmd = f"source scripts/qa/axe-wrapper.sh && axe_describe_ui '{udid}'"
            proc = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=30)
            resp = json.loads(proc.stdout.strip()) if proc.stdout.strip() else {"success": False, "error": "no output"}
        else:
            resp = {"success": False, "error": f"Unknown action type: {action_type}"}

        result["success"] = resp.get("success", False)
        result["data"] = resp.get("data")
        result["error"] = resp.get("error")
        if result["success"]:
            passed += 1
    except subprocess.TimeoutExpired:
        result["success"] = False
        result["error"] = f"Action timed out after 30s"
    except Exception as e:
        result["success"] = False
        result["error"] = str(e)

    results.append(result)

total = len(results)
print(json.dumps({"results": results, "total": total, "passed": passed}))
PYEOF
    ) || py_exit=$?
    if [ "$py_exit" -eq 0 ] && [ -n "$batch_result" ]; then
      _json_response true null "$batch_result"
    else
      _json_response false "Batch execution failed" null
    fi
  else
    _json_response false "python3 required for axe_batch" null
  fi
}
