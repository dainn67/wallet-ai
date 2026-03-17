#!/usr/bin/env bash
# Integration tests for epic-decompose + pre-task.sh design spec integration (Issue #124)
# Validates that source files contain expected patterns.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert_ok() {
  local desc="$1" result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" = "true" ]; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "======================================="
echo " Tests: Decompose + Hook Design Integration"
echo "======================================="

# --- Test 1: epic-decompose.md contains design spec detection ---
echo ""
echo "Test 1: epic-decompose.md has design spec detection"
match=$(grep -c 'designs.*specs' "$PROJECT_ROOT/commands/pm/epic-decompose.md" 2>/dev/null || echo 0)
assert_ok "epic-decompose.md references .claude/designs/*/specs/" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 2: epic-decompose.md has guard condition ---
echo ""
echo "Test 2: epic-decompose.md has guard/conditional for design"
match=$(grep -ci 'if.*available\|only if\|if no\|skip silently' "$PROJECT_ROOT/commands/pm/epic-decompose.md" 2>/dev/null || echo 0)
assert_ok "epic-decompose.md has conditional guard for design enrichment" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 3: epic-decompose.md has design_spec frontmatter instruction ---
echo ""
echo "Test 3: epic-decompose.md instructs adding design_spec to frontmatter"
match=$(grep -c 'design_spec:' "$PROJECT_ROOT/commands/pm/epic-decompose.md" 2>/dev/null || echo 0)
assert_ok "epic-decompose.md mentions design_spec frontmatter field" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 4: pre-task.sh contains design_spec variable ---
echo ""
echo "Test 4: pre-task.sh has design_spec handling"
match=$(grep -c 'design_spec' "$PROJECT_ROOT/hooks/pre-task.sh" 2>/dev/null || echo 0)
assert_ok "pre-task.sh references design_spec (got $match occurrences)" "$([ "$match" -ge 2 ] && echo true || echo false)"

# --- Test 5: pre-task.sh still has original advisory ---
echo ""
echo "Test 5: pre-task.sh preserves original Design Gate flow"
match=$(grep -c 'create a design file' "$PROJECT_ROOT/hooks/pre-task.sh" 2>/dev/null || echo 0)
assert_ok "pre-task.sh still contains 'create a design file'" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 6: pre-task.sh has new advisory ---
echo ""
echo "Test 6: pre-task.sh has DESIGN REFERENCE AVAILABLE advisory"
match=$(grep -c 'DESIGN REFERENCE AVAILABLE' "$PROJECT_ROOT/hooks/pre-task.sh" 2>/dev/null || echo 0)
assert_ok "pre-task.sh contains 'DESIGN REFERENCE AVAILABLE'" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 7: pre-task.sh has graceful fallback for missing spec file ---
echo ""
echo "Test 7: pre-task.sh checks spec file existence"
match=$(grep -c '\-f.*_design_spec' "$PROJECT_ROOT/hooks/pre-task.sh" 2>/dev/null || echo 0)
assert_ok "pre-task.sh uses -f check on design spec path" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Summary ---
echo ""
echo "======================================="
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
