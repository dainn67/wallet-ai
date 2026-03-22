#!/bin/bash
# Integration Tests: QA Run command validation
# Tests the command file structure and report output format
set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected '$expected', got '$actual'"
    (( FAIL++ )) || true
  fi
}

echo "=== QA Run Integration Tests ==="

# Test 1: Command file exists
if [ -f "commands/qa/run.md" ]; then
  echo "  ✅ commands/qa/run.md exists"
  (( PASS++ )) || true
else
  echo "  ❌ commands/qa/run.md not found"
  (( FAIL++ )) || true
fi

# Test 2: Command has frontmatter with allowed-tools
if head -5 commands/qa/run.md | grep -q 'allowed-tools'; then
  echo "  ✅ Command has allowed-tools in frontmatter"
  (( PASS++ )) || true
else
  echo "  ❌ Missing allowed-tools in frontmatter"
  (( FAIL++ )) || true
fi

# Test 3: Command has model specification
if head -5 commands/qa/run.md | grep -q 'model'; then
  echo "  ✅ Command has model in frontmatter"
  (( PASS++ )) || true
else
  echo "  ❌ Missing model in frontmatter"
  (( FAIL++ )) || true
fi

# Test 4: Reports directory exists
if [ -d ".claude/qa/reports" ]; then
  echo "  ✅ Reports directory exists"
  (( PASS++ )) || true
else
  echo "  ❌ Reports directory not found"
  (( FAIL++ )) || true
fi

# Test 5: Command references all 7 phases
phase_count=0
for phase in "Phase 1" "Phase 2" "Phase 3" "Phase 4" "Phase 5" "Phase 6" "Phase 7"; do
  if grep -q "$phase" commands/qa/run.md; then
    (( phase_count++ )) || true
  fi
done
assert_eq "Command references all 7 phases" "7" "$phase_count"

# Test 6: Command references health score computation
if grep -q "health.score" commands/qa/run.md || grep -q "Health Score" commands/qa/run.md; then
  echo "  ✅ Command includes health score"
  (( PASS++ )) || true
else
  echo "  ❌ Command missing health score references"
  (( FAIL++ )) || true
fi

# Test 7: Command references dual signal evaluation
if grep -q "accessibility tree" commands/qa/run.md && grep -q "screenshot" commands/qa/run.md; then
  echo "  ✅ Command uses dual signal (a11y tree + screenshot)"
  (( PASS++ )) || true
else
  echo "  ❌ Command missing dual signal evaluation"
  (( FAIL++ )) || true
fi

# Test 8: Command references shell wrappers
if grep -q "axe-wrapper" commands/qa/run.md || grep -q "axe_" commands/qa/run.md; then
  echo "  ✅ Command references axe wrapper"
  (( PASS++ )) || true
else
  echo "  ❌ Command missing axe wrapper reference"
  (( FAIL++ )) || true
fi

# Test 9: Command references evidence capture
if grep -q "evidence-capture" commands/qa/run.md || grep -q "capture_" commands/qa/run.md; then
  echo "  ✅ Command references evidence capture"
  (( PASS++ )) || true
else
  echo "  ❌ Command missing evidence capture reference"
  (( FAIL++ )) || true
fi

# Test 10: Command references simctl wrapper
if grep -q "simctl" commands/qa/run.md; then
  echo "  ✅ Command references simctl wrapper"
  (( PASS++ )) || true
else
  echo "  ❌ Command missing simctl reference"
  (( FAIL++ )) || true
fi

# Test 11: Scenario directory has test scenarios
scenario_count=$(ls .claude/qa/scenarios/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$scenario_count" -ge 1 ]; then
  echo "  ✅ Scenarios available: $scenario_count"
  (( PASS++ )) || true
else
  echo "  ❌ No scenarios in .claude/qa/scenarios/"
  (( FAIL++ )) || true
fi

# Test 12: Config has required fields for run command
if jq -e '.category_weights and .health_score_threshold and .default_timeout' config/qa.json >/dev/null 2>&1; then
  echo "  ✅ Config has required fields for run command"
  (( PASS++ )) || true
else
  echo "  ❌ Config missing required fields"
  (( FAIL++ )) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
