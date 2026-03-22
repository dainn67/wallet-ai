#!/bin/bash
# Tests for ccpm-browse.sh CLI argument parsing and error handling
# No mocking of Playwright/Node.js execution — tests focus on shell logic

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BROWSE_SH="$REPO_ROOT/scripts/qa/ccpm-browse.sh"

PASS=0
FAIL=0

_pass() { printf "  ✓ %s\n" "$1"; PASS=$((PASS + 1)); }
_fail() { printf "  ✗ %s\n" "$1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Test: --help outputs usage info
# ---------------------------------------------------------------------------
printf "Test: --help outputs usage\n"
if bash "$BROWSE_SH" --help 2>&1 | grep -q "COMMAND"; then
  _pass "--help shows COMMAND in usage"
else
  _fail "--help did not show usage"
fi

if bash "$BROWSE_SH" --help 2>&1 | grep -q "goto"; then
  _pass "--help lists 'goto' command"
else
  _fail "--help did not list goto command"
fi

# ---------------------------------------------------------------------------
# Test: invalid command returns JSON error with valid command list
# ---------------------------------------------------------------------------
printf "Test: invalid command returns JSON error\n"
output=$(bash "$BROWSE_SH" -s=test badcmd 2>/dev/null || true)

if printf '%s' "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['success'] == False" 2>/dev/null; then
  _pass "invalid command returns success=false"
else
  _fail "invalid command did not return success=false (output: $output)"
fi

if printf '%s' "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'goto' in d.get('error','')" 2>/dev/null; then
  _pass "invalid command error lists valid commands"
else
  _fail "invalid command error missing valid command list (output: $output)"
fi

if printf '%s' "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'badcmd' in d.get('error','')" 2>/dev/null; then
  _pass "invalid command error includes the unknown command name"
else
  _fail "invalid command error missing unknown command name (output: $output)"
fi

# ---------------------------------------------------------------------------
# Test: missing node → JSON error (via PATH with fake node dir)
# ---------------------------------------------------------------------------
printf "Test: missing node returns JSON error\n"
FAKE_BIN=$(mktemp -d)
# Keep system dirs but exclude node — so `command -v node` will fail
output=$( (export PATH="$FAKE_BIN:/usr/bin:/bin"; bash "$BROWSE_SH" -s=test goto "http://example.com") 2>/dev/null || true)
rm -rf "$FAKE_BIN"

if printf '%s' "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['success'] == False" 2>/dev/null; then
  _pass "missing node returns success=false"
else
  _fail "missing node did not return JSON error (output: $output)"
fi

if printf '%s' "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'Node.js' in d.get('error','')" 2>/dev/null; then
  _pass "missing node error mentions Node.js"
else
  _fail "missing node error missing Node.js mention (output: $output)"
fi

# ---------------------------------------------------------------------------
# Test: argument parsing — session, command, args extracted correctly
# ---------------------------------------------------------------------------
printf "Test: argument parsing\n"

# Test that -s=mysession is parsed (we can verify by checking session dir creation)
# We do this by temporarily pointing PROJECT_ROOT to /tmp and checking the dir
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Since the script walks up to find .claude/, we can't easily test session dir
# without a real node. Instead, verify via error path that session flag doesn't
# confuse command parsing.
output=$(bash "$BROWSE_SH" -s=mysession invalidcmd 2>/dev/null || true)
if printf '%s' "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'invalidcmd' in d.get('error','')" 2>/dev/null; then
  _pass "-s=session flag doesn't interfere with command parsing"
else
  _fail "-s=session flag interfered with command parsing (output: $output)"
fi

# Test valid command with -s= flag still reaches node check (not rejected early)
# Since node is available but index.js doesn't exist, we get a different error than "Unknown command"
output=$(bash "$BROWSE_SH" -s=mysession goto "http://example.com" 2>/dev/null || true)
if printf '%s' "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'Unknown command' not in (d.get('error') or '')" 2>/dev/null; then
  _pass "valid command with -s= flag passes command validation"
else
  _fail "valid command with -s= flag incorrectly failed command validation (output: $output)"
fi

# ---------------------------------------------------------------------------
# Test: no command provided
# ---------------------------------------------------------------------------
printf "Test: no command provided returns JSON error\n"
output=$(bash "$BROWSE_SH" 2>/dev/null || true)
if printf '%s' "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['success'] == False" 2>/dev/null; then
  _pass "no command returns success=false"
else
  _fail "no command did not return JSON error (output: $output)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n%d passed, %d failed\n" "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
