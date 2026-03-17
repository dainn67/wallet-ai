#!/usr/bin/env bash
# Integration tests for downstream design pipeline integration (Issue #126)
# Validates prd-parse.md and epic-decompose.md contain design-related conditional blocks.
# Also validates TEXT_ONLY mode coverage (NFR-3).

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
echo " Tests: Downstream Integration (prd-parse + epic-decompose)"
echo "======================================="

PRD_PARSE="$PROJECT_ROOT/commands/pm/prd-parse.md"
EPIC_DECOMPOSE="$PROJECT_ROOT/commands/pm/epic-decompose.md"

# =============================================
# Part A: prd-parse.md design integration
# =============================================
echo ""
echo "--- prd-parse.md ---"

# --- Test 1: prd-parse has design system detection ---
echo ""
echo "Test 1: Design system detection in prd-parse"
match=$(grep -c 'designs.*design-system' "$PRD_PARSE" 2>/dev/null || echo 0)
assert_ok "prd-parse references designs/*/design-system" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 2: prd-parse has existence guard ---
echo ""
echo "Test 2: Existence guard in prd-parse"
match=$(grep -c 'designs.*exists\|designs.*available\|Only if.*designs\|Otherwise.*Skip' "$PRD_PARSE" 2>/dev/null || echo 0)
assert_ok "prd-parse has existence guard for design artifacts" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 3: prd-parse preserves original sections ---
echo ""
echo "Test 3: Original sections preserved in prd-parse"
for section in "Preflight" "Role & Mindset" "Instructions" "IMPORTANT"; do
  match=$(grep -c "## $section" "$PRD_PARSE" 2>/dev/null || echo 0)
  assert_ok "prd-parse still has '$section' section" "$([ "$match" -ge 1 ] && echo true || echo false)"
done

# --- Test 4: prd-parse section count (no removals) ---
echo ""
echo "Test 4: Section count in prd-parse"
section_count=$(grep -c '^## ' "$PRD_PARSE" 2>/dev/null || echo 0)
assert_ok "prd-parse has >= 4 top-level sections (got $section_count)" "$([ "$section_count" -ge 4 ] && echo true || echo false)"

# =============================================
# Part B: epic-decompose.md design integration
# =============================================
echo ""
echo "--- epic-decompose.md ---"

# --- Test 5: epic-decompose has design spec detection ---
echo ""
echo "Test 5: Design spec detection in epic-decompose"
match=$(grep -c 'designs.*specs' "$EPIC_DECOMPOSE" 2>/dev/null || echo 0)
assert_ok "epic-decompose references designs/*/specs/" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 6: epic-decompose has guard condition ---
echo ""
echo "Test 6: Guard condition in epic-decompose"
match=$(grep -ci 'if.*available\|only if\|if no\|skip silently' "$EPIC_DECOMPOSE" 2>/dev/null || echo 0)
assert_ok "epic-decompose has conditional guard for design enrichment" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 7: epic-decompose mentions design_spec frontmatter ---
echo ""
echo "Test 7: design_spec frontmatter instruction in epic-decompose"
match=$(grep -c 'design_spec:' "$EPIC_DECOMPOSE" 2>/dev/null || echo 0)
assert_ok "epic-decompose mentions design_spec frontmatter field" "$([ "$match" -ge 1 ] && echo true || echo false)"

# --- Test 8: epic-decompose preserves original sections ---
echo ""
echo "Test 8: Original sections preserved in epic-decompose"
section_count=$(grep -c '^## \|^### Step' "$EPIC_DECOMPOSE" 2>/dev/null || echo 0)
assert_ok "epic-decompose has >= 5 sections/steps (got $section_count)" "$([ "$section_count" -ge 5 ] && echo true || echo false)"

# =============================================
# Part C: TEXT_ONLY mode pipeline coverage (NFR-3)
# =============================================
echo ""
echo "--- TEXT_ONLY Mode Pipeline Coverage ---"

# --- Test 9: prd-design.md handles TEXT_ONLY in each phase ---
echo ""
echo "Test 9: TEXT_ONLY mode coverage in prd-design.md"
PRD_DESIGN="$PROJECT_ROOT/commands/pm/prd-design.md"
text_only_refs=$(grep -c 'TEXT_ONLY' "$PRD_DESIGN" 2>/dev/null || echo 0)
assert_ok "prd-design.md references TEXT_ONLY (got $text_only_refs occurrences)" "$([ "$text_only_refs" -ge 3 ] && echo true || echo false)"

# TEXT_ONLY should have fallback behavior (no external tool dependency)
fallback_refs=$(grep -c 'native reasoning\|fallback\|not available\|without.*tool' "$PRD_DESIGN" 2>/dev/null || echo 0)
assert_ok "prd-design.md has fallback path for no-tool scenario" "$([ "$fallback_refs" -ge 1 ] && echo true || echo false)"

# --- Test 10: Detection scripts return correct codes for TEXT_ONLY ---
echo ""
echo "Test 10: Detection scripts support TEXT_ONLY (both fail = TEXT_ONLY)"
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf '$TMPDIR_TEST'" EXIT
# Neither UUPM nor Stitch → TEXT_ONLY mode
uupm_exit=$(cd "$TMPDIR_TEST" && bash "$PROJECT_ROOT/scripts/pm/detect-uupm.sh" >/dev/null 2>&1; echo $?)
stitch_exit=$(cd "$TMPDIR_TEST" && bash "$PROJECT_ROOT/scripts/pm/detect-stitch.sh" >/dev/null 2>&1; echo $?)
assert_ok "detect-uupm exits 1 in clean env (TEXT_ONLY)" "$([ "$uupm_exit" = "1" ] && echo true || echo false)"
assert_ok "detect-stitch exits 1 in clean env (TEXT_ONLY)" "$([ "$stitch_exit" = "1" ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"
trap - EXIT

# --- Test 11: Config supports TEXT_ONLY fallback ---
echo ""
echo "Test 11: Config lifecycle supports TEXT_ONLY fallback"
fallback_to_text=$(jq -r '.design_phase.fallback_to_text' "$PROJECT_ROOT/config/lifecycle.json" 2>/dev/null)
assert_ok "lifecycle.json design_phase.fallback_to_text is true" "$([ "$fallback_to_text" = "true" ] && echo true || echo false)"

# --- Summary ---
echo ""
echo "======================================="
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
