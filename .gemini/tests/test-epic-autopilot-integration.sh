#!/usr/bin/env bash
# Epic Autopilot — Integration Tests
#
# Tests scripts delivered by the epic-autopilot epic:
#   - scripts/pm/next.sh (analyze issue filtering)
#   - scripts/pm/epic-run-plan.sh (execution plan generation)
#   - E2E verification on actual epic-autopilot data
#
# Usage:
#   bash tests/test-epic-autopilot-integration.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
TOTAL=0

# --- Test Helpers (same pattern as test-lifecycle-integration.sh) ---

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

assert_not_contains() {
  local output="$1" pattern="$2" label="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "  ❌ $label — pattern '$pattern' should NOT be present"
    FAIL=$((FAIL + 1))
  else
    echo "  ✅ $label"
    PASS=$((PASS + 1))
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

# --- Fixture Setup ---

FIXTURE_NAME="test-epic-$$"
FIXTURE_DIR=".gemini/epics/$FIXTURE_NAME"

setup_fixtures() {
  mkdir -p "$FIXTURE_DIR"

  # epic.md (required by both scripts)
  cat > "$FIXTURE_DIR/epic.md" << 'EPICEOF'
---
name: test-epic
status: in-progress
---
# Test Epic
EPICEOF

  # 1.md — open task, phase 1, no deps (should appear as READY)
  cat > "$FIXTURE_DIR/1.md" << 'EOF'
---
name: Normal open task
status: open
phase: 1
parallel: false
recommended_model: opus
github: 999
depends_on: []
---
# Task 1
Implementation details here.
EOF

  # 2.md — closed task, phase 1
  cat > "$FIXTURE_DIR/2.md" << 'EOF'
---
name: Completed task
status: closed
phase: 1
parallel: true
recommended_model: sonnet
github: 998
depends_on: []
---
# Task 2
Already done.
EOF

  # 3.md — open, phase 2, depends on closed task 2 (should be READY)
  cat > "$FIXTURE_DIR/3.md" << 'EOF'
---
name: Phase 2 ready task
status: open
phase: 2
parallel: false
depends_on: [2]
github: 997
---
# Task 3
Depends on task 2 which is closed.
EOF

  # 4-analysis.md — analysis file (should be skipped by plan, filtered by next)
  cat > "$FIXTURE_DIR/4-analysis.md" << 'EOF'
---
name: Analysis of codebase
status: open
phase: 1
---
# Analysis
This is an analysis artifact.
EOF

  # 5.md — [Analysis] prefix in name (filtered by next)
  # Note: no YAML quotes — grep-based parser reads raw text
  cat > "$FIXTURE_DIR/5.md" << 'EOF'
---
name: [Analysis] Codebase review
status: open
phase: 1
parallel: false
depends_on: []
---
# Task 5
Analysis by name prefix.
EOF

  # 6.md — body marker analyze (filtered by next)
  cat > "$FIXTURE_DIR/6.md" << 'EOF'
---
name: Hidden analyze task
status: open
phase: 1
parallel: false
depends_on: []
---
<!-- type: analyze -->
# Task 6
Analysis by body marker.
EOF

  # 7.md — open, phase 2, depends on open task 1 (should be BLOCKED)
  cat > "$FIXTURE_DIR/7.md" << 'EOF'
---
name: Blocked by task 1
status: open
phase: 2
parallel: false
depends_on: [1]
github: 996
---
# Task 7
Depends on task 1 which is still open.
EOF
}

cleanup_fixtures() {
  rm -rf "$FIXTURE_DIR"
}

trap cleanup_fixtures EXIT

echo "═══════════════════════════════════════════"
echo "  Epic Autopilot — Integration Tests"
echo "═══════════════════════════════════════════"

setup_fixtures

# ═══════════════════════════════════════════
# Section 1: next.sh Tests
# ═══════════════════════════════════════════

echo ""
echo "─── Section 1: next.sh ───"

run_test "Normal task appears in output"
output=$(bash scripts/pm/next.sh 2>&1)
rc=$?
assert_contains "$output" "Normal open task" "Open task visible"

run_test "Closed task hidden from output"
assert_not_contains "$output" "Completed task" "Closed task not shown"

run_test "Analysis filename filtered"
assert_not_contains "$output" "Analysis of codebase" "Analysis file filtered"

run_test "Analysis name prefix filtered"
assert_not_contains "$output" "Codebase review" "Analysis name filtered"

run_test "Analysis body marker filtered"
assert_not_contains "$output" "Hidden analyze task" "Body marker filtered"

run_test "Filtered count shown"
assert_contains "$output" "analyze issues filtered" "Filter count displayed"

run_test "--all flag shows filtered tasks"
output_all=$(bash scripts/pm/next.sh --all 2>&1)
assert_contains "$output_all" "Hidden analyze task" "Body marker task shown with --all"

run_test "next.sh exits cleanly"
assert_exit 0 "$rc" "Exit code 0"

# ═══════════════════════════════════════════
# Section 2: epic-run-plan.sh Tests
# ═══════════════════════════════════════════

echo ""
echo "─── Section 2: epic-run-plan.sh ───"

run_test "Missing args produces error"
output=$(bash scripts/pm/epic-run-plan.sh 2>&1)
rc=$?
assert_exit 1 "$rc" "Exit 1 on missing args"

run_test "Nonexistent epic produces error"
output=$(bash scripts/pm/epic-run-plan.sh nonexistent-epic-xyz 2>&1)
rc=$?
assert_exit 1 "$rc" "Exit 1 on bad epic name"

run_test "Plan output for test fixtures"
output=$(bash scripts/pm/epic-run-plan.sh "$FIXTURE_NAME" 2>&1)
rc=$?
assert_exit 0 "$rc" "Exit 0 on valid epic"

run_test "Analysis files skipped from plan"
assert_not_contains "$output" "Analysis of codebase" "Analysis file not in plan"

run_test "Closed tasks skipped from plan"
assert_not_contains "$output" "Completed task" "Closed task not in plan lines"

run_test "Open task appears as READY"
assert_contains "$output" "READY|1|Normal open task" "Task 1 is READY"

run_test "Default model is sonnet when missing"
# Task 3 has no recommended_model field
assert_contains "$output" "|3|Phase 2 ready task|sonnet|" "Default model sonnet"

run_test "Phase sorting — phase 1 before phase 2"
# Get line numbers of phase 1 and phase 2 tasks
line_p1=$(echo "$output" | grep -n "|1|Normal open task|" | head -1 | cut -d: -f1)
line_p2=$(echo "$output" | grep -n "|3|Phase 2 ready task|" | head -1 | cut -d: -f1)
if [ -n "$line_p1" ] && [ -n "$line_p2" ] && [ "$line_p1" -lt "$line_p2" ]; then
  echo "  ✅ Phase 1 tasks before phase 2"
  PASS=$((PASS + 1))
else
  echo "  ❌ Phase sorting incorrect (p1 line=$line_p1, p2 line=$line_p2)"
  FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))

