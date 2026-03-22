#!/bin/bash
# E2E Tests: Web QA Platform — Pipeline Integration
# Tests: epic-verify-b references QA, registry has web agent, all scripts executable
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

VERIFY_B="$REPO_ROOT/commands/pm/epic-verify-b.md"
REGISTRY="$REPO_ROOT/config/qa-agents.json"

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

assert_executable() {
  local desc="$1" path="$2"
  if [ -x "$path" ]; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: $path is not executable"
    (( FAIL++ )) || true
  fi
}

echo "=== Web QA Platform Pipeline Integration E2E Tests ==="

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

if [ -f "$REGISTRY" ]; then
  echo "  ✅ config/qa-agents.json exists"
  (( PASS++ )) || true
else
  echo "  ❌ config/qa-agents.json not found"
  (( FAIL++ )) || true
  echo ""; echo "Results: $PASS passed, $FAIL failed"; exit 1
fi

CONTENT=$(cat "$VERIFY_B")

# Test 1: epic-verify-b references detect-agents.sh (QA pipeline entry point)
echo ""
echo "-- QA pipeline entry point --"
assert_contains "epic-verify-b references detect-agents.sh" "detect-agents.sh" "$CONTENT"

# Test 2: epic-verify-b has per-agent iteration (web QA support)
echo ""
echo "-- Per-agent dispatch --"
assert_contains "per-agent iteration: AGENT_NAME field" "AGENT_NAME" "$CONTENT"
assert_contains "per-agent prompt resolution: AGENT_COMMAND" "AGENT_COMMAND" "$CONTENT"

# Test 3: Web QA Results section label in verify-b
echo ""
echo "-- Web QA Results section --"
assert_contains "Web QA Results section label present" "Web QA" "$CONTENT"

# Test 4: Non-blocking QA tier
echo ""
echo "-- Non-blocking QA tier --"
assert_contains "non-blocking comment present" "Never set FAIL=1" "$CONTENT"

# Test 5: registry has web-qa-agent
echo ""
echo "-- Registry: web-qa-agent entry --"
REGISTRY_CONTENT=$(cat "$REGISTRY")
assert_contains "registry has web-qa-agent" "web-qa-agent" "$REGISTRY_CONTENT"

# Test 6: web-qa-agent has detect_command field
echo ""
echo "-- Registry: web-qa-agent detect_command --"
assert_contains "web-qa-agent has detect_command" "detect_command" "$REGISTRY_CONTENT"

# Test 7: web-qa-agent references web-qa-agent-prompt.md
echo ""
echo "-- Registry: web-qa-agent prompt path --"
assert_contains "web-qa-agent references web-qa-agent-prompt" "web-qa-agent-prompt.md" "$REGISTRY_CONTENT"

# Test 8: All QA scripts are executable
echo ""
echo "-- Script executability --"
for script in \
  "$REPO_ROOT/scripts/qa/detect-agents.sh" \
  "$REPO_ROOT/scripts/qa/detect-web.sh" \
  "$REPO_ROOT/scripts/qa/detect-server.sh" \
  "$REPO_ROOT/scripts/qa/health-score.sh" \
  "$REPO_ROOT/scripts/qa/generate-tests.sh" \
  "$REPO_ROOT/scripts/qa/ccpm-browse.sh"; do
  name=$(basename "$script")
  if [ -f "$script" ]; then
    assert_executable "scripts/qa/$name is executable" "$script"
  else
    echo "  ❌ scripts/qa/$name not found"
    (( FAIL++ )) || true
  fi
done

# Test 9: web-qa-agent-prompt.md exists
echo ""
echo "-- web-qa-agent-prompt.md exists --"
PROMPT="$REPO_ROOT/prompts/web-qa-agent-prompt.md"
if [ -f "$PROMPT" ]; then
  echo "  ✅ prompts/web-qa-agent-prompt.md exists"
  (( PASS++ )) || true
else
  echo "  ❌ prompts/web-qa-agent-prompt.md not found — run T209 first"
  (( FAIL++ )) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
