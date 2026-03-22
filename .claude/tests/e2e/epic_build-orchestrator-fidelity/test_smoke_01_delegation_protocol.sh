#!/usr/bin/env bash
# Smoke Test 01: Delegation protocol rule exists and has required sections
# Epic: build-orchestrator-fidelity
# Scenario: Verify delegation-protocol.md exists with all required sections and anti-patterns

set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== Smoke Test 01: Delegation Protocol Rule ==="

# Test 1: File exists
if test -f "$REPO_ROOT/rules/delegation-protocol.md"; then
  pass "rules/delegation-protocol.md exists"
else
  fail "rules/delegation-protocol.md MISSING"
fi

# Test 2: Has at least 5 sections
section_count=$(grep -c "^## " "$REPO_ROOT/rules/delegation-protocol.md" 2>/dev/null || echo 0)
if [ "$section_count" -ge 5 ]; then
  pass "Has $section_count sections (>= 5 required)"
else
  fail "Only $section_count sections found (need >= 5)"
fi

# Test 3: Has Anti-Patterns section
if grep -q "Anti-Pattern" "$REPO_ROOT/rules/delegation-protocol.md"; then
  pass "Has Anti-Patterns section"
else
  fail "Missing Anti-Patterns section"
fi

# Test 4: Has concrete Always/Never rules
if grep -qi "always\|never" "$REPO_ROOT/rules/delegation-protocol.md"; then
  pass "Has Always/Never rules"
else
  fail "Missing Always/Never rules"
fi

# Test 5: No frontmatter (rule file format)
first_line=$(head -1 "$REPO_ROOT/rules/delegation-protocol.md")
if echo "$first_line" | grep -q "^# "; then
  pass "No frontmatter — starts with # header"
else
  fail "First line is not a # header: '$first_line'"
fi

# Test 6: Referenced in build.md
if grep -q "delegation-protocol" "$REPO_ROOT/commands/pm/build.md"; then
  pass "Referenced in commands/pm/build.md"
else
  fail "NOT referenced in commands/pm/build.md"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
