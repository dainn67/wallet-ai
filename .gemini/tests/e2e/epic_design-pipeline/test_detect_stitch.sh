#!/usr/bin/env bash
# Tests for scripts/pm/detect-stitch.sh
# Uses temporary directories — no mocking.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/pm/detect-stitch.sh"

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
echo " Tests: detect-stitch.sh"
echo "======================================="

# --- Test 1: Script exists and is executable ---
echo ""
echo "Test 1: Script existence"
assert_ok "scripts/pm/detect-stitch.sh exists" "$([ -f "$SCRIPT" ] && echo true || echo false)"
assert_ok "scripts/pm/detect-stitch.sh is executable" "$([ -x "$SCRIPT" ] && echo true || echo false)"

# --- Test 2: Syntax check ---
echo ""
echo "Test 2: Syntax check"
syntax_exit=$(bash -n "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "script passes bash -n syntax check" "$([ "$syntax_exit" = "0" ] && echo true || echo false)"

# --- Test 3: No settings files — exits 1 ---
echo ""
echo "Test 3: No settings files (clean temp dir)"
TMPDIR_TEST=$(mktemp -d)
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1 || true)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 1 when no settings files" "$([ "$actual_exit" = "1" ] && echo true || echo false)"
assert_ok "stdout contains 'stitch-mcp:not-available'" "$(echo "$output" | grep -q 'stitch-mcp:not-available' && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 4: settings.json with Stitch MCP — exits 0 ---
echo ""
echo "Test 4: settings.json with Stitch MCP configured"
TMPDIR_TEST=$(mktemp -d)
cat > "$TMPDIR_TEST/settings.json" << 'SETTINGSEOF'
{
  "mcpServers": {
    "stitch": {
      "command": "stitch-mcp",
      "args": ["serve"]
    }
  }
}
SETTINGSEOF
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 0 when Stitch MCP found" "$([ "$actual_exit" = "0" ] && echo true || echo false)"
assert_ok "stdout contains 'stitch-mcp:available'" "$(echo "$output" | grep -q 'stitch-mcp:available' && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 5: settings.json without Stitch — exits 1 ---
echo ""
echo "Test 5: settings.json without Stitch MCP"
TMPDIR_TEST=$(mktemp -d)
cat > "$TMPDIR_TEST/settings.json" << 'SETTINGSEOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "fs-mcp"
    }
  }
}
SETTINGSEOF
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1 || true)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 1 when no Stitch in settings" "$([ "$actual_exit" = "1" ] && echo true || echo false)"
assert_ok "stdout contains 'stitch-mcp:not-available'" "$(echo "$output" | grep -q 'stitch-mcp:not-available' && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 6: Malformed JSON — exits 1 gracefully ---
echo ""
echo "Test 6: Malformed JSON settings file"
TMPDIR_TEST=$(mktemp -d)
echo "{ this is not valid json }" > "$TMPDIR_TEST/settings.json"
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1 || true)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 1 on malformed JSON" "$([ "$actual_exit" = "1" ] && echo true || echo false)"
assert_ok "stdout contains 'stitch-mcp:not-available'" "$(echo "$output" | grep -q 'stitch-mcp:not-available' && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 7: No stderr output on failure ---
echo ""
echo "Test 7: No stderr on failure (malformed JSON)"
TMPDIR_TEST=$(mktemp -d)
echo "{ broken }" > "$TMPDIR_TEST/settings.json"
stderr_output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1 1>/dev/null || true)
assert_ok "no stderr output on malformed JSON" "$([ -z "$stderr_output" ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 8: .gemini/settings.local.json takes priority ---
echo ""
echo "Test 8: .gemini/settings.local.json priority"
TMPDIR_TEST=$(mktemp -d)
mkdir -p "$TMPDIR_TEST/.gemini"
cat > "$TMPDIR_TEST/.gemini/settings.local.json" << 'SETTINGSEOF'
{
  "mcpServers": {
    "stitch-design": {
      "command": "stitch"
    }
  }
}
SETTINGSEOF
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 0 for .gemini/settings.local.json with stitch" "$([ "$actual_exit" = "0" ] && echo true || echo false)"
assert_ok "stdout contains 'stitch-mcp:available'" "$(echo "$output" | grep -q 'stitch-mcp:available' && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 9: Case-insensitive Stitch match ---
echo ""
echo "Test 9: Case-insensitive match"
TMPDIR_TEST=$(mktemp -d)
cat > "$TMPDIR_TEST/settings.json" << 'SETTINGSEOF'
{
  "mcpServers": {
    "Stitch-MCP-Server": {
      "command": "stitch"
    }
  }
}
SETTINGSEOF
output=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" 2>&1)
actual_exit=$(cd "$TMPDIR_TEST" && bash "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "exits 0 for case-insensitive 'Stitch' match" "$([ "$actual_exit" = "0" ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Summary ---
echo ""
echo "======================================="
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
