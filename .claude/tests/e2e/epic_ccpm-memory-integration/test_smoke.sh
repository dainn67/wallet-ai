#!/usr/bin/env bash
# Phase B Smoke Tests for epic ccpm-memory-integration
#
# Verifies all deliverables exist, have correct structure, and basic execution works.
# Tests are independent of Memory Agent availability — handles both running/stopped.
#
# Usage:
#   bash tests/e2e/epic_ccpm-memory-integration/test_smoke.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
TOTAL=0

# --- Test Helpers ---

run_test() { TOTAL=$((TOTAL + 1)); echo ""; echo "-- Test $TOTAL: $1 --"; }

assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [ "$actual" -eq "$expected" ]; then echo "  PASS: $label"; PASS=$((PASS + 1))
  else echo "  FAIL: $label (expected exit $expected, got $actual)"; FAIL=$((FAIL + 1)); fi
}

assert_file() {
  local file="$1" label="$2"
  if [ -f "$file" ]; then echo "  PASS: $label"; PASS=$((PASS + 1))
  else echo "  FAIL: $label -- not found: $file"; FAIL=$((FAIL + 1)); fi
}

assert_executable() {
  local file="$1" label="$2"
  if [ -x "$file" ]; then echo "  PASS: $label"; PASS=$((PASS + 1))
  else echo "  FAIL: $label -- not executable: $file"; FAIL=$((FAIL + 1)); fi
}

assert_contains() {
  local output="$1" pattern="$2" label="$3"
  if echo "$output" | grep -q "$pattern"; then echo "  PASS: $label"; PASS=$((PASS + 1))
  else echo "  FAIL: $label -- '$pattern' not found"; FAIL=$((FAIL + 1)); fi
}

assert_equal() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS: $label"; PASS=$((PASS + 1))
  else echo "  FAIL: $label -- expected '$expected', got '$actual'"; FAIL=$((FAIL + 1)); fi
}

assert_not_empty() {
  local value="$1" label="$2"
  if [ -n "$value" ] && [ "$value" != "null" ]; then echo "  PASS: $label"; PASS=$((PASS + 1))
  else echo "  FAIL: $label -- value is empty or null"; FAIL=$((FAIL + 1)); fi
}

cleanup() {
  rm -f /tmp/ccpm-memory-health-* 2>/dev/null || true
  rm -f /tmp/ccpm-smoke-test-* 2>/dev/null || true
}

trap cleanup EXIT

echo ""
echo "========================================="
echo "  Smoke Tests: epic ccpm-memory-integration"
echo "========================================="

# ===========================================================
# Section 1: File Existence & Structure
# ===========================================================

echo ""
echo "--- Section 1: File Existence & Structure ---"

run_test "memory-health.sh exists and is executable"
assert_file "scripts/pm/memory-health.sh" "Health check script exists"
assert_executable "scripts/pm/memory-health.sh" "Health check script is executable"

run_test "memory-bootstrap.sh exists and is executable"
assert_file "scripts/pm/memory-bootstrap.sh" "Bootstrap script exists"
assert_executable "scripts/pm/memory-bootstrap.sh" "Bootstrap script is executable"

run_test "memory-query.md command exists with valid frontmatter"
assert_file "commands/pm/memory-query.md" "memory-query.md exists"
QUERY_FM=$(head -5 commands/pm/memory-query.md)
assert_contains "$QUERY_FM" "model:" "memory-query.md has model frontmatter"
assert_contains "$QUERY_FM" "allowed-tools:" "memory-query.md has allowed-tools frontmatter"

run_test "memory-status.md command exists with valid frontmatter"
assert_file "commands/pm/memory-status.md" "memory-status.md exists"
STATUS_FM=$(head -5 commands/pm/memory-status.md)
assert_contains "$STATUS_FM" "model:" "memory-status.md has model frontmatter"
assert_contains "$STATUS_FM" "allowed-tools:" "memory-status.md has allowed-tools frontmatter"

run_test "lifecycle-helpers.sh has memory_query function"
assert_file "scripts/pm/lifecycle-helpers.sh" "lifecycle-helpers.sh exists"
assert_contains "$(cat scripts/pm/lifecycle-helpers.sh)" "memory_query()" "memory_query function defined"

