#!/usr/bin/env bash
# Integration tests for Superpowers Integration epic
# Tests cross-component integration points identified in Phase A
#
# Uses PROJECT_ROOT as CCPM_ROOT (same as E2E tests) since hooks
# reference source code at project root, not installed .gemini/ copies.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CCPM_ROOT="$PROJECT_ROOT"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    echo -e "  ${GREEN}✅${NC} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌${NC} $desc (expected=$expected, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

setup_state() {
  mkdir -p "$CCPM_ROOT/context/verify"
  cat > "$CCPM_ROOT/context/verify/state.json" <<STEOF
{
  "active_task": {
    "issue_number": $1,
    "epic": "$2",
    "type": "$3",
    "verify_mode": "${4:-STRICT}",
    "tech_stack": "generic",
    "max_iterations": 20,
    "current_iteration": 0,
    "started_at": "2026-01-01T00:00:00Z",
    "iterations": []
  }
}
STEOF
}

cleanup() {
  rm -f "$CCPM_ROOT/context/verify/state.json"
  rm -rf ".gemini/epics/integ-test"
  rm -rf "$CCPM_ROOT/epics/integ-test"
}

echo ""
echo "═══ Integration Tests: Superpowers Integration ═══"
echo ""

# --- IT-1: lifecycle-helpers.sh ↔ detect-superpowers.sh ---
echo "── IT-1: lifecycle-helpers → detect-superpowers ──"

