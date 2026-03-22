#!/usr/bin/env bash
# test-integration.sh — Cross-component integration tests for dx-hardening epic
#
# Usage: bash tests/integration/epic_dx-hardening/test-integration.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
TOTAL=0

# --- Helpers ---

run_test() {
  local name="$1"
  TOTAL=$((TOTAL + 1))
  echo ""
  echo "── Test $TOTAL: $name ──"
}

assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "  ✅ $label (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local output="$1" pattern="$2" label="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — pattern '$pattern' not found in output"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local file="$1" label="$2"
  if [ -f "$file" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — file missing: $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_json_key() {
  local file="$1" key="$2" expected="$3" label="$4"
  local actual
  actual=$(python3 -c "import json; d=json.load(open('$file')); v=d.get('$key'); print(v if v is not None else '')" 2>/dev/null)
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

# --- Cleanup ---

FEATURE="test-integration-$$"
STATE_FILE=".claude/context/build-state/${FEATURE}.json"

cleanup() {
  rm -f "$STATE_FILE" 2>/dev/null || true
}
trap cleanup EXIT

# --- Test 1: Cross-component state flow (T181 init → T182 build reads state) ---

run_test "build-state.sh init → state file created with valid structure"
source scripts/pm/build-state.sh
init_state "$FEATURE" >/dev/null 2>&1
init_exit=$?
assert_exit 0 "$init_exit" "init_state exits 0"
assert_file_exists "$STATE_FILE" "state file exists after init"

if [ -f "$STATE_FILE" ]; then
  step_count=$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(len(s['steps']))")
  assert_contains "$step_count" "10" "10 steps created"

  run_test "advance_step → state advances, budget script can read updated state"
  advance_step "$FEATURE" >/dev/null 2>&1
  assert_exit 0 $? "advance_step exits 0"
  current=$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(s['current_step'])")
  assert_contains "$current" "1" "current_step advanced to 1"
  step0_status=$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(s['steps'][0]['status'])")
  assert_contains "$step0_status" "complete" "step 0 marked complete"
fi

# --- Test 2: budget.sh reads config/build.json (T181 config → T186 budget) ---

run_test "budget.sh reads config/build.json and outputs table"
assert_file_exists "config/build.json" "config/build.json exists"
assert_file_exists "scripts/pm/budget.sh" "scripts/pm/budget.sh exists"

output=$(bash scripts/pm/budget.sh "test-feature" 2>&1)
budget_exit=$?
assert_exit 0 "$budget_exit" "budget.sh exits 0"
assert_contains "$output" "test-feature\|TOTAL\|Total\|token\|Token\|Step\|step" "budget output has expected content"

# --- Test 3: model-tiers.json contains all new commands (T189) ---

run_test "model-tiers.json contains all new command entries"
assert_file_exists "config/model-tiers.json" "model-tiers.json exists"

build_tier=$(python3 -c "import json; d=json.load(open('config/model-tiers.json')); print(d['commands'].get('build','MISSING'))")
budget_tier=$(python3 -c "import json; d=json.load(open('config/model-tiers.json')); print(d['commands'].get('budget','MISSING'))")
onboard_tier=$(python3 -c "import json; d=json.load(open('config/model-tiers.json')); print(d['commands'].get('onboard','MISSING'))")
upstream_tier=$(python3 -c "import json; d=json.load(open('config/model-tiers.json')); print(d['commands'].get('upstream-sync','MISSING'))")
next_tier=$(python3 -c "import json; d=json.load(open('config/model-tiers.json')); print(d['commands'].get('next','MISSING'))")

assert_contains "$build_tier" "heavy" "build tier is heavy"
assert_contains "$budget_tier" "light" "budget tier is light"
assert_contains "$onboard_tier" "medium" "onboard tier is medium"
assert_contains "$upstream_tier" "medium" "upstream-sync tier is medium"
assert_contains "$next_tier" "medium" "next tier is medium"

# --- Test 4: All new command files have valid frontmatter ---

run_test "All new commands have required frontmatter fields (name, description, allowed-tools, model)"
for cmd in build budget next onboard upstream-sync; do
  file="commands/pm/${cmd}.md"
  if [ ! -f "$file" ]; then
    echo "  ❌ $file missing"
    FAIL=$((FAIL + 1))
    continue
  fi

  # Check name field
  if head -10 "$file" | grep -q "^name:"; then
    echo "  ✅ $cmd has name:"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $cmd missing name: field"
    FAIL=$((FAIL + 1))
  fi

  # Check description field
  if head -10 "$file" | grep -q "^description:"; then
    echo "  ✅ $cmd has description:"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $cmd missing description: field"
    FAIL=$((FAIL + 1))
  fi

  # Check model field (set by apply-model-tiers.sh)
  if head -10 "$file" | grep -q "^model:"; then
    echo "  ✅ $cmd has model:"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $cmd missing model: field"
    FAIL=$((FAIL + 1))
  fi
done

# --- Test 5: next.sh --smart exits cleanly (T184) ---

run_test "scripts/pm/next.sh --smart exits 0 without crashing"
assert_file_exists "scripts/pm/next.sh" "next.sh exists"
output=$(bash scripts/pm/next.sh --smart 2>&1)
next_exit=$?
assert_exit 0 "$next_exit" "next.sh --smart exits 0"
# Should produce some output
if [ -n "$output" ]; then
  echo "  ✅ next.sh --smart produces output"
  PASS=$((PASS + 1))
else
  echo "  ❌ next.sh --smart produced no output"
  FAIL=$((FAIL + 1))
fi

# --- Test 6: upstream-sync.sh exists and is executable (T188) ---

run_test "scripts/pm/upstream-sync.sh exists and has valid syntax"
assert_file_exists "scripts/pm/upstream-sync.sh" "upstream-sync.sh exists"
bash -n scripts/pm/upstream-sync.sh 2>/dev/null
assert_exit 0 $? "upstream-sync.sh has valid bash syntax"

# --- Test 7: budget.sh has valid bash syntax (T186) ---

run_test "scripts/pm/budget.sh has valid bash syntax"
bash -n scripts/pm/budget.sh
assert_exit 0 $? "budget.sh has valid bash syntax"

# --- Test 8: build-state.sh has valid bash syntax (T181) ---

run_test "scripts/pm/build-state.sh has valid bash syntax"
bash -n scripts/pm/build-state.sh
assert_exit 0 $? "build-state.sh has valid bash syntax"

# --- Summary ---

echo ""
echo "══════════════════════════════════════"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "══════════════════════════════════════"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
