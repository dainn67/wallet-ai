#!/bin/bash
# Integration Tests: epic-verify-b.md QA Agent Tier section
# Tests: Agent in allowed-tools, QA Agent Tier section exists, non-blocking pattern
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

VERIFY_B="$REPO_ROOT/commands/pm/epic-verify-b.md"

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected to contain '$needle'"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "  ❌ $desc: should NOT contain '$needle'"
    (( FAIL++ )) || true
  else
    echo "  ✅ $desc"
    (( PASS++ )) || true
  fi
}

echo "=== epic-verify-b.md QA Agent Tier Integration Tests ==="

# Prerequisites
echo ""
echo "-- Prerequisites --"
if [ -f "$VERIFY_B" ]; then
  echo "  ✅ commands/pm/epic-verify-b.md exists"
  (( PASS++ )) || true
else
  echo "  ❌ commands/pm/epic-verify-b.md not found"
  (( FAIL++ )) || true
  echo ""; echo "Results: $PASS passed, $FAIL failed"; exit 1
fi

CONTENT=$(cat "$VERIFY_B")
FRONTMATTER=$(head -20 "$VERIFY_B")

# Test 1: Agent in allowed-tools frontmatter
echo ""
echo "-- Agent in allowed-tools --"
assert_contains "frontmatter includes 'Agent' in allowed-tools" "Agent" "$FRONTMATTER"

# Test 2: QA Agent Tier section exists
echo ""
echo "-- QA Agent Tier section --"
assert_contains "QA Agent Tier section exists" "QA Agent Tier" "$CONTENT"

# Test 3: detect-agents.sh call pattern
echo ""
echo "-- detect-agents.sh integration --"
assert_contains "detect-agents call present" "detect-agents.sh" "$CONTENT"

# Test 4: NFR-2 — non-blocking: must NOT set FAIL=1 from QA results
echo ""
echo "-- NFR-2: non-blocking QA tier --"
# The QA section must explicitly state it does not set FAIL=1
assert_contains "non-blocking comment present" "Never set FAIL=1" "$CONTENT"

# Test 5: NFR-2 — skip path: graceful skip with report when no agents
echo ""
echo "-- NFR-2: graceful skip path --"
assert_contains "skip path: no QA agents message" "No QA agents detected" "$CONTENT"

# Test 6: NFR-4 — backward compat: non-iOS projects see zero change
# Verify the skip path produces output without FAIL
echo ""
echo "-- NFR-4: backward compat skip produces no FAIL --"
assert_not_contains "skip path does not set FAIL=1 for non-iOS" "FAIL=1" \
  "$(printf '%s' "$CONTENT" | grep -A5 "No QA agents detected" || true)"

# Test 7: Report section format
echo ""
echo "-- QA Agent Results report section --"
assert_contains "report section header present" "QA Agent Results" "$CONTENT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
