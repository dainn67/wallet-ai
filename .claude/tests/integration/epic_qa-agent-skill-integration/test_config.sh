#!/bin/bash
# Integration Tests: epic-verify.json and qa-agents.json config validation
# Tests: QA tier has execution:agent, qa-agents.json valid and parseable
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

VERIFY_CONFIG="$REPO_ROOT/config/epic-verify.json"
QA_AGENTS_CONFIG="$REPO_ROOT/config/qa-agents.json"

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected '$expected', got '$actual'"
    (( FAIL++ )) || true
  fi
}

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

echo "=== Config Validation Tests ==="

# Prerequisites
echo ""
echo "-- Prerequisites --"
if [ -f "$VERIFY_CONFIG" ]; then
  echo "  ✅ config/epic-verify.json exists"
  (( PASS++ )) || true
else
  echo "  ❌ config/epic-verify.json not found"
  (( FAIL++ )) || true
  echo ""; echo "Results: $PASS passed, $FAIL failed"; exit 1
fi

if [ -f "$QA_AGENTS_CONFIG" ]; then
  echo "  ✅ config/qa-agents.json exists"
  (( PASS++ )) || true
else
  echo "  ❌ config/qa-agents.json not found"
  (( FAIL++ )) || true
  echo ""; echo "Results: $PASS passed, $FAIL failed"; exit 1
fi

# Test 1: epic-verify.json is valid JSON
echo ""
echo "-- epic-verify.json validity --"
if python3 -c "import json; json.load(open('$VERIFY_CONFIG'))" 2>/dev/null; then
  echo "  ✅ epic-verify.json is valid JSON"
  (( PASS++ )) || true
else
  echo "  ❌ epic-verify.json is not valid JSON"
  (( FAIL++ )) || true
fi

# Test 2: epic-verify.json QA tier has execution: agent
echo ""
echo "-- epic-verify.json QA tier execution:agent --"
QA_EXECUTION=$(python3 -c "
import json, sys
d = json.load(open('$VERIFY_CONFIG'))
qa = d.get('phase_b', {}).get('test_tiers', {}).get('qa', {})
print(qa.get('execution', ''))
" 2>/dev/null || echo "")
assert_eq "QA tier execution field is 'agent'" "agent" "$QA_EXECUTION"

# Test 3: epic-verify.json QA tier required=false (non-blocking)
echo ""
echo "-- epic-verify.json QA tier required:false (NFR-2) --"
QA_REQUIRED=$(python3 -c "
import json, sys
d = json.load(open('$VERIFY_CONFIG'))
qa = d.get('phase_b', {}).get('test_tiers', {}).get('qa', {})
print(str(qa.get('required', True)).lower())
" 2>/dev/null || echo "")
assert_eq "QA tier required is false (non-blocking, NFR-2)" "false" "$QA_REQUIRED"

# Test 4: qa-agents.json is valid JSON
echo ""
echo "-- qa-agents.json validity --"
if python3 -c "import json; json.load(open('$QA_AGENTS_CONFIG'))" 2>/dev/null; then
  echo "  ✅ qa-agents.json is valid JSON"
  (( PASS++ )) || true
else
  echo "  ❌ qa-agents.json is not valid JSON"
  (( FAIL++ )) || true
fi

# Test 5: qa-agents.json has agents array
echo ""
echo "-- qa-agents.json structure --"
HAS_AGENTS=$(python3 -c "
import json
d = json.load(open('$QA_AGENTS_CONFIG'))
print('yes' if isinstance(d.get('agents'), list) else 'no')
" 2>/dev/null || echo "no")
assert_eq "qa-agents.json has 'agents' array" "yes" "$HAS_AGENTS"

# Test 6: ios-qa-agent entry has required fields
echo ""
echo "-- ios-qa-agent required fields --"
IOS_AGENT_FIELDS=$(python3 -c "
import json
d = json.load(open('$QA_AGENTS_CONFIG'))
agents = d.get('agents', [])
ios = next((a for a in agents if a.get('name') == 'ios-qa-agent'), None)
if ios is None:
    print('missing')
else:
    required = ['name', 'detect_pattern', 'command', 'blocking', 'timeout']
    missing = [f for f in required if f not in ios]
    print(','.join(missing) if missing else 'ok')
" 2>/dev/null || echo "error")
assert_eq "ios-qa-agent has all required fields" "ok" "$IOS_AGENT_FIELDS"

# Test 7: ios-qa-agent blocking=false (non-blocking, NFR-2)
echo ""
echo "-- ios-qa-agent non-blocking (NFR-2) --"
IOS_BLOCKING=$(python3 -c "
import json
d = json.load(open('$QA_AGENTS_CONFIG'))
agents = d.get('agents', [])
ios = next((a for a in agents if a.get('name') == 'ios-qa-agent'), None)
print(str(ios.get('blocking', True)).lower() if ios else 'missing')
" 2>/dev/null || echo "missing")
assert_eq "ios-qa-agent blocking is false (NFR-2)" "false" "$IOS_BLOCKING"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