# ===========================================================
# Section 2: Config Section Completeness
# ===========================================================

echo ""
echo "--- Section 2: Config Section Completeness ---"

run_test "config/lifecycle.json has memory_agent section with all 8 keys"
CONFIG_SECTION=$(jq '.memory_agent' config/lifecycle.json 2>/dev/null || echo "null")
assert_not_empty "$CONFIG_SECTION" "memory_agent section exists"

KEY_COUNT=$(jq '.memory_agent | keys | length' config/lifecycle.json 2>/dev/null || echo "0")
assert_equal "8" "$KEY_COUNT" "memory_agent has exactly 8 keys"

for KEY in enabled host port query_on_prime query_on_pretask query_on_prd query_on_verify auto_ingest; do
  VAL=$(jq -r ".memory_agent.${KEY}" config/lifecycle.json 2>/dev/null || echo "MISSING")
  if [ "$VAL" = "MISSING" ] || [ "$VAL" = "null" ]; then
    echo "  FAIL: Key missing: $KEY"; FAIL=$((FAIL + 1))
  else
    echo "  PASS: Key present: $KEY = $VAL"; PASS=$((PASS + 1))
  fi
  TOTAL=$((TOTAL + 1))
done

run_test "All boolean toggles default to false (safe deployment)"
for TOGGLE in enabled query_on_prime query_on_pretask query_on_prd query_on_verify auto_ingest; do
  VAL=$(jq -r ".memory_agent.${TOGGLE}" config/lifecycle.json 2>/dev/null || echo "")
  assert_equal "false" "$VAL" "memory_agent.$TOGGLE defaults to false"
done

run_test "Host defaults to localhost and port to 8888"
HOST_VAL=$(jq -r '.memory_agent.host' config/lifecycle.json 2>/dev/null || echo "")
PORT_VAL=$(jq -r '.memory_agent.port' config/lifecycle.json 2>/dev/null || echo "")
assert_equal "localhost" "$HOST_VAL" "Host default is localhost"
assert_equal "8888" "$PORT_VAL" "Port default is 8888"

# ===========================================================
# Section 3: Function & Script Availability
# ===========================================================

echo ""
echo "--- Section 3: Function & Script Availability ---"

run_test "source lifecycle-helpers.sh && type memory_query"
FUNC_CHECK=$(bash -c "source scripts/pm/lifecycle-helpers.sh 2>/dev/null; type memory_query 2>&1")
FUNC_EXIT=$?
assert_exit 0 $FUNC_EXIT "memory_query function loadable"
assert_contains "$FUNC_CHECK" "function" "memory_query is a function"

run_test "memory_query listed in CLI commands of lifecycle-helpers.sh"
CLI_OUTPUT=$(bash scripts/pm/lifecycle-helpers.sh 2>&1 || true)
assert_contains "$CLI_OUTPUT" "memory-query" "memory-query in CLI help"

run_test "read_config_bool works for memory_agent toggles"
source scripts/pm/lifecycle-helpers.sh 2>/dev/null || true
read_config_bool "memory_agent" "enabled" 2>/dev/null
BOOL_EXIT=$?
assert_exit 1 $BOOL_EXIT "read_config_bool memory_agent.enabled returns 1 (false)"

# ===========================================================
# Section 4: Health Check Behavior
# ===========================================================

echo ""
echo "--- Section 4: Health Check Behavior ---"

run_test "memory-health.sh returns valid exit code (0 or 1)"
rm -f /tmp/ccpm-memory-health-* 2>/dev/null || true
HEALTH_OUTPUT=$(bash scripts/pm/memory-health.sh 2>&1 || true)
HEALTH_EXIT=$?
if [ "$HEALTH_EXIT" -eq 0 ] || [ "$HEALTH_EXIT" -eq 1 ]; then
  echo "  PASS: Exit code is valid: $HEALTH_EXIT"; PASS=$((PASS + 1))
else
  echo "  FAIL: Unexpected exit code: $HEALTH_EXIT"; FAIL=$((FAIL + 1))
fi

