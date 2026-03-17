#!/usr/bin/env bash
# E2E Tests for Superpowers Integration (Issue #37)
# Tests all 3 enhancement layers: design gate, test-before-done, semantic review

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CCPM_ROOT="$PROJECT_ROOT"

PASS=0
FAIL=0
TOTAL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" -eq "$actual" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc (exit=$actual)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc (expected=$expected, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" output="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$output" | grep -q "$pattern"; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc — pattern not found: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" output="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if ! echo "$output" | grep -q "$pattern"; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc — pattern should NOT be present: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

# --- Setup / Teardown ---

setup_state() {
  local task_type="$1" verify_mode="${2:-STRICT}" epic="${3:-test-epic}" issue="${4:-99}"
  mkdir -p "$CCPM_ROOT/context/verify"
  cat > "$CCPM_ROOT/context/verify/state.json" <<STATEOF
{
  "active_task": {
    "issue_number": $issue,
    "epic": "$epic",
    "type": "$task_type",
    "verify_mode": "$verify_mode",
    "tech_stack": "generic",
    "verify_profile": "",
    "max_iterations": 20,
    "current_iteration": 0,
    "started_at": "2026-01-01T00:00:00Z",
    "iterations": []
  }
}
STATEOF
}

cleanup() {
  rm -f "$CCPM_ROOT/context/verify/state.json"
  rm -rf ".claude/epics/test-epic/designs"
  rm -rf "$CCPM_ROOT/epics/test-epic/designs"
  rm -rf .claude-plugin
  rm -f "$CCPM_ROOT/context/handoffs/latest.md"
  rm -f "$CCPM_ROOT/context/verify/BLOCKED.md"
  rm -rf "$CCPM_ROOT/context/verify/results"
}

# ========================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  E2E Tests: Superpowers Integration"
echo "═══════════════════════════════════════════════════════"
echo ""

# ========================================
echo "── Scenario 1: FEATURE Task — Happy Path ──"
echo ""

cleanup
setup_state "FEATURE" "STRICT" "test-epic" "99"

# 1.1: PreTask shows design gate
echo "  [1.1] PreTask: design gate protocol for FEATURE"
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreTask exits 0" 0 "$exit_code"
assert_contains "PreTask shows DESIGN GATE PROTOCOL" "$output" "DESIGN GATE PROTOCOL"
assert_contains "PreTask shows design file path" "$output" "designs/task-99-design.md"
assert_contains "PreTask shows CONTEXT LOADING" "$output" "CONTEXT LOADING PROTOCOL"

# 1.2: PreToolUse blocks Write without design file
echo ""
echo "  [1.2] PreToolUse: BLOCK Write without design file"
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/some/code.sh","content":"hello"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreToolUse blocks Write (exit 2)" 2 "$exit_code"
assert_contains "PreToolUse shows BLOCKED message" "$output" "BLOCKED"

# 1.3: PreToolUse allows writing design file
echo ""
echo "  [1.3] PreToolUse: ALLOW writing design file"
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":".claude/epics/test-epic/designs/task-99-design.md","content":"design"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreToolUse allows design file write (exit 0)" 0 "$exit_code"

# 1.4: PreToolUse allows after design file created
echo ""
echo "  [1.4] PreToolUse: ALLOW Write after design file exists"
# PreToolUse checks ".claude/epics/..." (relative), PostTask checks "$CCPM_ROOT/epics/..."
# At runtime both resolve to .claude/epics/, but in test CCPM_ROOT=project root
mkdir -p ".claude/epics/test-epic/designs"
mkdir -p "$CCPM_ROOT/epics/test-epic/designs"
echo "# Design" > ".claude/epics/test-epic/designs/task-99-design.md"
echo "# Design" > "$CCPM_ROOT/epics/test-epic/designs/task-99-design.md"
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/some/code.sh","content":"hello"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreToolUse allows Write with design file (exit 0)" 0 "$exit_code"

# 1.5: PostTask warns about missing Design vs Implementation
echo ""
echo "  [1.5] PostTask: warn missing 'Design vs Implementation'"
mkdir -p "$CCPM_ROOT/context/handoffs"
cat > "$CCPM_ROOT/context/handoffs/latest.md" <<'HANDOFF'
# Handoff

## Completed
- Did stuff

## Decisions Made
- Decision A

## State of Tests
- All pass

## Files Changed
- file.sh
HANDOFF
touch "$CCPM_ROOT/context/handoffs/latest.md"  # ensure fresh
output=$(bash "$PROJECT_ROOT/hooks/post-task.sh" "$CCPM_ROOT" 2>&1)
assert_contains "PostTask warns missing Design vs Implementation" "$output" "Design vs Implementation"

