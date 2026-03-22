#!/usr/bin/env bash
# build-state.sh — State lifecycle management for pm:build orchestrator
#
# Functions: init_state, save_state, load_state, advance_step, get_current_step, _atomic_write
#
# Usage: source scripts/pm/build-state.sh && init_state "my-feature"

set -uo pipefail

_BUILD_STATE_DIR=".claude/context/build-state"
_BUILD_CONFIG="config/build.json"

# ---------------------------------------------------------------------------
# _validate_json <file>
#   Returns 0 if file is valid JSON, 1 otherwise.
# ---------------------------------------------------------------------------
_validate_json() {
  local file="$1"
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# _run_python <script_text> [args...]
#   Writes script to a tmp file and executes it. Cleans up tmp file.
# ---------------------------------------------------------------------------
_run_python() {
  local script_text="$1"
  shift
  local tmp_py
  tmp_py=$(mktemp /tmp/build-state.XXXXXX.py)
  printf '%s' "$script_text" > "$tmp_py"
  python3 "$tmp_py" "$@"
  local exit_code=$?
  rm -f "$tmp_py"
  return $exit_code
}

# ---------------------------------------------------------------------------
# _atomic_write <filepath> <content>
#   Writes content to filepath using atomic tmp→validate→mv pattern.
#   On validation failure: removes tmp, returns 1.
# ---------------------------------------------------------------------------
_atomic_write() {
  local filepath="$1"
  local content="$2"
  local tmp="${filepath}.tmp"

  printf '%s' "$content" > "$tmp"

  if ! _validate_json "$tmp"; then
    rm -f "$tmp"
    echo "❌ _atomic_write: invalid JSON — write aborted" >&2
    return 1
  fi

  mv "$tmp" "$filepath"
}

# ---------------------------------------------------------------------------
# init_state <feature>
#   Creates .claude/context/build-state/<feature>.json with all 10 steps pending.
# ---------------------------------------------------------------------------
init_state() {
  local feature="$1"

  if [ ! -f "$_BUILD_CONFIG" ]; then
    echo "❌ config/build.json not found" >&2
    return 1
  fi

  mkdir -p "$_BUILD_STATE_DIR"

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local py_init='
import json, sys
config_path, feature, now = sys.argv[1], sys.argv[2], sys.argv[3]
config = json.load(open(config_path))
steps = [
    {"name": s["name"], "status": "pending", "started": "", "completed": ""}
    for s in config["workflow"]["steps"]
]
state = {
    "feature": feature,
    "current_step": 0,
    "steps": steps,
    "gates_config": "default",
    "created": now,
    "updated": now
}
print(json.dumps(state, indent=2))
'

  local state_json
  state_json=$(_run_python "$py_init" "$_BUILD_CONFIG" "$feature" "$now") || return 1

  local target="${_BUILD_STATE_DIR}/${feature}.json"
  _atomic_write "$target" "$state_json" || return 1
  echo "✅ State initialized: $target"
}

# ---------------------------------------------------------------------------
# save_state <feature> <json_content>
#   Persists JSON content for feature using atomic write.
# ---------------------------------------------------------------------------
save_state() {
  local feature="$1"
  local json_content="$2"
  local target="${_BUILD_STATE_DIR}/${feature}.json"

  mkdir -p "$_BUILD_STATE_DIR"
  _atomic_write "$target" "$json_content" || return 1
}

# ---------------------------------------------------------------------------
# load_state <feature>
#   Validates and outputs state JSON to stdout. Exits 1 on error.
# ---------------------------------------------------------------------------
load_state() {
  local feature="$1"
  local target="${_BUILD_STATE_DIR}/${feature}.json"

  if [ ! -f "$target" ]; then
    echo "❌ State not found: $target" >&2
    return 1
  fi

  local py_load='
import json, sys
try:
    state = json.load(open(sys.argv[1]))
except Exception as e:
    sys.stderr.write("INVALID_JSON:" + str(e) + "\n")
    sys.exit(1)
required = {"feature", "current_step", "steps"}
missing = required - state.keys()
if missing:
    sys.stderr.write("SCHEMA_ERROR:missing keys " + str(sorted(missing)) + "\n")
    sys.exit(1)
steps = state["steps"]
if not isinstance(steps, list) or len(steps) == 0:
    sys.stderr.write("SCHEMA_ERROR:steps must be a non-empty array\n")
    sys.exit(1)
current = state["current_step"]
if not isinstance(current, int) or current < 0 or current > len(steps):
    sys.stderr.write("SCHEMA_ERROR:current_step " + str(current) + " out of bounds (0-" + str(len(steps)) + ")\n")
    sys.exit(1)
print(json.dumps(state, indent=2))
'

  local result
  result=$(_run_python "$py_load" "$target" 2>&1)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    echo "❌ load_state: invalid state — $result" >&2
    return 1
  fi

  echo "$result"
}

# ---------------------------------------------------------------------------
# advance_step <feature>
#   Increments current_step, updates step statuses and timestamps.
# ---------------------------------------------------------------------------
advance_step() {
  local feature="$1"
  local target="${_BUILD_STATE_DIR}/${feature}.json"

  local current_json
  current_json=$(load_state "$feature") || return 1

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local py_advance='
import json, sys
state = json.loads(sys.argv[1])
now = sys.argv[2]
idx = state["current_step"]
steps = state["steps"]
if idx < len(steps):
    steps[idx]["status"] = "complete"
    steps[idx]["completed"] = now
idx += 1
state["current_step"] = idx
if idx < len(steps):
    steps[idx]["status"] = "in-progress"
    steps[idx]["started"] = now
state["updated"] = now
print(json.dumps(state, indent=2))
'

  local new_json
  new_json=$(_run_python "$py_advance" "$current_json" "$now") || return 1

  _atomic_write "$target" "$new_json" || return 1

  local new_step
  new_step=$(python3 -c "import json,sys; s=json.loads(sys.argv[1]); print(s['current_step'])" "$new_json")
  echo "✅ Advanced to step $new_step"
}

# ---------------------------------------------------------------------------
# get_current_step <feature>
#   Outputs current step name and status.
# ---------------------------------------------------------------------------
get_current_step() {
  local feature="$1"

  local current_json
  current_json=$(load_state "$feature") || return 1

  local py_get='
import json, sys
state = json.loads(sys.argv[1])
idx = state["current_step"]
steps = state["steps"]
if idx < len(steps):
    step = steps[idx]
    print("step: " + step["name"])
    print("status: " + step["status"])
else:
    print("step: (complete -- no more steps)")
    print("status: done")
'

  _run_python "$py_get" "$current_json"
}
