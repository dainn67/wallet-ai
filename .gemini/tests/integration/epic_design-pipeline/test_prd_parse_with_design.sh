#!/usr/bin/env bash
# Test: prd-parse design system integration (Issue #123)
# Verifies that commands/pm/prd-parse.md contains design-aware additions.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TARGET="$REPO_ROOT/commands/pm/prd-parse.md"
PASS=0
FAIL=0

assert() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== test_prd_parse_with_design ==="

# 1. Design system loading reference exists
assert "prd-parse contains design system path reference" \
  "grep -q 'designs.*design-system' '$TARGET'"

# 2. Existence guard present
assert "prd-parse contains existence guard for design artifacts" \
  "[ \$(grep -c 'designs.*exists\|designs.*available\|Only if.*designs' '$TARGET') -ge 1 ]"

# 3. Architecture Decision injection for design system
assert "prd-parse contains Design System AD injection" \
  "grep -q 'AD-N: Design System' '$TARGET'"

# 4. Design spec enrichment for tasks
assert "prd-parse contains design spec enrichment section" \
  "grep -q 'Design Spec Enrichment' '$TARGET'"

# 5. All original sections still present (no removals)
assert "prd-parse still has Preflight section" \
  "grep -q '## Preflight' '$TARGET'"
assert "prd-parse still has Role & Mindset section" \
  "grep -q '## Role & Mindset' '$TARGET'"
assert "prd-parse still has Instructions section" \
  "grep -q '## Instructions' '$TARGET'"
assert "prd-parse still has IMPORTANT section" \
  "grep -q '## IMPORTANT' '$TARGET'"

# 6. Guard pattern: "Otherwise: Skip" present for each design block
assert "prd-parse has graceful skip guards (>=3)" \
  "[ \$(grep -c 'Otherwise.*Skip' '$TARGET') -ge 3 ]"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
