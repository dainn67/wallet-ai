#!/usr/bin/env bash
# test-build-state.sh — Unit tests for scripts/pm/build-state.sh
#
# Usage: bash tests/integration/epic_dx-hardening/test-build-state.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

# Source functions under test
# shellcheck source=../../../scripts/pm/build-state.sh
source scripts/pm/build-state.sh

PASS=0
FAIL=0
TOTAL=0

# --- Helpers ---

run_test() {
  local name="$1"
  TOTAL=$((TOTAL + 1))
  echo ""
  echo "── Test $TOTAL: $name ──"
}

assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "  ✅ $label (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local output="$1" pattern="$2" label="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — pattern '$pattern' not found in output"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_exists() {
  local file="$1" label="$2"
  if [ ! -f "$file" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — file still exists: $file"
    FAIL=$((FAIL + 1))
  fi
}

# Cleanup helper
FEATURE="test-build-state-$$"
STATE_FILE=".claude/context/build-state/${FEATURE}.json"

cleanup() {
  rm -f "$STATE_FILE" "${STATE_FILE}.tmp"
  rm -f ".claude/context/build-state/nonexistent.json" 2>/dev/null || true
}
trap cleanup EXIT

# --- Tests ---

run_test "init_state creates valid JSON with 10 steps all pending"
init_state "$FEATURE" >/dev/null 2>&1
init_exit=$?
assert_exit 0 "$init_exit" "init_state exits 0"
if [ -f "$STATE_FILE" ]; then
  step_count=$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(len(s['steps']))")
  pending_count=$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(sum(1 for st in s['steps'] if st['status']=='pending'))")
  current=$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(s['current_step'])")
  assert_contains "$step_count" "10" "10 steps created"
  assert_contains "$pending_count" "10" "all 10 steps are pending"
  assert_contains "$current" "0" "current_step starts at 0"
  # Validate JSON
  python3 -m json.tool "$STATE_FILE" >/dev/null 2>&1
  assert_exit 0 $? "state file is valid JSON"
else
  echo "  ❌ state file not created"
  FAIL=$((FAIL + 1)); FAIL=$((FAIL + 1)); FAIL=$((FAIL + 1)); FAIL=$((FAIL + 1))
fi

run_test "init_state without config/build.json exits 1 with error"
# Temporarily rename config
mv config/build.json config/build.json.bak
output=$(init_state "no-config-feature" 2>&1)
no_config_exit=$?
mv config/build.json.bak config/build.json
assert_exit 1 "$no_config_exit" "exits 1 when config missing"
assert_contains "$output" "config/build.json not found" "clear error message shown"

run_test "load_state returns JSON with correct structure"
output=$(load_state "$FEATURE" 2>&1)
assert_exit 0 $? "load_state exits 0"
assert_contains "$output" "\"feature\"" "output has feature key"
assert_contains "$output" "\"current_step\"" "output has current_step key"
assert_contains "$output" "\"steps\"" "output has steps key"

run_test "load_state on nonexistent feature exits 1"
output=$(load_state "nonexistent-feature-$$" 2>&1)
no_load_exit=$?
assert_exit 1 "$no_load_exit" "exits 1 for missing state"
assert_contains "$output" "State not found" "error message shown"

run_test "advance_step increments current_step and updates statuses"
advance_step "$FEATURE" >/dev/null 2>&1
assert_exit 0 $? "advance_step exits 0"
new_step=$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(s['current_step'])")
step0_status=$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(s['steps'][0]['status'])")
step1_status=$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(s['steps'][1]['status'])")
assert_contains "$new_step" "1" "current_step incremented to 1"
assert_contains "$step0_status" "complete" "previous step marked complete"
assert_contains "$step1_status" "in-progress" "next step marked in-progress"

run_test "get_current_step returns correct step name"
output=$(get_current_step "$FEATURE" 2>&1)
assert_exit 0 $? "get_current_step exits 0"
assert_contains "$output" "prd-qualify" "correct step name (step 1)"
assert_contains "$output" "in-progress" "correct status"

run_test "load_state on corrupt JSON exits 1 with validation error"
echo "{not valid json" > "$STATE_FILE"
output=$(load_state "$FEATURE" 2>&1)
corrupt_exit=$?
assert_exit 1 "$corrupt_exit" "exits 1 for invalid JSON"
assert_contains "$output" "invalid state" "validation error message shown"
# Restore clean state
init_state "$FEATURE" >/dev/null 2>&1

run_test "_atomic_write with invalid JSON leaves no tmp file and returns 1"
target="${_BUILD_STATE_DIR}/${FEATURE}.json"
# Save original content
original=$(cat "$target")
_atomic_write "$target" "{bad json" 2>/dev/null
atomic_exit=$?
assert_exit 1 "$atomic_exit" "_atomic_write exits 1 for invalid JSON"
assert_not_exists "${target}.tmp" "tmp file cleaned up"
# Original file should be untouched
current_content=$(cat "$target")
if [ "$current_content" = "$original" ]; then
  echo "  ✅ original file intact"
  PASS=$((PASS + 1))
else
  echo "  ❌ original file was modified"
  FAIL=$((FAIL + 1))
fi

# --- Summary ---

echo ""
echo "══════════════════════════════════════"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "══════════════════════════════════════"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
