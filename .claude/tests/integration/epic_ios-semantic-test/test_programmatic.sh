#!/bin/bash
# Integration tests for programmatic QA CLI (T168)
# Tests: CLI invocation, exit codes, config/epic-verify.json qa tier
# These tests do NOT require a real iOS simulator.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
_pass() { echo "  ✅ $1"; ((PASS++)) || true; }
_fail() { echo "  ❌ $1"; ((FAIL++)) || true; ERRORS+=("$1"); }

assert_exit_code() {
  local description="$1"
  local expected="$2"
  shift 2
  local actual
  "$@" > /dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    _pass "$description (exit $actual)"
  else
    _fail "$description: expected exit $expected, got $actual"
  fi
}

# ---------------------------------------------------------------------------
# 1. Python files exist
# ---------------------------------------------------------------------------
echo "--- File existence ---"
for f in scripts/qa/cli.py scripts/qa/runner.py scripts/qa/evaluator.py; do
  if [ -f "$REPO_ROOT/$f" ]; then
    _pass "File exists: $f"
  else
    _fail "File missing: $f"
  fi
done

# ---------------------------------------------------------------------------
# 2. CLI --help exits 0
# ---------------------------------------------------------------------------
echo "--- CLI help ---"
assert_exit_code "cli.py --help exits 0" 0 python3 "$REPO_ROOT/scripts/qa/cli.py" --help

# ---------------------------------------------------------------------------
# 3. Missing --non-interactive flag → exit 3
# ---------------------------------------------------------------------------
echo "--- Missing --non-interactive flag ---"
(
  cd "$REPO_ROOT"
  result=0
  python3 scripts/qa/cli.py run 2>/dev/null || result=$?
  if [ "$result" -eq 3 ]; then
    _pass "cli.py run without --non-interactive exits 3"
  else
    _fail "cli.py run without --non-interactive should exit 3, got $result"
  fi
)

# ---------------------------------------------------------------------------
# 4. Missing ANTHROPIC_API_KEY → exit 3
# ---------------------------------------------------------------------------
echo "--- Missing ANTHROPIC_API_KEY ---"
(
  cd "$REPO_ROOT"
  result=0
  env -u ANTHROPIC_API_KEY python3 scripts/qa/cli.py run --non-interactive 2>/dev/null || result=$?
  if [ "$result" -eq 3 ]; then
    _pass "Missing ANTHROPIC_API_KEY exits 3"
  else
    _fail "Missing ANTHROPIC_API_KEY should exit 3, got $result"
  fi
)

# ---------------------------------------------------------------------------
# 5. Error message content for missing API key
# ---------------------------------------------------------------------------
echo "--- Error message content ---"
(
  cd "$REPO_ROOT"
  err_output=$(env -u ANTHROPIC_API_KEY python3 scripts/qa/cli.py run --non-interactive 2>&1 || true)
  if echo "$err_output" | grep -q "ANTHROPIC_API_KEY"; then
    _pass "Error message mentions ANTHROPIC_API_KEY"
  else
    _fail "Error message missing ANTHROPIC_API_KEY: $err_output"
  fi
)

# ---------------------------------------------------------------------------
# 6. axe_batch function exists in axe-wrapper.sh
# ---------------------------------------------------------------------------
echo "--- axe_batch function ---"
if grep -q "^axe_batch()" "$REPO_ROOT/scripts/qa/axe-wrapper.sh"; then
  _pass "axe_batch() function defined in axe-wrapper.sh"
else
  _fail "axe_batch() not found in axe-wrapper.sh"
fi

# ---------------------------------------------------------------------------
# 7. config/epic-verify.json has qa tier
# ---------------------------------------------------------------------------
echo "--- epic-verify.json qa tier ---"
if python3 -c "
import json, sys
data = json.load(open('$REPO_ROOT/config/epic-verify.json'))
tiers = data.get('phase_b', {}).get('test_tiers', {})
qa = tiers.get('qa', {})
assert 'required' in qa, 'qa tier missing required field'
assert 'blocking' in qa, 'qa tier missing blocking field'
assert qa['required'] == False, 'qa.required should be false'
assert qa['blocking'] == False, 'qa.blocking should be false'
print('OK')
" 2>/dev/null | grep -q "OK"; then
  _pass "epic-verify.json has valid qa tier (required=false, blocking=false)"
else
  _fail "epic-verify.json qa tier invalid or missing"
fi

# ---------------------------------------------------------------------------
# 8. qa tier command references cli.py
# ---------------------------------------------------------------------------
echo "--- qa tier command ---"
if python3 -c "
import json
data = json.load(open('$REPO_ROOT/config/epic-verify.json'))
tiers = data.get('phase_b', {}).get('test_tiers', {})
qa = tiers.get('qa', {})
cmd = qa.get('command', '')
assert 'cli.py' in cmd, f'Expected cli.py in command: {cmd}'
assert '--non-interactive' in cmd, f'Expected --non-interactive in command: {cmd}'
print('OK')
" 2>/dev/null | grep -q "OK"; then
  _pass "qa tier command references cli.py --non-interactive"
else
  _fail "qa tier command missing cli.py or --non-interactive"
fi

# ---------------------------------------------------------------------------
# 9. shellcheck on axe-wrapper.sh
# ---------------------------------------------------------------------------
echo "--- shellcheck ---"
if command -v shellcheck &>/dev/null; then
  if shellcheck -x "$REPO_ROOT/scripts/qa/axe-wrapper.sh" 2>/dev/null; then
    _pass "shellcheck passes on axe-wrapper.sh"
  else
    _fail "shellcheck reports issues in axe-wrapper.sh"
  fi
else
  _pass "shellcheck not installed — skipping"
fi

# ---------------------------------------------------------------------------
# 10. Python imports work
# ---------------------------------------------------------------------------
echo "--- Python imports ---"
(
  cd "$REPO_ROOT"
  if python3 -c "
import sys
sys.path.insert(0, '.')
from scripts.qa.runner import QARunner, _detect_action, _extract_quoted
from scripts.qa.evaluator import ConfigError
print('OK')
" 2>/dev/null | grep -q "OK"; then
    _pass "Python module imports succeed"
  else
    _fail "Python module import failed"
  fi
)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Integration results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "Failures:"
  for e in "${ERRORS[@]}"; do echo "  - $e"; done
fi

[ "$FAIL" -eq 0 ]
