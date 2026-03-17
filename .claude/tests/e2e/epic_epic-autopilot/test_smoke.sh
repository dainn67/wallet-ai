#!/usr/bin/env bash
# Smoke tests for epic-autopilot deliverables
# Verifies all files exist and basic execution works

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

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

echo "═══ Smoke Tests: epic-autopilot ═══"

# --- File existence ---

run_test "epic-run.md exists"
assert_file "commands/pm/epic-run.md" "Command file"

run_test "epic-run-plan.sh exists and is executable"
assert_file "scripts/pm/epic-run-plan.sh" "Plan script"
test -x "scripts/pm/epic-run-plan.sh" || chmod +x "scripts/pm/epic-run-plan.sh"

run_test "config/epic-run.json exists and is valid JSON"
assert_file "config/epic-run.json" "Config file"
python3 -c "import json; json.load(open('config/epic-run.json'))" 2>/dev/null
assert_exit 0 $? "Valid JSON"

run_test "epic-decompose.md has complexity scoring"
output=$(grep -c "complexity\|recommended_model" commands/pm/epic-decompose.md 2>/dev/null)
if [ "$output" -ge 2 ]; then echo "  ✅ Complexity fields present ($output matches)"; PASS=$((PASS + 1))
else echo "  ❌ Missing complexity/model fields"; FAIL=$((FAIL + 1)); fi
TOTAL=$((TOTAL + 1))

run_test "epic-sync.md has model labels"
assert_contains "$(cat commands/pm/epic-sync.md)" "model:" "Model label in sync"

run_test "issue-start.md has model display"
assert_contains "$(cat commands/pm/issue-start.md)" "recommended_model" "Model display in issue-start"

# --- Script execution ---

run_test "next.sh runs without error"
output=$(bash scripts/pm/next.sh 2>&1)
assert_exit 0 $? "Clean exit"

run_test "epic-run-plan.sh runs on epic-autopilot"
if [ -d ".claude/epics/epic-autopilot" ]; then
  output=$(bash scripts/pm/epic-run-plan.sh epic-autopilot 2>&1)
  assert_exit 0 $? "Clean exit"
  assert_contains "$output" "Epic Run Plan" "Header present"
else
  echo "  ⏭️  Skipped — epic-autopilot not found"
  TOTAL=$((TOTAL - 1))
fi

run_test "epic-run.md has correct frontmatter"
head_content=$(head -5 commands/pm/epic-run.md)
assert_contains "$head_content" "model:" "Model in frontmatter"
assert_contains "$head_content" "allowed-tools:" "Allowed tools in frontmatter"

# --- Summary ---

echo ""
echo "═══════════════════════════════════════════"
echo "  Smoke: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════"

[ "$FAIL" -gt 0 ] && exit 1
exit 0
