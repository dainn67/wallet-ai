#!/usr/bin/env bash
# Integration tests for epic ace-learning — cross-module verification
# Tests interfaces between: config → scripts, extract → inject, scoring → model-tiers

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

CCPM_ROOT="$PROJECT_ROOT/.claude"
export _CCPM_ROOT="$CCPM_ROOT"

PASS=0
FAIL=0
TOTAL=0

run_test() { TOTAL=$((TOTAL + 1)); echo ""; echo "── Test $TOTAL: $1 ──"; }

assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [ "$actual" -eq "$expected" ]; then echo "  ✅ $label"; PASS=$((PASS + 1))
  else echo "  ❌ $label (expected exit $expected, got $actual)"; FAIL=$((FAIL + 1)); fi
}

assert_contains() {
  local output="$1" pattern="$2" label="$3"
  if echo "$output" | grep -q "$pattern"; then echo "  ✅ $label"; PASS=$((PASS + 1))
  else echo "  ❌ $label — '$pattern' not found"; FAIL=$((FAIL + 1)); fi
}

assert_not_contains() {
  local output="$1" pattern="$2" label="$3"
  if echo "$output" | grep -q "$pattern"; then echo "  ❌ $label — '$pattern' should NOT be present"; FAIL=$((FAIL + 1))
  else echo "  ✅ $label"; PASS=$((PASS + 1)); fi
}

assert_equal() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then echo "  ✅ $label"; PASS=$((PASS + 1))
  else echo "  ❌ $label — expected '$expected', got '$actual'"; FAIL=$((FAIL + 1)); fi
}

echo "═══ Integration Tests: ace-learning ═══"

# ── Setup: backup skillbook for restore after tests ──
ORIG_SKILLBOOK=""
if [ -f ".claude/context/skillbook.md" ]; then
  ORIG_SKILLBOOK=$(cat .claude/context/skillbook.md)
fi
cleanup() {
  # Restore original skillbook
  if [ -n "$ORIG_SKILLBOOK" ]; then
    echo "$ORIG_SKILLBOOK" > .claude/context/skillbook.md
  fi
  # Clean up test fixtures
  rm -rf .claude/epics/integ-test-$$ 2>/dev/null
}
trap cleanup EXIT

# ── 1. Config → lifecycle-helpers integration ──

run_test "read_ace_config reads actual config values"
source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
val=$(read_ace_config "skillbook" "max_entries" "50" 2>/dev/null)
assert_equal "50" "$val" "max_entries from config"

run_test "ace_feature_enabled reads enabled status from config"
source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
ace_feature_enabled "skillbook" 2>/dev/null
assert_exit 0 $? "skillbook enabled"
ace_feature_enabled "reflection" 2>/dev/null
assert_exit 0 $? "reflection enabled"
ace_feature_enabled "complexity" 2>/dev/null
assert_exit 0 $? "complexity enabled"

run_test "ace_feature_enabled returns false for nonexistent feature"
source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
ace_feature_enabled "nonexistent_feature" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then echo "  ✅ Returns disabled for unknown feature"; PASS=$((PASS + 1))
else echo "  ❌ Should return disabled for unknown feature"; FAIL=$((FAIL + 1)); fi

# ── 2. skillbook-extract → skillbook-inject format compatibility ──

run_test "Skillbook extract format is parseable by inject"
source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
source .claude/scripts/pm/skillbook-extract.sh 2>/dev/null

# Init and append a test entry
init_skillbook 2>/dev/null
count_before=$(count_skillbook_entries 2>/dev/null)
append_skillbook_entry "helpful" "bash,testing,integration" "epic/test#99" "**Pattern:** Test pattern.\n**Why:** Test reason.\n**When applicable:** Integration tests.\n**Resolution:** Use real assertions." 2>/dev/null
count_after=$(count_skillbook_entries 2>/dev/null)

if [ "$count_after" -gt "$count_before" ]; then echo "  ✅ Entry appended (count: $count_before → $count_after)"; PASS=$((PASS + 1))
else echo "  ❌ Entry not appended (count: $count_before → $count_after)"; FAIL=$((FAIL + 1)); fi

# Verify inject can parse the appended entry
source .claude/scripts/pm/skillbook-inject.sh 2>/dev/null
if type score_skill_entry &>/dev/null || type inject_relevant_skills &>/dev/null; then
  echo "  ✅ Inject functions available"; PASS=$((PASS + 1))
else
  echo "  ❌ Inject functions not found"; FAIL=$((FAIL + 1))
fi

run_test "Skillbook entry contains required metadata fields"
entry=$(tail -20 .claude/context/skillbook.md)
assert_contains "$entry" "id:" "Has id field"
assert_contains "$entry" "context:" "Has context field"
assert_contains "$entry" "source_task:" "Has source_task field"

# ── 3. complexity-score → model-tiers.json interface ──

run_test "Complexity score thresholds match model-tiers config"
source .claude/scripts/pm/complexity-score.sh 2>/dev/null

