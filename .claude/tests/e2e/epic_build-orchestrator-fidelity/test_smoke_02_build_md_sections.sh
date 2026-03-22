#!/usr/bin/env bash
# Smoke Test 02: build.md contains all required new sections
# Epic: build-orchestrator-fidelity
# Scenario: Verify all 4 new sections added to build.md are present

set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
BUILD_MD="$REPO_ROOT/commands/pm/build.md"

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== Smoke Test 02: build.md Required Sections ==="

# Test 1: build.md line count < 500
line_count=$(wc -l < "$BUILD_MD")
if [ "$line_count" -lt 500 ]; then
  pass "build.md line count: $line_count (< 500)"
else
  fail "build.md line count: $line_count (>= 500, too large)"
fi

# Test 2: Delegation Guards section
if grep -q "Delegation Guards" "$BUILD_MD"; then
  pass "Delegation Guards section present"
else
  fail "Delegation Guards section MISSING"
fi

# Test 3: Plan-review Apply section
if grep -q "Plan-review Apply" "$BUILD_MD"; then
  pass "Plan-review Apply section present"
else
  fail "Plan-review Apply section MISSING"
fi

# Test 4: prd-qualify post-condition
if grep -q "Post-condition check" "$BUILD_MD"; then
  pass "Post-condition check section present"
else
  fail "Post-condition check section MISSING"
fi

# Test 5: QA completeness check
if grep -q "QA completeness check" "$BUILD_MD"; then
  pass "QA completeness check section present"
else
  fail "QA completeness check section MISSING"
fi

# Test 6: Enhanced prd-qualify detection (validation report status)
if grep -q "val_status\|validation.*passed\|passed.*validation" "$BUILD_MD"; then
  pass "Enhanced prd-qualify artifact detection present"
else
  fail "Enhanced prd-qualify artifact detection MISSING"
fi

# Test 7: Enhanced plan-review detection (verdict blocked check)
if grep -q "verdict.*blocked\|blocked.*verdict\|BLOCKED" "$BUILD_MD"; then
  pass "Enhanced plan-review artifact detection (blocked verdict) present"
else
  fail "Enhanced plan-review artifact detection MISSING"
fi

# Test 8: Enhanced epic-verify detection (QA section check)
if grep -q "QA.*Results" "$BUILD_MD"; then
  pass "Enhanced epic-verify artifact detection (QA section) present"
else
  fail "Enhanced epic-verify artifact detection MISSING"
fi

# Test 9: PRD hash check (prd modification detection)
if grep -q "prd_hash" "$BUILD_MD"; then
  pass "PRD hash modification detection present"
else
  fail "PRD hash modification detection MISSING"
fi

# Test 10: Epic hash check (plan-review apply verification)
if grep -q "epic_hash" "$BUILD_MD"; then
  pass "Epic hash apply verification present"
else
  fail "Epic hash apply verification MISSING"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