run_test "memory-health.sh output matches exit code"
if [ "$HEALTH_EXIT" -eq 0 ]; then
  assert_contains "$HEALTH_OUTPUT" "status" "Output contains 'status' when running"
else
  assert_equal "memory-agent-unavailable" "$HEALTH_OUTPUT" "Output is 'memory-agent-unavailable' when stopped"
fi

run_test "Health check creates cache file"
CACHE_COUNT=$(ls /tmp/ccpm-memory-health-* 2>/dev/null | wc -l | tr -d ' ')
if [ "$CACHE_COUNT" -ge 1 ]; then
  echo "  PASS: Cache file created ($CACHE_COUNT file(s))"; PASS=$((PASS + 1))
else
  echo "  FAIL: No cache file found"; FAIL=$((FAIL + 1))
fi

# ===========================================================
# Section 5: Command Registration
# ===========================================================

echo ""
echo "--- Section 5: Command Registration ---"

run_test "memory-query registered as medium tier in model-tiers.json"
TIER=$(jq -r '.commands["memory-query"]' config/model-tiers.json 2>/dev/null || echo "")
assert_equal "medium" "$TIER" "memory-query is medium tier"

run_test "memory-status registered as light tier in model-tiers.json"
TIER=$(jq -r '.commands["memory-status"]' config/model-tiers.json 2>/dev/null || echo "")
assert_equal "light" "$TIER" "memory-status is light tier"

# ===========================================================
# Section 6: Existing Tests Regression
# ===========================================================

echo ""
echo "--- Section 6: Existing Tests Regression ---"

run_test "Existing memory integration tests pass (static checks)"
EXISTING_OUTPUT=$(bash tests/test-memory-integration.sh 2>&1)
EXISTING_EXIT=$?
assert_exit 0 $EXISTING_EXIT "test-memory-integration.sh passes"

run_test "Existing lifecycle integration tests pass (no regression)"
LIFECYCLE_OUTPUT=$(bash tests/test-lifecycle-integration.sh 2>&1)
LIFECYCLE_EXIT=$?
assert_exit 0 $LIFECYCLE_EXIT "test-lifecycle-integration.sh passes (no regression)"

# ===========================================================
# Section 7: Bootstrap Degradation
# ===========================================================

echo ""
echo "--- Section 7: Bootstrap Degradation ---"

run_test "memory-bootstrap.sh has valid bash syntax"
bash -n scripts/pm/memory-bootstrap.sh 2>/dev/null
assert_exit 0 $? "Bootstrap script passes syntax check"

run_test "memory-bootstrap.sh exits 1 when agent not running"
# Create a temp project with config pointing to a definitely-unused port
TMP_PROJ=$(mktemp -d /tmp/ccpm-smoke-test-XXXXXX)
mkdir -p "$TMP_PROJ/config" "$TMP_PROJ/scripts/pm"
cat > "$TMP_PROJ/config/lifecycle.json" <<'CFGEOF'
{"memory_agent":{"enabled":true,"host":"localhost","port":19999,"query_on_prime":false,"query_on_pretask":false,"query_on_prd":false,"query_on_verify":false,"auto_ingest":false}}
CFGEOF
cp scripts/pm/lifecycle-helpers.sh "$TMP_PROJ/scripts/pm/"
cp scripts/pm/memory-health.sh "$TMP_PROJ/scripts/pm/"
rm -f /tmp/ccpm-memory-health-* 2>/dev/null || true
BOOTSTRAP_OUT=$(bash scripts/pm/memory-bootstrap.sh "$TMP_PROJ" 2>&1)
BOOTSTRAP_EXIT=$?
rm -rf "$TMP_PROJ" 2>/dev/null || true
assert_exit 1 $BOOTSTRAP_EXIT "memory-bootstrap.sh exits 1 when agent not running"
assert_contains "$BOOTSTRAP_OUT" "not running" "Bootstrap outputs 'not running' error"

# ===========================================================
# Summary
# ===========================================================

echo ""
echo "========================================="
printf "  Smoke: %d passed, %d failed (of %d)\n" "$PASS" "$FAIL" "$TOTAL"
echo "========================================="

[ "$FAIL" -gt 0 ] && exit 1
exit 0