# If global plugin exists, baseline detection succeeds (exit 0), otherwise fails (exit 1)
if [ -f "$HOME/.gemini/settings.json" ] && grep -q '"superpowers' "$HOME/.gemini/settings.json" 2>/dev/null; then
  _global_cache="$HOME/.gemini/plugins/cache"
  _global_found=1
  if [ -d "$_global_cache" ]; then
    for _sp_dir in "$_global_cache"/*/superpowers; do
      if [ -d "$_sp_dir" ]; then
        _global_found=0
        break
      fi
    done
  fi
  _global_expected="$_global_found"
else
  _global_expected=1
fi

bash "$PROJECT_ROOT/scripts/pm/lifecycle-helpers.sh" detect-superpowers >/dev/null 2>&1
assert "detect_superpowers CLI: matches global state" "$_global_expected" "$?"

bash "$PROJECT_ROOT/scripts/detect-superpowers.sh" >/dev/null 2>&1
assert "detect-superpowers.sh direct: matches global state" "$_global_expected" "$?"

mkdir -p .gemini-plugin
echo '{"name":"superpowers-plugin"}' > .gemini-plugin/plugin.json
bash "$PROJECT_ROOT/scripts/detect-superpowers.sh" >/dev/null 2>&1
assert "detect-superpowers.sh with mock: exit 0" "0" "$?"
rm -rf .gemini-plugin

# --- IT-2: lifecycle-helpers.sh ↔ lifecycle.json ---
echo ""
echo "── IT-2: lifecycle-helpers → lifecycle.json ──"

bash "$PROJECT_ROOT/scripts/pm/lifecycle-helpers.sh" read-config-bool design_gate enabled true >/dev/null 2>&1
assert "read_config_bool: design_gate.enabled = true" "0" "$?"

bash "$PROJECT_ROOT/scripts/pm/lifecycle-helpers.sh" read-config-bool semantic_review block_on_failure false >/dev/null 2>&1
assert "read_config_bool: semantic_review.block_on_failure = false" "1" "$?"

bash "$PROJECT_ROOT/scripts/pm/lifecycle-helpers.sh" read-config-bool superpowers auto_detect true >/dev/null 2>&1
assert "read_config_bool: superpowers.auto_detect = true" "0" "$?"

bash "$PROJECT_ROOT/scripts/pm/lifecycle-helpers.sh" read-config-bool test_first block_on_no_tests true >/dev/null 2>&1
assert "read_config_bool: test_first.block_on_no_tests = true" "0" "$?"

# --- IT-3: pre-tool-use.sh ↔ lifecycle-helpers.sh ---
echo ""
echo "── IT-3: pre-tool-use → lifecycle-helpers (config + state) ──"

cleanup
setup_state 999 "integ-test" "FEATURE"

# Write without design file → BLOCK
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/test.sh","content":"x"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert "pre-tool-use: BLOCK Write without design (FEATURE)" "2" "$exit_code"

# Write design file → ALLOW
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":".gemini/epics/integ-test/designs/task-999-design.md","content":"d"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert "pre-tool-use: ALLOW writing design file" "0" "$exit_code"

# Create design file, then Write → ALLOW
mkdir -p ".gemini/epics/integ-test/designs"
echo "# Design" > ".gemini/epics/integ-test/designs/task-999-design.md"
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/test.sh","content":"x"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert "pre-tool-use: ALLOW Write with design file exists" "0" "$exit_code"

# BUG_FIX type → ALLOW (no gate)
setup_state 999 "integ-test" "BUG_FIX"
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/test.sh","content":"x"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert "pre-tool-use: ALLOW Write for BUG_FIX" "0" "$exit_code"

# --- IT-4: pre-task.sh ↔ lifecycle-helpers.sh ---
echo ""
echo "── IT-4: pre-task → lifecycle-helpers (state reading) ──"

setup_state 999 "integ-test" "FEATURE"

output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
assert "pre-task: exits 0 always" "0" "$?"
echo "$output" | grep -q "DESIGN GATE" 2>/dev/null
assert "pre-task: shows DESIGN GATE for FEATURE" "0" "$?"

setup_state 999 "integ-test" "DOCS"
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
echo "$output" | grep -q "DESIGN GATE" 2>/dev/null
assert "pre-task: NO DESIGN GATE for DOCS" "1" "$?"

# --- IT-5: Config sections consistency ---
echo ""
echo "── IT-5: Shared config consistency ──"

config_file="$PROJECT_ROOT/config/lifecycle.json"
sections=$(jq 'keys[]' "$config_file" 2>/dev/null | wc -l | tr -d ' ')
assert "lifecycle.json has 7 sections" "7" "$sections"

for section in design_gate test_first semantic_review; do
  jq -e ".${section}.enabled" "$config_file" >/dev/null 2>&1
  assert "Section '$section' has 'enabled' field" "0" "$?"
done

jq -e '.superpowers.auto_detect' "$config_file" >/dev/null 2>&1
assert "Section 'superpowers' has 'auto_detect' field" "0" "$?"

# Existing sections untouched
for section in verification context cost_control; do
  jq -e ".$section" "$config_file" >/dev/null 2>&1
  assert "Existing section '$section' present" "0" "$?"
done

# --- IT-6: File path convention ---
echo ""
echo "── IT-6: Design file path convention ──"

grep -q 'designs/task-' "$PROJECT_ROOT/hooks/pre-tool-use.sh" 2>/dev/null
assert "pre-tool-use uses designs/task- pattern" "0" "$?"

grep -q 'designs/task-' "$PROJECT_ROOT/hooks/post-task.sh" 2>/dev/null
assert "post-task uses designs/task- pattern" "0" "$?"

grep -q 'designs/task-' "$PROJECT_ROOT/hooks/pre-task.sh" 2>/dev/null
assert "pre-task uses designs/task- pattern" "0" "$?"

# --- IT-7: Existing guards regression ---
echo ""
echo "── IT-7: Existing guards still work ──"

setup_state 999 "integ-test" "FEATURE"

# Issue close without verify → BLOCKED
output=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh issue close 999"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
assert "Guard 1: issue close without verify → BLOCK" "2" "$?"

# Read tool → ALLOW (non-Bash/Write/Edit)
output=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/x"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
assert "Non-Bash/Write/Edit tool → ALLOW" "0" "$?"

# --- Cleanup ---
cleanup

# --- Summary ---
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Integration Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════"

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}✅ ALL INTEGRATION TESTS PASSED${NC}"
  exit 0
else
  echo -e "${RED}❌ $FAIL INTEGRATION TEST(S) FAILED${NC}"
  exit 1
fi
