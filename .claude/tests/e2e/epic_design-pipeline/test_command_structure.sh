#!/usr/bin/env bash
# Tests for commands/pm/prd-design.md command file structure (Issue #126)
# Validates frontmatter, phases, mode handling, flag handling.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TARGET="$PROJECT_ROOT/commands/pm/prd-design.md"

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
echo " Tests: prd-design.md Command Structure"
echo "======================================="

# --- Test 1: File exists ---
echo ""
echo "Test 1: File existence"
assert_ok "commands/pm/prd-design.md exists" "$([ -f "$TARGET" ] && echo true || echo false)"

# --- Test 2: Frontmatter contains model: opus ---
echo ""
echo "Test 2: Frontmatter"
model_line=$(head -10 "$TARGET" | grep -c 'model: opus' || true)
assert_ok "frontmatter has model: opus" "$([ "$model_line" -ge 1 ] && echo true || echo false)"

# --- Test 3: Contains all three phases ---
echo ""
echo "Test 3: Phase sections"
phase1=$(grep -c 'Phase 1' "$TARGET" || true)
phase2=$(grep -c 'Phase 2' "$TARGET" || true)
phase3=$(grep -c 'Phase 3' "$TARGET" || true)
assert_ok "contains Phase 1 section" "$([ "$phase1" -ge 1 ] && echo true || echo false)"
assert_ok "contains Phase 2 section" "$([ "$phase2" -ge 1 ] && echo true || echo false)"
assert_ok "contains Phase 3 section" "$([ "$phase3" -ge 1 ] && echo true || echo false)"

# --- Test 4: References detection scripts ---
echo ""
echo "Test 4: Detection script references"
uupm_ref=$(grep -c 'detect-uupm' "$TARGET" || true)
stitch_ref=$(grep -c 'detect-stitch' "$TARGET" || true)
assert_ok "references detect-uupm.sh" "$([ "$uupm_ref" -ge 1 ] && echo true || echo false)"
assert_ok "references detect-stitch.sh" "$([ "$stitch_ref" -ge 1 ] && echo true || echo false)"

# --- Test 5: References .claude/designs/ directory ---
echo ""
echo "Test 5: Designs directory reference"
designs_ref=$(grep -c 'designs/' "$TARGET" || true)
assert_ok "references .claude/designs/ directory (got $designs_ref occurrences)" "$([ "$designs_ref" -ge 3 ] && echo true || echo false)"

# --- Test 6: Contains all 4 mode names ---
echo ""
echo "Test 6: Operation modes"
full_mode=$(grep -c 'FULL' "$TARGET" || true)
design_only=$(grep -c 'DESIGN_ONLY' "$TARGET" || true)
mockup_only=$(grep -c 'MOCKUP_ONLY' "$TARGET" || true)
text_only=$(grep -c 'TEXT_ONLY' "$TARGET" || true)
assert_ok "contains FULL mode" "$([ "$full_mode" -ge 1 ] && echo true || echo false)"
assert_ok "contains DESIGN_ONLY mode" "$([ "$design_only" -ge 1 ] && echo true || echo false)"
assert_ok "contains MOCKUP_ONLY mode" "$([ "$mockup_only" -ge 1 ] && echo true || echo false)"
assert_ok "contains TEXT_ONLY mode" "$([ "$text_only" -ge 1 ] && echo true || echo false)"

# --- Test 7: Contains re-run handling ---
echo ""
echo "Test 7: Re-run handling"
rerun_ref=$(grep -ci 're-run\|re_run\|rerun\|existing designs' "$TARGET" || true)
assert_ok "contains re-run handling instructions" "$([ "$rerun_ref" -ge 1 ] && echo true || echo false)"

# --- Test 8: Contains --screen flag handling ---
echo ""
echo "Test 8: --screen flag handling"
screen_ref=$(grep -c '\-\-screen' "$TARGET" || true)
assert_ok "contains --screen flag handling (got $screen_ref refs)" "$([ "$screen_ref" -ge 2 ] && echo true || echo false)"

# --- Test 9: Mode determination logic ---
echo ""
echo "Test 9: Mode determination logic"
# Should define mode based on tool availability
mode_logic=$(grep -c 'uupm_available\|stitch_available' "$TARGET" || true)
assert_ok "mode logic references tool availability variables" "$([ "$mode_logic" -ge 2 ] && echo true || echo false)"

# --- Summary ---
echo ""
echo "======================================="
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
