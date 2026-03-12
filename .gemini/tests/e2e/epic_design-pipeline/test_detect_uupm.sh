#!/usr/bin/env bash
# Tests for scripts/pm/detect-uupm.sh
# Uses temporary directories — no mocking.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/pm/detect-uupm.sh"

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
echo " Tests: detect-uupm.sh"
echo "======================================="

# --- Test 1: Script exists and is executable ---
echo ""
echo "Test 1: Script existence"
assert_ok "scripts/pm/detect-uupm.sh exists" "$([ -f "$SCRIPT" ] && echo true || echo false)"
assert_ok "scripts/pm/detect-uupm.sh is executable" "$([ -x "$SCRIPT" ] && echo true || echo false)"

# --- Test 2: Syntax check ---
echo ""
echo "Test 2: Syntax check"
syntax_exit=$(bash -n "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "script passes bash -n syntax check" "$([ "$syntax_exit" = "0" ] && echo true || echo false)"

# --- Test 3: No UUPM installed — exits 1 ---
echo ""
echo "Test 3: UUPM not installed (clean temp dir)"
TMPDIR_TEST=$(mktemp -d)
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1 || true)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 1 when UUPM not found" "$([ "$actual_exit" = "1" ] && echo true || echo false)"
assert_ok "stdout contains 'uupm:not-installed'" "$(echo "$output" | grep -q 'uupm:not-installed' && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 4: UUPM installed locally with SKILL.md — exits 0 ---
echo ""
echo "Test 4: UUPM installed locally (SKILL.md present)"
TMPDIR_TEST=$(mktemp -d)
mkdir -p "$TMPDIR_TEST/.gemini-plugin/skills/ui-ux-pro-max"
echo "# UI UX Pro Max Skill" > "$TMPDIR_TEST/.gemini-plugin/skills/ui-ux-pro-max/SKILL.md"
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 0 when UUPM SKILL.md found" "$([ "$actual_exit" = "0" ] && echo true || echo false)"
assert_ok "stdout contains path to UUPM" "$(echo "$output" | grep -q 'ui-ux-pro-max' && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 5: Directory exists but empty (broken install) — exits 1 ---
echo ""
echo "Test 5: UUPM directory exists but empty (broken install)"
TMPDIR_TEST=$(mktemp -d)
mkdir -p "$TMPDIR_TEST/.gemini-plugin/skills/ui-ux-pro-max"
# No SKILL.md or search.py — broken install
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1 || true)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 1 when directory empty (broken)" "$([ "$actual_exit" = "1" ] && echo true || echo false)"
assert_ok "stdout contains 'uupm:not-installed'" "$(echo "$output" | grep -q 'uupm:not-installed' && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 6: UUPM installed with search.py — exits 0 ---
echo ""
echo "Test 6: UUPM installed with search.py"
TMPDIR_TEST=$(mktemp -d)
mkdir -p "$TMPDIR_TEST/.gemini-plugin/skills/ui-ux-pro-max"
echo "# search module" > "$TMPDIR_TEST/.gemini-plugin/skills/ui-ux-pro-max/search.py"
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 0 when search.py found" "$([ "$actual_exit" = "0" ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 7: No stderr output on failure ---
echo ""
echo "Test 7: No stderr on failure"
TMPDIR_TEST=$(mktemp -d)
stderr_output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1 1>/dev/null || true)
assert_ok "no stderr output on failure" "$([ -z "$stderr_output" ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Summary ---
echo ""
echo "======================================="
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