# 1.6: PostTask no warning when section present
echo ""
echo "  [1.6] PostTask: no warning when section present"
cat >> "$CCPM_ROOT/context/handoffs/latest.md" <<'SECTION'

## Design vs Implementation
- Implemented as designed
SECTION
touch "$CCPM_ROOT/context/handoffs/latest.md"
output=$(bash "$PROJECT_ROOT/hooks/post-task.sh" "$CCPM_ROOT" 2>&1)
assert_not_contains "PostTask no warning when section present" "$output" "missing (design file exists"

# ========================================
echo ""
echo "── Scenario 2: BUG_FIX Task — No Gates ──"
echo ""

cleanup
setup_state "BUG_FIX" "STRICT" "test-epic" "88"

# 2.1: PreTask no design gate
echo "  [2.1] PreTask: NO design gate for BUG_FIX"
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreTask exits 0" 0 "$exit_code"
assert_not_contains "PreTask skips DESIGN GATE for BUG_FIX" "$output" "DESIGN GATE PROTOCOL"
assert_contains "PreTask still shows CONTEXT LOADING" "$output" "CONTEXT LOADING PROTOCOL"

# 2.2: PreToolUse allows Write without design file
echo ""
echo "  [2.2] PreToolUse: ALLOW Write for BUG_FIX (no design gate)"
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/some/code.sh","content":"fix"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreToolUse allows Write for BUG_FIX (exit 0)" 0 "$exit_code"

# ========================================
echo ""
echo "── Scenario 3: Config Disabled ──"
echo ""

cleanup
setup_state "FEATURE" "STRICT" "test-epic" "77"

# Backup and disable all gates
cp "$PROJECT_ROOT/config/lifecycle.json" "$PROJECT_ROOT/config/lifecycle.json.bak"
if command -v jq &>/dev/null; then
  jq '.design_gate.enabled = false | .test_first.enabled = false | .semantic_review.enabled = false' \
    "$PROJECT_ROOT/config/lifecycle.json.bak" > "$PROJECT_ROOT/config/lifecycle.json"
fi

# 3.1: PreTask skips design gate when disabled
echo "  [3.1] PreTask: skip design gate when disabled"
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
assert_not_contains "PreTask skips design gate when disabled" "$output" "DESIGN GATE PROTOCOL"

# 3.2: PreToolUse allows Write when design gate disabled
echo ""
echo "  [3.2] PreToolUse: ALLOW Write when design gate disabled"
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/some/code.sh","content":"hello"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreToolUse allows Write when design gate disabled (exit 0)" 0 "$exit_code"

# Restore config
mv "$PROJECT_ROOT/config/lifecycle.json.bak" "$PROJECT_ROOT/config/lifecycle.json"

# ========================================
echo ""
echo "── Scenario 4: Superpowers Detection ──"
echo ""

cleanup
setup_state "FEATURE" "STRICT" "test-epic" "66"

# 4.1: Without Superpowers — native messages
echo "  [4.1] PreTask: native template without Superpowers"
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
assert_contains "PreTask shows native template" "$output" "alternative approaches"
assert_not_contains "PreTask no brainstorming skill" "$output" "brainstorming"

# 4.2: With mock Superpowers — skill messages
echo ""
echo "  [4.2] PreTask: brainstorming skill with Superpowers"
mkdir -p .claude-plugin
echo '{"name": "superpowers-plugin", "version": "4.1.1"}' > .claude-plugin/plugin.json
output=$(bash "$PROJECT_ROOT/hooks/pre-task.sh" "$CCPM_ROOT" 2>&1)
assert_contains "PreTask shows brainstorming skill" "$output" "brainstorming"

# 4.3: Detection script exit codes
echo ""
echo "  [4.3] Detection script: exit codes"
det_output=$(bash "$PROJECT_ROOT/scripts/detect-superpowers.sh" 2>&1)
det_exit=$?
assert_exit "Detect with mock plugin (exit 0)" 0 "$det_exit"
assert_contains "Detect stdout: installed" "$det_output" "superpowers:installed"

rm -rf .claude-plugin
det_output=$(bash "$PROJECT_ROOT/scripts/detect-superpowers.sh" 2>&1)
det_exit=$?
assert_exit "Detect without plugin (exit 1)" 1 "$det_exit"
assert_contains "Detect stdout: not-installed" "$det_output" "superpowers:not-installed"

# ========================================
echo ""
echo "── Scenario 5: Regression Tests ──"
echo ""

