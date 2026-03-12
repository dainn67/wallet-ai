#!/usr/bin/env bash
# CCPM Task Lifecycle Engine — Integration Tests
#
# Tests all lifecycle subsystems end-to-end:
#   - Hooks (pre-task, post-task, stop-verify, pre-tool-use)
#   - Detection engine (task type, tech stack)
#   - Verification profiles
#   - State management
#   - Context rotation
#
# Usage:
#   bash tests/test-lifecycle-integration.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
TOTAL=0

# --- Test Helpers ---

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
    echo "  ❌ $label — pattern '$pattern' not found"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local file="$1" label="$2"
  if [ -f "$file" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — file not found: $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_equal() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

cleanup() {
  # Reset state
  echo '{"active_task": null}' > context/verify/state.json
  rm -f context/verify/BLOCKED.md
  rm -f context/verify/results/task-*-verify.log
  rm -f context/handoffs/latest.md
  rm -f context/handoffs/task-*.md
  rm -f context/verify/custom/*.sh
}

echo "═══ CCPM Lifecycle Integration Tests ═══"
echo "Project root: $PROJECT_ROOT"

# --- Scenario 1: Pre-task hook loads context ---

run_test "Pre-task hook — context loading protocol"
cleanup
output=$(bash hooks/pre-task.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Pre-task hook exits 0"
assert_contains "$output" "CONTEXT LOADING PROTOCOL" "Outputs context loading protocol"
assert_contains "$output" "No previous context found" "Reports no previous handoff"

# --- Scenario 2: Pre-task with existing handoff ---

run_test "Pre-task hook — with existing handoff note"
echo "# Test Handoff" > context/handoffs/latest.md
output=$(bash hooks/pre-task.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Pre-task hook exits 0"
assert_contains "$output" "Read .gemini/context/handoffs/latest.md" "Instructs to read handoff"

# --- Scenario 3: Post-task hook — missing handoff ---

run_test "Post-task hook — blocks when handoff missing"
cleanup
output=$(bash hooks/post-task.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 1 $exit_code "Post-task hook exits 1 (blocked)"
assert_contains "$output" "Handoff note missing" "Reports missing handoff"

# --- Scenario 4: Post-task hook — stale handoff ---

run_test "Post-task hook — blocks when handoff stale"
# Create a handoff but make it old (touch with past timestamp)
touch -t 202601010000 context/handoffs/latest.md
output=$(bash hooks/post-task.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 1 $exit_code "Post-task hook exits 1 (stale)"
assert_contains "$output" "stale" "Reports stale handoff"

# --- Scenario 5: Post-task hook — valid handoff ---

run_test "Post-task hook — passes with valid handoff"
cat > context/handoffs/latest.md << 'HANDOFF'
# Handoff Note

## Completed
- Implemented feature X

## Decisions Made
- Used approach A over B

## State of Tests
- All passing

## Files Changed
- src/main.ts
HANDOFF
touch context/handoffs/latest.md  # Make it fresh
output=$(bash hooks/post-task.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Post-task hook exits 0 (valid handoff)"
assert_contains "$output" "PASSED" "Reports passed"

# --- Scenario 6: Stop hook — no active task ---

run_test "Stop hook — allows exit when no active task"
cleanup
output=$(bash hooks/stop-verify.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Stop hook exits 0 (no active task)"

# --- Scenario 7: Stop hook — SKIP mode ---

run_test "Stop hook — allows exit in SKIP mode"
echo '{"active_task":{"issue_number":99,"verify_mode":"SKIP","tech_stack":"generic","current_iteration":0,"max_iterations":20,"iterations":[]}}' > context/verify/state.json
output=$(bash hooks/stop-verify.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Stop hook exits 0 (SKIP mode)"
assert_contains "$output" "skipped" "Reports verification skipped"

# --- Scenario 8: Stop hook — STRICT + PASS ---

run_test "Stop hook — allows exit on VERIFY_PASS (STRICT)"
echo '{"active_task":{"issue_number":99,"verify_mode":"STRICT","tech_stack":"generic","current_iteration":0,"max_iterations":20,"iterations":[]}}' > context/verify/state.json
output=$(bash hooks/stop-verify.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Stop hook exits 0 (VERIFY_PASS)"
assert_contains "$output" "VERIFY_PASS" "Profile outputs VERIFY_PASS"

# --- Scenario 9: Stop hook — STRICT + FAIL blocks ---

run_test "Stop hook — blocks exit on VERIFY_FAIL (STRICT)"
echo '#!/bin/bash
echo "❌ Build: Failed"
echo "VERIFY_FAIL: Build failed."
exit 1' > context/verify/custom/fail-test.sh
chmod +x context/verify/custom/fail-test.sh
echo '{"active_task":{"issue_number":99,"verify_mode":"STRICT","tech_stack":"custom","current_iteration":0,"max_iterations":20,"iterations":[]}}' > context/verify/state.json
output=$(bash hooks/stop-verify.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 2 $exit_code "Stop hook exits 2 (BLOCKED)"
assert_contains "$output" "EXIT BLOCKED" "Reports exit blocked"
assert_contains "$output" "Iteration 1/20" "Shows iteration count"
rm -f context/verify/custom/fail-test.sh

# --- Scenario 10: Stop hook — RELAXED + FAIL warns ---

run_test "Stop hook — warns but allows exit on VERIFY_FAIL (RELAXED)"
echo '#!/bin/bash
echo "❌ Lint: Issues found"
echo "VERIFY_FAIL: Lint issues."
exit 1' > context/verify/custom/fail-test.sh
chmod +x context/verify/custom/fail-test.sh
echo '{"active_task":{"issue_number":99,"verify_mode":"RELAXED","tech_stack":"custom","current_iteration":0,"max_iterations":20,"iterations":[]}}' > context/verify/state.json
output=$(bash hooks/stop-verify.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Stop hook exits 0 (RELAXED allows)"
assert_contains "$output" "RELAXED" "Reports RELAXED mode"
rm -f context/verify/custom/fail-test.sh

# --- Scenario 11: Max iterations → BLOCKED.md ---

run_test "Stop hook — max iterations creates BLOCKED.md"
echo '{"active_task":{"issue_number":99,"verify_mode":"STRICT","tech_stack":"generic","current_iteration":3,"max_iterations":3,"iterations":[{"iteration":1,"timestamp":"T1","result":"VERIFY_FAIL","failures":["build"],"files_changed":[]},{"iteration":2,"timestamp":"T2","result":"VERIFY_FAIL","failures":["tests"],"files_changed":[]},{"iteration":3,"timestamp":"T3","result":"VERIFY_FAIL","failures":["lint"],"files_changed":[]}]}}' > context/verify/state.json
output=$(bash hooks/stop-verify.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Stop hook exits 0 (max iterations → allow)"
assert_contains "$output" "MAX ITERATIONS REACHED" "Reports max iterations"
assert_file_exists "context/verify/BLOCKED.md" "BLOCKED.md created"

# --- Scenario 12: Pre-tool-use — blocks issue close without verify ---

run_test "Pre-tool-use — blocks issue close without verification"
echo '{"active_task":{"issue_number":99,"verify_mode":"STRICT","tech_stack":"generic","current_iteration":0,"max_iterations":20,"iterations":[]}}' > context/verify/state.json
output=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh issue close 99"}}' | bash hooks/pre-tool-use.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 2 $exit_code "Pre-tool-use blocks (exit 2)"
assert_contains "$output" "Cannot close issue without passing verification" "Clear block message"

# --- Scenario 13: Pre-tool-use — allows close after VERIFY_PASS ---

run_test "Pre-tool-use — allows close after VERIFY_PASS"
echo '{"active_task":{"issue_number":99,"verify_mode":"STRICT","tech_stack":"generic","current_iteration":1,"max_iterations":20,"iterations":[{"iteration":1,"timestamp":"T1","result":"VERIFY_PASS","failures":[],"files_changed":[]}]}}' > context/verify/state.json
output=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh issue close 99"}}' | bash hooks/pre-tool-use.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Pre-tool-use allows (exit 0)"

# --- Scenario 14: Pre-tool-use — allows non-CCPM operations ---

run_test "Pre-tool-use — allows non-CCPM tool calls"
echo '{"active_task":{"issue_number":99,"verify_mode":"STRICT","tech_stack":"generic","current_iteration":0,"max_iterations":20,"iterations":[]}}' > context/verify/state.json
output=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/test.txt"}}' | bash hooks/pre-tool-use.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Non-Bash tool allowed (exit 0)"

# --- Scenario 15: Tech stack detection ---

run_test "Tech stack detection"
source scripts/pm/lifecycle-helpers.sh

# Test generic (current project has no standard markers)
result=$(detect_tech_stack "$PROJECT_ROOT")
# This project has no pyproject.toml, package.json, etc. so should be generic
# (unless there are marker files — just check it returns something valid)
echo "  Detected: $result"
valid_stacks="python node swift rust go generic custom"
if echo "$valid_stacks" | grep -qw "$result"; then
  echo "  ✅ Returns valid tech stack"
  PASS=$((PASS + 1))
else
  echo "  ❌ Invalid tech stack: $result"
  FAIL=$((FAIL + 1))
fi

# Test with temp Python project
tmp_py=$(mktemp -d)
touch "$tmp_py/pyproject.toml"
py_result=$(detect_tech_stack "$tmp_py")
assert_equal "python" "$py_result" "Detects Python project"
rm -rf "$tmp_py"

# Test with temp Node project
tmp_node=$(mktemp -d)
echo '{}' > "$tmp_node/package.json"
node_result=$(detect_tech_stack "$tmp_node")
assert_equal "node" "$node_result" "Detects Node project"
rm -rf "$tmp_node"

# --- Scenario 16: State persistence across iterations ---

run_test "State persistence — tracks iterations correctly"
cleanup
echo '{"active_task":{"issue_number":42,"epic":"test","type":"FEATURE","verify_mode":"STRICT","tech_stack":"generic","verify_profile":"","max_iterations":10,"current_iteration":0,"started_at":"2026-02-20T04:00:00Z","iterations":[]}}' > context/verify/state.json

# Increment 3 times
increment_iteration "VERIFY_FAIL" "build-failed" "main.ts" > /dev/null 2>&1
increment_iteration "VERIFY_FAIL" "test-failed" "main.ts,test.ts" > /dev/null 2>&1
increment_iteration "VERIFY_PASS" "" "main.ts" > /dev/null 2>&1

# Check state
if command -v jq &>/dev/null; then
  iter_count=$(jq -r '.active_task.current_iteration' context/verify/state.json)
  last_result=$(jq -r '.active_task.iterations[-1].result' context/verify/state.json)
  total_iters=$(jq -r '.active_task.iterations | length' context/verify/state.json)
else
  iter_count=$(python3 -c "import json; d=json.load(open('context/verify/state.json')); print(d['active_task']['current_iteration'])")
  last_result=$(python3 -c "import json; d=json.load(open('context/verify/state.json')); print(d['active_task']['iterations'][-1]['result'])")
  total_iters=$(python3 -c "import json; d=json.load(open('context/verify/state.json')); print(len(d['active_task']['iterations']))")
fi

assert_equal "3" "$iter_count" "Iteration count is 3"
assert_equal "VERIFY_PASS" "$last_result" "Last result is VERIFY_PASS"
assert_equal "3" "$total_iters" "3 iteration records stored"

# --- Scenario 17: Context rotation ---

run_test "Context rotation — archives excess handoff notes"
cleanup
mkdir -p context/handoffs/.archive

# Create 12 dummy handoff notes
for i in $(seq 1 12); do
  echo "# Handoff $i" > "context/handoffs/task-$(printf '%03d' $i).md"
  sleep 0.1  # Ensure different modification times
done

count_before=$(find context/handoffs -maxdepth 1 -name "task-*.md" -type f | wc -l | tr -d ' ')
assert_equal "12" "$count_before" "12 handoff notes before rotation"

# Run pre-task hook (triggers rotation)
bash hooks/pre-task.sh "$PROJECT_ROOT" > /dev/null 2>&1

count_after=$(find context/handoffs -maxdepth 1 -name "task-*.md" -type f | wc -l | tr -d ' ')
archived=$(find context/handoffs/.archive -name "task-*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

assert_equal "10" "$count_after" "10 handoff notes after rotation"
assert_equal "2" "$archived" "2 notes archived"

# --- Scenario 18: Generic verification profile ---

run_test "Generic verification profile — runs in this repo"
output=$(bash context/verify/profiles/generic.sh "$PROJECT_ROOT" 2>&1)
exit_code=$?
assert_exit 0 $exit_code "Generic profile exits 0"
assert_contains "$output" "VERIFY_PASS" "Generic profile passes"

# --- Cleanup ---

cleanup
rm -f context/handoffs/task-*.md
rm -rf context/handoffs/.archive/task-*.md

# --- Summary ---

echo ""
echo "═══════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed (out of $TOTAL tests)"
echo "═══════════════════════════════════════"

if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ ALL TESTS PASSED"
  exit 0
else
  echo "  ❌ SOME TESTS FAILED"
  exit 1
fi