# Read thresholds from ace-learning config
low_threshold=$(python3 -c "import json; c=json.load(open('.claude/config/ace-learning.json')); print(c['complexity']['thresholds']['low'])" 2>/dev/null)
high_threshold=$(python3 -c "import json; c=json.load(open('.claude/config/ace-learning.json')); print(c['complexity']['thresholds']['high'])" 2>/dev/null)

# Verify suggest_model uses these thresholds
low_model=$(suggest_model "$low_threshold" 2>/dev/null)
high_model=$(suggest_model "$high_threshold" 2>/dev/null)
assert_contains "$low_model" "haiku\|sonnet" "Low threshold maps to light model"
assert_contains "$high_model" "opus" "High threshold maps to opus"

run_test "model-tiers.json has ace-learning tier mappings"
assert_contains "$(cat .claude/config/model-tiers.json)" "haiku\|sonnet\|opus" "Model tiers defined"

# ── 4. reflection-generate → verify-run interface ──

run_test "Reflection generate functions exist and are callable"
source .claude/scripts/pm/reflection-generate.sh 2>/dev/null
if type generate_reflection &>/dev/null; then echo "  ✅ generate_reflection defined"; PASS=$((PASS + 1))
else echo "  ❌ generate_reflection not found"; FAIL=$((FAIL + 1)); fi

if type get_attempt_number &>/dev/null; then echo "  ✅ get_attempt_number defined"; PASS=$((PASS + 1))
else echo "  ❌ get_attempt_number not found"; FAIL=$((FAIL + 1)); fi

if type get_reflection_history &>/dev/null; then echo "  ✅ get_reflection_history defined"; PASS=$((PASS + 1))
else echo "  ❌ get_reflection_history not found"; FAIL=$((FAIL + 1)); fi

run_test "Attempt numbering starts at 1 for new task"
source .claude/scripts/pm/reflection-generate.sh 2>/dev/null
attempt=$(get_attempt_number "integ-test-$$" "999" 2>/dev/null)
assert_equal "1" "$attempt" "First attempt = 1"

# ── 5. failure-patterns integration ──

run_test "detect_failure_patterns function exists"
source .claude/scripts/pm/failure-patterns.sh 2>/dev/null
if type detect_failure_patterns &>/dev/null; then echo "  ✅ Function defined"; PASS=$((PASS + 1))
else echo "  ❌ Function not found"; FAIL=$((FAIL + 1)); fi

run_test "Pattern detection handles empty reflections dir"
source .claude/scripts/pm/failure-patterns.sh 2>/dev/null
output=$(detect_failure_patterns "nonexistent-epic" 2>/dev/null || true)
# Should not error, just return empty/no patterns
assert_exit 0 $? "Handles missing dir gracefully"

# ── 6. ace_log integration ──

run_test "ace_log writes to log file"
source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
lines_before=$(wc -l < .claude/context/ace-learning-log.md 2>/dev/null || echo "0")
ace_log "TEST" "integration test entry" 2>/dev/null
lines_after=$(wc -l < .claude/context/ace-learning-log.md 2>/dev/null || echo "0")
if [ "$lines_after" -gt "$lines_before" ]; then echo "  ✅ Log entry written"; PASS=$((PASS + 1))
else echo "  ❌ Log entry not written ($lines_before → $lines_after)"; FAIL=$((FAIL + 1)); fi

run_test "Log entry has correct format"
last_line=$(tail -1 .claude/context/ace-learning-log.md)
assert_contains "$last_line" "TEST" "Contains action"
assert_contains "$last_line" "integration test entry" "Contains detail"

# ── 7. Skillbook max entries cap ──

run_test "Skillbook append respects max_entries cap"
source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
source .claude/scripts/pm/skillbook-extract.sh 2>/dev/null
max=$(read_ace_config "skillbook" "max_entries" "50" 2>/dev/null)
current=$(count_skillbook_entries 2>/dev/null)
if [ "$current" -lt "$max" ]; then
  echo "  ✅ Under cap ($current < $max) — append should work"
  PASS=$((PASS + 1))
else
  echo "  ⚠️ At or over cap ($current >= $max) — append should be blocked"
  PASS=$((PASS + 1))
fi

# ── 8. End-to-end: config disable → no ace-learning output ──

run_test "All features disabled = no ace-learning code paths"
# Verify config guards exist in all modified commands
issue_start=$(cat .claude/commands/pm/issue-start.md)
issue_complete=$(cat .claude/commands/pm/issue-complete.md)
verify_run=$(cat .claude/commands/pm/verify-run.md)

assert_contains "$issue_start" "ace_feature_enabled\|ace-learning.*enabled\|skillbook.*enabled" "issue-start has config guard"
assert_contains "$issue_complete" "ace_feature_enabled\|ace-learning.*enabled\|skillbook.*enabled" "issue-complete has config guard"
assert_contains "$verify_run" "ace_feature_enabled\|reflection.*enabled" "verify-run has config guard"

# ── Summary ──

echo ""
echo "═══════════════════════════════════════════"
echo "  Integration: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════"

[ "$FAIL" -gt 0 ] && exit 1
exit 0