cleanup
setup_state "FEATURE" "STRICT" "test-epic" "55"

# 5.1: Existing guard — close issue without verify
echo "  [5.1] PreToolUse: block issue close without verification"
output=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh issue close 55"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreToolUse blocks issue close without verify (exit 2)" 2 "$exit_code"
assert_contains "Shows verification required message" "$output" "Cannot close issue without passing verification"

# 5.2: Non-Bash/Write/Edit tool — still allowed
echo ""
echo "  [5.2] PreToolUse: allow non-Bash/Write/Edit tools"
output=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/some/file"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreToolUse allows Read tool (exit 0)" 0 "$exit_code"

# 5.3: No active task — fast path
echo ""
echo "  [5.3] PreToolUse: fast path with no active task"
rm -f "$CCPM_ROOT/context/verify/state.json"
output=$(echo '{"tool_name":"Write","tool_input":{"file_path":"/some/code.sh","content":"x"}}' | bash "$PROJECT_ROOT/hooks/pre-tool-use.sh" "$CCPM_ROOT" 2>&1)
exit_code=$?
assert_exit "PreToolUse allows all when no state (exit 0)" 0 "$exit_code"

# 5.4: lifecycle.json valid JSON
echo ""
echo "  [5.4] Config: lifecycle.json valid and complete"
TOTAL=$((TOTAL + 1))
if jq '.' "$PROJECT_ROOT/config/lifecycle.json" >/dev/null 2>&1; then
  echo -e "  ${GREEN}✅ PASS${NC}: lifecycle.json valid JSON"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC}: lifecycle.json invalid JSON"
  FAIL=$((FAIL + 1))
fi

# 5.5: All required config sections exist
echo ""
echo "  [5.5] Config: all sections present"
for section in verification context cost_control design_gate test_first semantic_review superpowers; do
  TOTAL=$((TOTAL + 1))
  if jq -e ".$section" "$PROJECT_ROOT/config/lifecycle.json" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ PASS${NC}: section '$section' exists"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: section '$section' missing"
    FAIL=$((FAIL + 1))
  fi
done

# 5.6: Prompt file exists with {N} variable
echo ""
echo "  [5.6] Prompt file: exists with template variable"
TOTAL=$((TOTAL + 1))
if [ -f "$PROJECT_ROOT/prompts/task-semantic-review.md" ] && grep -q '{N}' "$PROJECT_ROOT/prompts/task-semantic-review.md"; then
  echo -e "  ${GREEN}✅ PASS${NC}: prompt file exists with {N} variable"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC}: prompt file missing or no {N} variable"
  FAIL=$((FAIL + 1))
fi

# 5.7: Handoff template has Design vs Implementation
echo ""
echo "  [5.7] Template: 'Design vs Implementation' section"
TOTAL=$((TOTAL + 1))
if grep -q "^## Design vs Implementation" "$PROJECT_ROOT/context/handoffs/TEMPLATE.md"; then
  echo -e "  ${GREEN}✅ PASS${NC}: TEMPLATE.md has Design vs Implementation"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC}: TEMPLATE.md missing Design vs Implementation"
  FAIL=$((FAIL + 1))
fi

# 5.8: Performance check
echo ""
echo "  [5.8] Performance: detection script <200ms"
TOTAL=$((TOTAL + 1))
start_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null)
bash "$PROJECT_ROOT/scripts/detect-superpowers.sh" >/dev/null 2>&1 || true
end_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null)
elapsed=$((end_ms - start_ms))
if [ "$elapsed" -lt 200 ]; then
  echo -e "  ${GREEN}✅ PASS${NC}: detection script: ${elapsed}ms (<200ms)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}❌ FAIL${NC}: detection script: ${elapsed}ms (>200ms)"
  FAIL=$((FAIL + 1))
fi

# 5.9: lifecycle-helpers CLI commands
echo ""
echo "  [5.9] lifecycle-helpers: new CLI commands work"
bash "$PROJECT_ROOT/scripts/pm/lifecycle-helpers.sh" detect-superpowers >/dev/null 2>&1
det_exit=$?
assert_exit "detect-superpowers command works (exit 1 = not installed)" 1 "$det_exit"

bash "$PROJECT_ROOT/scripts/pm/lifecycle-helpers.sh" read-config-bool design_gate enabled true >/dev/null 2>&1
cfg_exit=$?
assert_exit "read-config-bool returns 0 for true" 0 "$cfg_exit"

# ========================================
# Cleanup
cleanup

# ========================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
  exit 0
else
  echo -e "${RED}❌ $FAIL TEST(S) FAILED${NC}"
  exit 1
fi
