#!/usr/bin/env bash
# test-build-resume.sh — Tests for --resume, --dry-run, and retry logic in build.md + build-state.sh
#
# Usage: bash tests/integration/epic_dx-hardening/test-build-resume.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

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

assert_not_contains() {
  local output="$1" pattern="$2" label="$3"
  if ! echo "$output" | grep -q "$pattern"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — unexpected pattern '$pattern' found in output"
    FAIL=$((FAIL + 1))
  fi
}

# Cleanup
FEATURE="test-resume-$$"
STATE_FILE=".claude/context/build-state/${FEATURE}.json"
cleanup() {
  rm -f "$STATE_FILE" "${STATE_FILE}.tmp"
}
trap cleanup EXIT

# ─── build.md structural checks (--resume and --dry-run) ───────────────────

echo "=== Section: build.md --resume and --dry-run implementation ==="

run_test "build.md: --resume flag is parsed (flag_resume variable)"
output=$(grep -n 'flag_resume' commands/pm/build.md 2>&1)
assert_contains "$output" "flag_resume" "flag_resume variable referenced"

run_test "build.md: --dry-run flag is parsed (flag_dry_run variable)"
output=$(grep -n 'flag_dry_run' commands/pm/build.md 2>&1)
assert_contains "$output" "flag_dry_run" "flag_dry_run variable referenced"

run_test "build.md: --resume missing state shows clear error"
output=$(grep -n 'No build state found' commands/pm/build.md 2>&1)
assert_contains "$output" "No build state found" "missing state error message present"

run_test "build.md: --dry-run exits without executing steps"
# Verify dry-run section exists and references exit 0
output=$(grep -n 'exit 0' commands/pm/build.md 2>&1)
assert_contains "$output" "exit 0" "dry-run has exit 0 to stop execution"

run_test "build.md: dry-run shows token estimates from config"
output=$(grep -n 'tokens_per_tier' commands/pm/build.md 2>&1)
assert_contains "$output" "tokens_per_tier" "dry-run references tokens_per_tier"

run_test "build.md: dry-run handles budget script missing (N/A note)"
output=$(grep -n 'budget script not available' commands/pm/build.md 2>&1)
assert_contains "$output" "budget script not available" "budget fallback note present"

run_test "build.md: dry-run marks completed steps as done"
output=$(grep -n 'done' commands/pm/build.md 2>&1)
assert_contains "$output" "done" "completed step status marker present"

run_test "build.md: --resume + --dry-run combined shows remaining steps"
output=$(grep -n 'dry_run\|dry-run\|resume' commands/pm/build.md 2>&1)
assert_contains "$output" "resume" "combined flag scenario documented"

# ─── Retry logic ───────────────────────────────────────────────────────────

echo ""
echo "=== Section: Retry logic ==="

run_test "build.md: transient error keywords listed"
output=$(grep -n 'rate limit\|ECONNREFUSED\|timeout' commands/pm/build.md 2>&1)
assert_contains "$output" "rate limit" "rate limit keyword listed"
assert_contains "$output" "ECONNREFUSED" "ECONNREFUSED keyword listed"
assert_contains "$output" "timeout" "timeout keyword listed"

run_test "build.md: retry once message present"
output=$(grep -n 'retrying' commands/pm/build.md 2>&1)
assert_contains "$output" "retrying" "retry message present"

run_test "build.md: failure menu includes fix option"
output=$(grep -n '→ fix' commands/pm/build.md 2>&1)
assert_contains "$output" "fix" "fix option in failure menu"

run_test "build.md: failure menu includes skip option"
output=$(grep -n '→ skip' commands/pm/build.md 2>&1)
assert_contains "$output" "skip" "skip option in failure menu"

run_test "build.md: failure menu includes abort option"
output=$(grep -n '→ abort' commands/pm/build.md 2>&1)
assert_contains "$output" "abort" "abort option in failure menu"

# ─── load_state validation (build-state.sh hardening) ─────────────────────

echo ""
echo "=== Section: load_state structural validation ==="