run_test "Blocked detection for unmet dependencies"
assert_contains "$output" "BLOCKED|7|Blocked by task 1" "Task 7 is BLOCKED"

run_test "Header shows totals"
assert_contains "$output" "Total:" "Header has Total count"
assert_contains "$output" "Ready:" "Header has Ready count"
assert_contains "$output" "Blocked:" "Header has Blocked count"
assert_contains "$output" "Closed:" "Header has Closed count"

run_test "Pipe-delimited format correct"
# Check a READY line has 8 pipe-separated fields
ready_line=$(echo "$output" | grep "^READY|1|" | head -1)
field_count=$(echo "$ready_line" | awk -F'|' '{print NF}')
assert_equal "8" "$field_count" "READY line has 8 fields"

# ═══════════════════════════════════════════
# Section 3: E2E on actual epic-autopilot
# ═══════════════════════════════════════════

echo ""
echo "─── Section 3: E2E on epic-autopilot ───"

run_test "epic-run-plan.sh on actual epic-autopilot"
if [ -d ".gemini/epics/epic-autopilot" ]; then
  output=$(bash scripts/pm/epic-run-plan.sh epic-autopilot 2>&1)
  rc=$?
  assert_exit 0 "$rc" "Exit 0"
  # All 7 tasks should be closed, so 0 READY lines
  ready_count=$(echo "$output" | grep "^READY|" | wc -l | tr -d ' ')
  assert_equal "0" "$ready_count" "No READY tasks (all closed)"
  assert_contains "$output" "Closed: 7" "Header shows 7 closed"
else
  echo "  ⏭️  Skipped — epic-autopilot not found (expected in CI)"
  TOTAL=$((TOTAL - 1))
fi

run_test "next.sh runs without error on current state"
output=$(bash scripts/pm/next.sh 2>&1)
rc=$?
assert_exit 0 "$rc" "Exit 0"

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
