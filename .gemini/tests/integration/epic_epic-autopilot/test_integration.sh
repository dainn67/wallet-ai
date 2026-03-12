#!/usr/bin/env bash
# Integration tests for epic-autopilot — cross-module verification
# Tests interfaces between: decompose → plan, plan output format, config → epic-run

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
TOTAL=0

run_test() { TOTAL=$((TOTAL + 1)); echo ""; echo "── Test $TOTAL: $1 ──"; }

assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [ "$actual" -eq "$expected" ]; then echo "  ✅ $label"; PASS=$((PASS + 1))
  else echo "  ❌ $label (expected exit $expected, got $actual)"; FAIL=$((FAIL + 1)); fi
}

assert_contains() {
  local output="$1" pattern="$2" label="$3"
  if echo "$output" | grep -q "$pattern"; then echo "  ✅ $label"; PASS=$((PASS + 1))
  else echo "  ❌ $label — '$pattern' not found"; FAIL=$((FAIL + 1)); fi
}

assert_not_contains() {
  local output="$1" pattern="$2" label="$3"
  if echo "$output" | grep -q "$pattern"; then echo "  ❌ $label — '$pattern' should NOT be present"; FAIL=$((FAIL + 1))
  else echo "  ✅ $label"; PASS=$((PASS + 1)); fi
}

assert_equal() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then echo "  ✅ $label"; PASS=$((PASS + 1))
  else echo "  ❌ $label — expected '$expected', got '$actual'"; FAIL=$((FAIL + 1)); fi
}

echo "═══ Integration Tests: epic-autopilot ═══"

# --- Decompose → Plan Script interface ---

run_test "epic-decompose.md defines complexity heuristics that plan script reads"
# Verify decompose defines the fields that plan script reads
assert_contains "$(cat commands/pm/epic-decompose.md)" "recommended_model" "Decompose defines recommended_model"
# Verify plan script reads recommended_model
assert_contains "$(cat scripts/pm/epic-run-plan.sh)" "recommended_model" "Plan script reads recommended_model"

run_test "Plan script output format matches epic-run expectations"
# epic-run.md should reference the pipe-delimited format
assert_contains "$(cat commands/pm/epic-run.md)" "epic-run-plan" "epic-run calls plan script"

# --- Plan script format verification with fixtures ---

FIXTURE_NAME="integ-test-$$"
FIXTURE_DIR=".gemini/epics/$FIXTURE_NAME"
mkdir -p "$FIXTURE_DIR"
trap "rm -rf '$FIXTURE_DIR'" EXIT

# Create minimal epic
cat > "$FIXTURE_DIR/epic.md" << 'EOF'
---
name: integration-test
status: in-progress
---
# Test
EOF

# Task with recommended_model set
cat > "$FIXTURE_DIR/1.md" << 'EOF'
---
name: Task with model
status: open
phase: 1
recommended_model: opus
github: 100
depends_on: []
parallel: true
---
# Task 1
EOF

# Task without recommended_model (should default to sonnet)
cat > "$FIXTURE_DIR/2.md" << 'EOF'
---
name: Task without model
status: open
phase: 1
github: 101
depends_on: []
parallel: false
---
# Task 2
EOF

run_test "Plan script propagates recommended_model from task frontmatter"
output=$(bash scripts/pm/epic-run-plan.sh "$FIXTURE_NAME" 2>&1)
assert_exit 0 $? "Script runs"
assert_contains "$output" "|1|Task with model|opus|" "opus model propagated"
assert_contains "$output" "|2|Task without model|sonnet|" "sonnet default applied"

run_test "Plan script outputs parallel field correctly"
assert_contains "$output" "|true" "parallel=true propagated"
assert_contains "$output" "|false" "parallel=false propagated"

run_test "Plan output has exactly 8 pipe-delimited fields per task line"
task_lines=$(echo "$output" | grep "^READY|" | head -1)
field_count=$(echo "$task_lines" | awk -F'|' '{print NF}')
assert_equal "8" "$field_count" "8 fields per line"

# --- Config → epic-run interface ---

run_test "config/epic-run.json has all expected fields"
config=$(cat config/epic-run.json)
assert_contains "$config" "max_parallel" "max_parallel field"
assert_contains "$config" "auto_continue" "auto_continue field"
assert_contains "$config" "skip_verification" "skip_verification field"
assert_contains "$config" "progress_format" "progress_format field"

run_test "epic-run.md references config fields"
epic_run=$(cat commands/pm/epic-run.md)
assert_contains "$epic_run" "epic-run.json" "References config file"
assert_contains "$epic_run" "max_parallel\|max-parallel" "Uses max_parallel config"

# --- next.sh integration with epic data ---

run_test "next.sh correctly handles epics with mixed task states"
# Add a closed task to fixture
cat > "$FIXTURE_DIR/3.md" << 'EOF'
---
name: Closed task
status: closed
phase: 1
---
# Done
EOF
output=$(bash scripts/pm/next.sh 2>&1)
assert_exit 0 $? "Runs with mixed states"

# --- epic-sync → issue-start interface ---

run_test "epic-sync model label format matches issue-start reading"
# epic-sync should write model:sonnet/model:opus labels
sync_content=$(cat commands/pm/epic-sync.md)
start_content=$(cat commands/pm/issue-start.md)
assert_contains "$sync_content" "model:" "Sync writes model labels"
assert_contains "$start_content" "model" "Start reads model info"

# --- Standalone test suite ---

run_test "Standalone integration test suite passes"
output=$(bash tests/test-epic-autopilot-integration.sh 2>&1)
rc=$?
assert_exit 0 "$rc" "All standalone tests pass"
assert_contains "$output" "0 failed" "Zero failures"

# --- Summary ---

echo ""
echo "═══════════════════════════════════════════"
echo "  Integration: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════"

[ "$FAIL" -gt 0 ] && exit 1
exit 0
