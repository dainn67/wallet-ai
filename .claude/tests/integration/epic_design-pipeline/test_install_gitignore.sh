#!/usr/bin/env bash
# Integration tests for .gitignore handling in install scripts (Issue #121)
# Uses temporary directories — no mocking.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INSTALL_SCRIPT="$PROJECT_ROOT/install/local_install.sh"

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
echo " Tests: Install .gitignore handling"
echo "======================================="

# --- Test 1: Fresh install adds .claude/designs/ to .gitignore ---
echo ""
echo "Test 1: Fresh install"
TMPDIR_TEST=$(mktemp -d)
bash "$INSTALL_SCRIPT" "$TMPDIR_TEST" >/dev/null 2>&1
has_entry=$(grep -cxF '.claude/designs/' "$TMPDIR_TEST/.gitignore" 2>/dev/null || echo 0)
assert_ok ".gitignore contains .claude/designs/ after install" "$([ "$has_entry" -ge 1 ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 2: Idempotent — running twice does not duplicate entry ---
echo ""
echo "Test 2: Idempotent install"
TMPDIR_TEST=$(mktemp -d)
bash "$INSTALL_SCRIPT" "$TMPDIR_TEST" >/dev/null 2>&1
bash "$INSTALL_SCRIPT" "$TMPDIR_TEST" >/dev/null 2>&1
count=$(grep -cxF '.claude/designs/' "$TMPDIR_TEST/.gitignore" 2>/dev/null || echo 0)
assert_ok ".claude/designs/ appears exactly once after two installs (got $count)" "$([ "$count" = "1" ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 3: Existing .gitignore preserved ---
echo ""
echo "Test 3: Existing .gitignore content preserved"
TMPDIR_TEST=$(mktemp -d)
echo "node_modules/" > "$TMPDIR_TEST/.gitignore"
echo ".env" >> "$TMPDIR_TEST/.gitignore"
bash "$INSTALL_SCRIPT" "$TMPDIR_TEST" >/dev/null 2>&1
has_node=$(grep -cxF 'node_modules/' "$TMPDIR_TEST/.gitignore" 2>/dev/null || echo 0)
has_env=$(grep -cxF '.env' "$TMPDIR_TEST/.gitignore" 2>/dev/null || echo 0)
has_designs=$(grep -cxF '.claude/designs/' "$TMPDIR_TEST/.gitignore" 2>/dev/null || echo 0)
assert_ok "node_modules/ preserved" "$([ "$has_node" -ge 1 ] && echo true || echo false)"
assert_ok ".env preserved" "$([ "$has_env" -ge 1 ] && echo true || echo false)"
assert_ok ".claude/designs/ added" "$([ "$has_designs" -ge 1 ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Summary ---
echo ""
echo "======================================="
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
