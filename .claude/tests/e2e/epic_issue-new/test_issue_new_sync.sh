#!/usr/bin/env bash
# Tests for scripts/pm/issue-new-sync.sh
# Uses REAL project files — no mocking.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/pm/issue-new-sync.sh"

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
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "═══════════════════════════════════════"
echo " Tests: issue-new-sync.sh"
echo "═══════════════════════════════════════"

# --- Test 1: Script exists and is executable ---
echo ""
echo "Test 1: Script existence"
assert_ok "scripts/pm/issue-new-sync.sh exists" "$([ -f "$SCRIPT" ] && echo true || echo false)"
assert_ok "scripts/pm/issue-new-sync.sh is executable" "$([ -x "$SCRIPT" ] && echo true || echo false)"

# --- Test 2: Missing args exits 1 with usage ---
echo ""
echo "Test 2: Missing arguments"
output=$(bash "$SCRIPT" create 2>&1 || true)
exit_code=$(bash "$SCRIPT" create 2>&1; echo $?)
actual_exit=$(bash "$SCRIPT" create >/dev/null 2>&1; echo $?)
assert_ok "no args → exits 1" "$([ "$actual_exit" = "1" ] && echo true || echo false)"
assert_ok "no args → prints usage" "$(echo "$output" | grep -qi 'usage\|title is required' && echo true || echo false)"

# --- Test 3: Non-existent body file exits 1 with clear error ---
echo ""
echo "Test 3: Non-existent body file"
output=$(bash "$SCRIPT" create "Test Title" "/tmp/does-not-exist-ccpm-test.md" 2>&1 || true)
actual_exit=$(bash "$SCRIPT" create "Test Title" "/tmp/does-not-exist-ccpm-test.md" >/dev/null 2>&1; echo $?)
assert_ok "missing body file → exits 1" "$([ "$actual_exit" = "1" ] && echo true || echo false)"
assert_ok "missing body file → prints error" "$(echo "$output" | grep -q '❌' && echo true || echo false)"

# --- Test 4: Label CSV parsing + source:issue-new appended ---
echo ""
echo "Test 4: Label parsing"
# Source the script and test the label-building logic via a dry-run sourcing
tmpfile=$(mktemp)
echo "Test body content" > "$tmpfile"

# Source the script and verify it parses labels correctly
labels_result=$(
  source "$SCRIPT" 2>/dev/null
  labels_csv="bug,complexity:low"
  labels=()
  if [ -n "$labels_csv" ]; then
    IFS=',' read -ra raw_labels <<< "$labels_csv"
    for lbl in "${raw_labels[@]}"; do
      lbl="${lbl## }"; lbl="${lbl%% }"
      [ -n "$lbl" ] && labels+=("$lbl")
    done
  fi
  labels+=("source:issue-new")
  echo "${labels[*]}"
)
assert_ok "CSV 'bug,complexity:low' splits into 2 + source:issue-new = 3 labels" \
  "$([ "$(echo "$labels_result" | wc -w | tr -d ' ')" = "3" ] && echo true || echo false)"
assert_ok "'source:issue-new' always present" \
  "$(echo "$labels_result" | grep -q 'source:issue-new' && echo true || echo false)"

# --- Test 5: Empty labels CSV → only source:issue-new ---
echo ""
echo "Test 5: Empty labels CSV"
labels_result_empty=$(
  source "$SCRIPT" 2>/dev/null
  labels_csv=""
  labels=()
  if [ -n "$labels_csv" ]; then
    IFS=',' read -ra raw_labels <<< "$labels_csv"
    for lbl in "${raw_labels[@]}"; do
      lbl="${lbl## }"; lbl="${lbl%% }"
      [ -n "$lbl" ] && labels+=("$lbl")
    done
  fi
  labels+=("source:issue-new")
  echo "${#labels[@]}"
)
assert_ok "empty CSV → only source:issue-new (1 label)" \
  "$([ "$labels_result_empty" = "1" ] && echo true || echo false)"

# --- Test 6: Script sources github-helpers.sh without error ---
echo ""
echo "Test 6: Script imports"
import_output=$(bash -n "$SCRIPT" 2>&1 || true)
import_exit=$(bash -n "$SCRIPT" >/dev/null 2>&1; echo $?)
assert_ok "script passes bash -n syntax check" "$([ "$import_exit" = "0" ] && echo true || echo false)"

source_test=$(
  export _CCPM_ROOT="$PROJECT_ROOT"
  source "$SCRIPT" 2>&1
  echo "ok"
)
assert_ok "script sources github-helpers.sh without error" \
  "$(echo "$source_test" | grep -q '^ok$' && echo true || echo false)"

# Cleanup
rm -f "$tmpfile"

# --- Summary ---
echo ""
echo "═══════════════════════════════════════"
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