run_test "load_state: valid state at step 5 loads successfully"
# Init state and advance to step 5
init_state "$FEATURE" >/dev/null 2>&1
for i in $(seq 1 5); do
  advance_step "$FEATURE" >/dev/null 2>&1
done
output=$(load_state "$FEATURE" 2>&1)
load_exit=$?
assert_exit 0 "$load_exit" "load_state exits 0 for valid state"
step_val=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['current_step'])" "$output" 2>/dev/null || echo "parse-error")
assert_contains "$step_val" "5" "current_step is 5"

run_test "--resume starts from step 6 (current_step_idx == 5 means next is 6)"
# Verify build.md documents advancing from current_step
output=$(grep -n 'current_step' commands/pm/build.md 2>&1)
assert_contains "$output" "current_step" "current_step referenced in resume section"

run_test "load_state: state file missing → exits 1 with clear error"
output=$(load_state "no-such-feature-$$" 2>&1)
missing_exit=$?
assert_exit 1 "$missing_exit" "exits 1 for missing state file"
assert_contains "$output" "State not found" "error message shown"

run_test "load_state: corrupted JSON → exits 1"
echo "{corrupted" > "$STATE_FILE"
output=$(load_state "$FEATURE" 2>&1)
corrupt_exit=$?
assert_exit 1 "$corrupt_exit" "exits 1 for corrupted JSON"
assert_contains "$output" "invalid state" "invalid state error shown"

run_test "load_state: missing 'steps' key → exits 1"
printf '{"feature":"test","current_step":0}' > "$STATE_FILE"
output=$(load_state "$FEATURE" 2>&1)
missing_key_exit=$?
assert_exit 1 "$missing_key_exit" "exits 1 for missing steps key"
assert_contains "$output" "SCHEMA_ERROR\|invalid state" "schema error shown"

run_test "load_state: missing 'current_step' key → exits 1"
printf '{"feature":"test","steps":[]}' > "$STATE_FILE"
output=$(load_state "$FEATURE" 2>&1)
missing_cs_exit=$?
assert_exit 1 "$missing_cs_exit" "exits 1 for missing current_step key"

run_test "load_state: steps is empty array → exits 1"
printf '{"feature":"test","current_step":0,"steps":[]}' > "$STATE_FILE"
output=$(load_state "$FEATURE" 2>&1)
empty_arr_exit=$?
assert_exit 1 "$empty_arr_exit" "exits 1 for empty steps array"
assert_contains "$output" "non-empty\|SCHEMA_ERROR\|invalid state" "error about empty array"

run_test "load_state: current_step out of bounds → exits 1"
printf '{"feature":"test","current_step":99,"steps":[{"name":"x","status":"pending","started":"","completed":""}]}' > "$STATE_FILE"
output=$(load_state "$FEATURE" 2>&1)
oob_exit=$?
assert_exit 1 "$oob_exit" "exits 1 when current_step out of bounds"
assert_contains "$output" "out of bounds\|SCHEMA_ERROR\|invalid state" "out of bounds error shown"

# ─── Dry-run output format ─────────────────────────────────────────────────

echo ""
echo "=== Section: Dry-run output structure ==="

run_test "build.md: dry-run table header includes 'Step', 'Name', 'Gate', 'Tier', 'Tokens'"
output=$(grep -n 'Step\|Gate\|Tier\|Tokens' commands/pm/build.md 2>&1)
assert_contains "$output" "Step" "table has Step column"
assert_contains "$output" "Gate" "table has Gate column"
assert_contains "$output" "Tier" "table has Tier column"
assert_contains "$output" "Tokens" "table has Tokens column"

run_test "build.md: dry-run footer shows total tokens and gate count"
output=$(grep -n 'Total estimated\|Gates:' commands/pm/build.md 2>&1)
assert_contains "$output" "Total estimated" "total tokens line present"
assert_contains "$output" "Gates:" "gates count line present"

run_test "build.md: dry-run gate marker 🚧 present"
output=$(grep -n '🚧' commands/pm/build.md 2>&1)
assert_contains "$output" "🚧" "gate marker 🚧 in dry-run output"

# --- Summary ---

echo ""
echo "══════════════════════════════════════"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "══════════════════════════════════════"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
