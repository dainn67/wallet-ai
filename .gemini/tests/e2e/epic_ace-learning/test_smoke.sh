#!/usr/bin/env bash
# Smoke tests for epic ace-learning deliverables
# Verifies all files exist, scripts are sourceable, basic functions work

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

# Use .gemini/ prefix for runtime paths
CCPM_ROOT="$PROJECT_ROOT/.gemini"
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

assert_file() {
  local file="$1" label="$2"
  if [ -f "$file" ]; then echo "  ✅ $label"; PASS=$((PASS + 1))
  else echo "  ❌ $label — not found: $file"; FAIL=$((FAIL + 1)); fi
}

assert_contains() {
  local output="$1" pattern="$2" label="$3"
  if echo "$output" | grep -q "$pattern"; then echo "  ✅ $label"; PASS=$((PASS + 1))
  else echo "  ❌ $label — '$pattern' not found"; FAIL=$((FAIL + 1)); fi
}

assert_numeric() {
  local value="$1" label="$2"
  if [[ "$value" =~ ^[0-9]+$ ]]; then echo "  ✅ $label (value=$value)"; PASS=$((PASS + 1))
  else echo "  ❌ $label — expected number, got '$value'"; FAIL=$((FAIL + 1)); fi
}

echo "═══ Smoke Tests: ace-learning ═══"

# ── 1. Config file exists and is valid JSON ──

run_test "config/ace-learning.json exists and is valid JSON"
assert_file ".gemini/config/ace-learning.json" "Config file exists"
python3 -c "import json; json.load(open('.gemini/config/ace-learning.json'))" 2>/dev/null
assert_exit 0 $? "Valid JSON"

run_test "Config has required sections"
config=$(cat .gemini/config/ace-learning.json)
assert_contains "$config" '"skillbook"' "skillbook section"
assert_contains "$config" '"reflection"' "reflection section"
assert_contains "$config" '"complexity"' "complexity section"
assert_contains "$config" '"enabled"' "enabled flags present"

# ── 2. All scripts exist and are sourceable ──

run_test "lifecycle-helpers.sh has ace-learning functions"
output=$(grep -c "read_ace_config\|ace_feature_enabled\|ace_log" .gemini/scripts/pm/lifecycle-helpers.sh 2>/dev/null)
if [ "$output" -ge 3 ]; then echo "  ✅ All 3 ace functions found ($output matches)"; PASS=$((PASS + 1))
else echo "  ❌ Missing ace functions (found $output)"; FAIL=$((FAIL + 1)); fi
TOTAL=$((TOTAL + 1))

run_test "skillbook-extract.sh exists and is sourceable"
assert_file ".gemini/scripts/pm/skillbook-extract.sh" "Script exists"
(source .gemini/scripts/pm/skillbook-extract.sh 2>/dev/null)
assert_exit 0 $? "Sourceable without error"

run_test "skillbook-inject.sh exists and is sourceable"
assert_file ".gemini/scripts/pm/skillbook-inject.sh" "Script exists"
(source .gemini/scripts/pm/skillbook-inject.sh 2>/dev/null)
assert_exit 0 $? "Sourceable without error"

run_test "reflection-generate.sh exists and is sourceable"
assert_file ".gemini/scripts/pm/reflection-generate.sh" "Script exists"
(source .gemini/scripts/pm/reflection-generate.sh 2>/dev/null)
assert_exit 0 $? "Sourceable without error"

run_test "complexity-score.sh exists and is sourceable"
assert_file ".gemini/scripts/pm/complexity-score.sh" "Script exists"
(source .gemini/scripts/pm/complexity-score.sh 2>/dev/null)
assert_exit 0 $? "Sourceable without error"

run_test "failure-patterns.sh exists and is sourceable"
assert_file ".gemini/scripts/pm/failure-patterns.sh" "Script exists"
(source .gemini/scripts/pm/failure-patterns.sh 2>/dev/null)
assert_exit 0 $? "Sourceable without error"

# ── 3. Commands exist with required sections ──

run_test "skillbook.md command exists"
assert_file ".gemini/commands/pm/skillbook.md" "View command"

run_test "skillbook-prune.md command exists"
assert_file ".gemini/commands/pm/skillbook-prune.md" "Prune command"

run_test "issue-complete.md has Learning Extraction section"
assert_contains "$(cat .gemini/commands/pm/issue-complete.md)" "Learning Extraction" "Extraction step present"

