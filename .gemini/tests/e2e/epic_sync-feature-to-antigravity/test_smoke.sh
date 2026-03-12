#!/usr/bin/env bash
# Smoke tests for epic sync-feature-to-antigravity
# Validates all deliverables exist with correct structure and content.
# Uses REAL project files — no fixtures.

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
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "═══════════════════════════════════════"
echo " Smoke Tests: sync-feature-to-antigravity"
echo "═══════════════════════════════════════"

# --- Smoke 1: Config file valid JSON ---
echo ""
echo "Smoke 1: Config file"
jq . "$PROJECT_ROOT/config/antigravity-sync.json" > /dev/null 2>&1
assert_ok "config/antigravity-sync.json is valid JSON" "$([ $? -eq 0 ] && echo true || echo false)"

jq -e '.mappings.workflows.source' "$PROJECT_ROOT/config/antigravity-sync.json" > /dev/null 2>&1
assert_ok "config has workflows mapping" "$([ $? -eq 0 ] && echo true || echo false)"

jq -e '.mappings.rules.source' "$PROJECT_ROOT/config/antigravity-sync.json" > /dev/null 2>&1
assert_ok "config has rules mapping" "$([ $? -eq 0 ] && echo true || echo false)"

jq -e '.skip_patterns' "$PROJECT_ROOT/config/antigravity-sync.json" > /dev/null 2>&1
assert_ok "config has skip_patterns" "$([ $? -eq 0 ] && echo true || echo false)"

# --- Smoke 2: Model tiers config ---
echo ""
echo "Smoke 2: Model tiers config"
jq . "$PROJECT_ROOT/config/model-tiers.json" > /dev/null 2>&1
assert_ok "config/model-tiers.json is valid JSON" "$([ $? -eq 0 ] && echo true || echo false)"

tier=$(jq -r '.commands["antigravity-sync"]' "$PROJECT_ROOT/config/model-tiers.json" 2>/dev/null)
assert_ok "model-tiers has antigravity-sync entry" "$([ "$tier" = "medium" ] && echo true || echo false)"

# --- Smoke 3: Script exists and executable ---
echo ""
echo "Smoke 3: Script"
assert_ok "scripts/pm/antigravity-sync.sh exists" "$([ -f "$PROJECT_ROOT/scripts/pm/antigravity-sync.sh" ] && echo true || echo false)"
assert_ok "scripts/pm/antigravity-sync.sh is executable" "$([ -x "$PROJECT_ROOT/scripts/pm/antigravity-sync.sh" ] && echo true || echo false)"

# --- Smoke 4: Command entry point ---
echo ""
echo "Smoke 4: Command entry point"
assert_ok "commands/pm/antigravity-sync.md exists" "$([ -f "$PROJECT_ROOT/commands/pm/antigravity-sync.md" ] && echo true || echo false)"
assert_ok "command has model: in frontmatter" "$(grep -q '^model:' "$PROJECT_ROOT/commands/pm/antigravity-sync.md" 2>/dev/null && echo true || echo false)"

# --- Smoke 5: Gap detection runs without errors ---
echo ""
echo "Smoke 5: Gap detection"
detect_output=$(bash "$PROJECT_ROOT/scripts/pm/antigravity-sync.sh" detect 2>&1)
detect_exit=$?
assert_ok "detect subcommand exits 0" "$([ $detect_exit -eq 0 ] && echo true || echo false)"
assert_ok "detect reports gap count" "$(echo "$detect_output" | grep -q 'Total:' && echo true || echo false)"

# --- Smoke 6: Sample workflow format ---
echo ""
echo "Smoke 6: Workflow format"
sample=$(ls "$PROJECT_ROOT/antigravity/workflows/pm-status.md" 2>/dev/null)
if [ -n "$sample" ]; then
  assert_ok "sample workflow has name: field" "$(grep -q '^name:' "$sample" && echo true || echo false)"
  assert_ok "sample workflow has description: field" "$(grep -q '^description:' "$sample" && echo true || echo false)"
  assert_ok "sample workflow has # tier: comment" "$(grep -q '^# tier:' "$sample" && echo true || echo false)"
  assert_ok "sample workflow has NO model: field" "$(grep -q '^model:' "$sample" && echo false || echo true)"
  assert_ok "sample workflow has NO allowed-tools: field" "$(grep -q '^allowed-tools:' "$sample" && echo false || echo true)"
else
  assert_ok "sample workflow pm-status.md exists" "false"
fi

# --- Smoke 7: Tech context updated ---
echo ""
echo "Smoke 7: Tech context"
assert_ok "tech-context has Antigravity Sync section" "$(grep -qi 'antigravity.*sync' "$PROJECT_ROOT/.gemini/context/tech-context.md" 2>/dev/null && echo true || echo false)"

# --- Smoke 8: Existing test suite passes ---
echo ""
echo "Smoke 8: Existing test suite"
test_output=$(bash "$PROJECT_ROOT/tests/test-antigravity-sync.sh" 2>&1)
test_exit=$?
assert_ok "test-antigravity-sync.sh passes" "$([ $test_exit -eq 0 ] && echo true || echo false)"

# --- Smoke 9: Format consistency across all workflows ---
echo ""
echo "Smoke 9: Format consistency"
old_format_count=0
total_wf=0
for wf in "$PROJECT_ROOT"/antigravity/workflows/pm-*.md; do
  [ -f "$wf" ] || continue
  total_wf=$((total_wf + 1))
  if grep -q '^  steps:' "$wf" 2>/dev/null; then
    old_format_count=$((old_format_count + 1))
  fi
done
assert_ok "all $total_wf workflows use unified format (no old steps: YAML)" "$([ $old_format_count -eq 0 ] && echo true || echo false)"

# --- Summary ---
echo ""
echo "═══════════════════════════════════════"
echo " Smoke Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
