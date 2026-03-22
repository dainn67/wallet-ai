#!/bin/bash
# test_browse_commands.sh — E2E tests for ccpm-browse core commands
# Tests against fixture HTML files using file:// URLs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../.."
BROWSE="$PROJECT_ROOT/scripts/qa/ccpm-browse.sh"
FIXTURES="$PROJECT_ROOT/tests/fixtures/web-qa"
BASIC_URL="file://$FIXTURES/basic.html"
BROKEN_URL="file://$FIXTURES/broken.html"
SESSION="test-$$"

PASS=0
FAIL=0

# Cleanup session on exit
cleanup() {
  rm -rf "$PROJECT_ROOT/.claude/qa/sessions/$SESSION" 2>/dev/null || true
  rm -rf "$PROJECT_ROOT/.claude/qa/sessions/${SESSION}-b" 2>/dev/null || true
}
trap cleanup EXIT

assert_json_success() {
  local desc="$1"
  local output="$2"
  if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['success']==True" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    Output: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_json_error() {
  local desc="$1"
  local output="$2"
  if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['success']==False" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    Output: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1"
  local output="$2"
  local expected="$3"
  if echo "$output" | grep -q "$expected"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected '$expected')"
    echo "    Output: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== ccpm-browse E2E Tests ==="
echo ""

# --- Navigation ---
echo "[Navigation]"

OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BASIC_URL" 2>/dev/null)
assert_json_success "goto basic.html" "$OUT"
assert_contains "goto returns title" "$OUT" "CCPM QA Test Page"

OUT=$(bash "$BROWSE" -s="$SESSION" reload 2>/dev/null)
assert_json_success "reload" "$OUT"

# --- Capture ---
echo ""
echo "[Capture]"

OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BASIC_URL" 2>/dev/null)
OUT=$(bash "$BROWSE" -s="$SESSION" snapshot 2>/dev/null)
assert_json_success "snapshot" "$OUT"
assert_contains "snapshot has refs" "$OUT" "@e1"

# Check token count (<500)
TOKEN_EST=$(echo "$OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
est=d.get('data',{}).get('tokenEstimate',0)
print(est)
" 2>/dev/null || echo "0")
if [ "$TOKEN_EST" -gt 0 ] && [ "$TOKEN_EST" -lt 500 ]; then
  echo "  PASS: snapshot token count ($TOKEN_EST) < 500"
  PASS=$((PASS + 1))
else
  echo "  FAIL: snapshot token count ($TOKEN_EST) should be < 500"
  FAIL=$((FAIL + 1))
fi

SCREENSHOT_PATH="/tmp/ccpm-test-screenshot-$$.png"
OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BASIC_URL" 2>/dev/null)
OUT=$(bash "$BROWSE" -s="$SESSION" screenshot "$SCREENSHOT_PATH" 2>/dev/null)
assert_json_success "screenshot" "$OUT"
if [ -f "$SCREENSHOT_PATH" ]; then
  echo "  PASS: screenshot file created"
  PASS=$((PASS + 1))
  rm -f "$SCREENSHOT_PATH"
else
  echo "  FAIL: screenshot file not found"
  FAIL=$((FAIL + 1))
fi

OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BASIC_URL" 2>/dev/null)
OUT=$(bash "$BROWSE" -s="$SESSION" text 2>/dev/null)
assert_json_success "text" "$OUT"
assert_contains "text has content" "$OUT" "Test Page"

# --- Interaction ---
echo ""
echo "[Interaction]"

# First navigate and snapshot to populate refs
OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BASIC_URL" 2>/dev/null)
OUT=$(bash "$BROWSE" -s="$SESSION" snapshot 2>/dev/null)

# Find the ref for "Submit" button
SUBMIT_REF=$(echo "$OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
refs=d.get('data',{}).get('refs',[])
for r in refs:
    if r.get('role')=='button' and 'Submit' in r.get('name',''):
        print(r['id']); break
" 2>/dev/null || echo "")

if [ -n "$SUBMIT_REF" ]; then
  OUT=$(bash "$BROWSE" -s="$SESSION" click "$SUBMIT_REF" 2>/dev/null)
  assert_json_success "click $SUBMIT_REF (Submit button)" "$OUT"
else
  echo "  SKIP: Could not find Submit button ref"
  FAIL=$((FAIL + 1))
fi

# Find the ref for username input
INPUT_REF=$(echo "$OUT" | python3 -c "
import sys,json
# Re-read snapshot
import subprocess
" 2>/dev/null || echo "")
# Re-snapshot to get fresh refs
OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BASIC_URL" 2>/dev/null)
OUT=$(bash "$BROWSE" -s="$SESSION" snapshot 2>/dev/null)
INPUT_REF=$(echo "$OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
refs=d.get('data',{}).get('refs',[])
for r in refs:
    if r.get('role')=='textbox' and 'Username' in r.get('name',''):
        print(r['id']); break
" 2>/dev/null || echo "")

if [ -n "$INPUT_REF" ]; then
  OUT=$(bash "$BROWSE" -s="$SESSION" fill "$INPUT_REF" "testuser" 2>/dev/null)
  assert_json_success "fill $INPUT_REF (Username) with 'testuser'" "$OUT"
else
  echo "  SKIP: Could not find Username input ref"
  FAIL=$((FAIL + 1))
fi

# Click invalid ref
OUT=$(bash "$BROWSE" -s="$SESSION" click "@e999" 2>/dev/null || true)
assert_json_error "click @e999 returns error" "$OUT"
assert_contains "error mentions ref not found" "$OUT" "not found"

# Press key
OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BASIC_URL" 2>/dev/null)
OUT=$(bash "$BROWSE" -s="$SESSION" press "Tab" 2>/dev/null)
assert_json_success "press Tab" "$OUT"

# --- Inspection ---
echo ""
echo "[Inspection]"

OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BROKEN_URL" 2>/dev/null)
OUT=$(bash "$BROWSE" -s="$SESSION" console 2>/dev/null)
assert_json_success "console on broken.html" "$OUT"

OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BROKEN_URL" 2>/dev/null)
OUT=$(bash "$BROWSE" -s="$SESSION" links 2>/dev/null)
assert_json_success "links on broken.html" "$OUT"
assert_contains "links detects broken" "$OUT" "broken"

OUT=$(bash "$BROWSE" -s="$SESSION" goto "$BASIC_URL" 2>/dev/null)
OUT=$(bash "$BROWSE" -s="$SESSION" forms 2>/dev/null)
assert_json_success "forms on basic.html" "$OUT"
assert_contains "forms has count" "$OUT" "count"

# --- Session Isolation ---
echo ""
echo "[Session Isolation]"

OUT_A=$(bash "$BROWSE" -s="$SESSION" goto "$BASIC_URL" 2>/dev/null)
OUT_B=$(bash "$BROWSE" -s="${SESSION}-b" goto "$BROKEN_URL" 2>/dev/null)
assert_json_success "session A loads basic.html" "$OUT_A"
assert_json_success "session B loads broken.html" "$OUT_B"
assert_contains "session A has correct page" "$OUT_A" "CCPM QA Test Page"
assert_contains "session B has correct page" "$OUT_B" "Broken Test Page"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