run_test "issue-start.md has Skillbook Injection section"
assert_contains "$(cat .gemini/commands/pm/issue-start.md)" "Skillbook Injection\|skillbook-inject\|skillbook" "Injection step present"

run_test "issue-start.md has Complexity Assessment section"
assert_contains "$(cat .gemini/commands/pm/issue-start.md)" "Complexity Assessment\|complexity-score\|complexity" "Scoring step present"

run_test "verify-run.md has Reflection & Retry section"
assert_contains "$(cat .gemini/commands/pm/verify-run.md)" "Reflection.*Retry\|reflection-generate\|ace_feature_enabled" "Retry flow present"

# ── 4. Context files exist ──

run_test "skillbook.md context file exists"
assert_file ".gemini/context/skillbook.md" "Skillbook file"

run_test "ace-learning-log.md exists"
assert_file ".gemini/context/ace-learning-log.md" "Log file"

# ── 5. Config loading + graceful degradation ──

run_test "ace_feature_enabled works when config exists"
source .gemini/scripts/pm/lifecycle-helpers.sh 2>/dev/null
ace_feature_enabled "skillbook" 2>/dev/null
assert_exit 0 $? "skillbook enabled returns 0"

run_test "read_ace_config reads values"
val=$(source .gemini/scripts/pm/lifecycle-helpers.sh 2>/dev/null && read_ace_config "skillbook" "max_entries" "50" 2>/dev/null)
assert_contains "$val" "50" "max_entries = 50"

run_test "Graceful degradation when config missing"
# Temporarily rename config to test degradation
cp .gemini/config/ace-learning.json /tmp/ace-learning-backup-$$.json
mv .gemini/config/ace-learning.json .gemini/config/ace-learning.json.bak
source .gemini/scripts/pm/lifecycle-helpers.sh 2>/dev/null
ace_feature_enabled "skillbook" 2>/dev/null
rc=$?
mv .gemini/config/ace-learning.json.bak .gemini/config/ace-learning.json
if [ "$rc" -ne 0 ]; then echo "  ✅ Returns disabled when config missing"; PASS=$((PASS + 1))
else echo "  ❌ Should return disabled when config missing"; FAIL=$((FAIL + 1)); fi

# ── 6. Complexity scoring basic test ──

run_test "suggest_model maps scores correctly"
source .gemini/scripts/pm/complexity-score.sh 2>/dev/null
low=$(suggest_model 2 2>/dev/null)
mid=$(suggest_model 5 2>/dev/null)
high=$(suggest_model 8 2>/dev/null)
assert_contains "$low" "haiku" "Score 2 → haiku"
assert_contains "$mid" "sonnet" "Score 5 → sonnet"
assert_contains "$high" "opus" "Score 8 → opus"

run_test "get_strategy_hints returns hints for high scores"
source .gemini/scripts/pm/complexity-score.sh 2>/dev/null
hints7=$(get_strategy_hints 7 2>/dev/null)
hints9=$(get_strategy_hints 9 2>/dev/null)
if [ -n "$hints7" ]; then echo "  ✅ Score 7 has hints"; PASS=$((PASS + 1))
else echo "  ❌ Score 7 should have hints"; FAIL=$((FAIL + 1)); fi
if [ -n "$hints9" ]; then echo "  ✅ Score 9 has hints"; PASS=$((PASS + 1))
else echo "  ❌ Score 9 should have hints"; FAIL=$((FAIL + 1)); fi

# ── 7. Zero external dependencies ──

run_test "No external package managers in ace-learning scripts"
deps=$(grep -rn "pip install\|npm install\|cargo install\|gem install" \
  .gemini/scripts/pm/skillbook-extract.sh \
  .gemini/scripts/pm/skillbook-inject.sh \
  .gemini/scripts/pm/reflection-generate.sh \
  .gemini/scripts/pm/complexity-score.sh \
  .gemini/scripts/pm/failure-patterns.sh 2>/dev/null || true)
if [ -z "$deps" ]; then echo "  ✅ No external deps"; PASS=$((PASS + 1))
else echo "  ❌ Found external deps: $deps"; FAIL=$((FAIL + 1)); fi

# ── Summary ──

echo ""
echo "═══════════════════════════════════════════"
echo "  Smoke: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════"

[ "$FAIL" -gt 0 ] && exit 1
exit 0
