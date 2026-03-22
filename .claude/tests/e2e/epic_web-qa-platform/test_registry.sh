#!/bin/bash
# test_registry.sh — E2E tests for QA Agent Registry + Web QA Config
# Task #207: web-qa-platform epic
set -euo pipefail

PASS=0
FAIL=0
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
QA_AGENTS_JSON="$ROOT/config/qa-agents.json"
WEB_QA_JSON="$ROOT/config/web-qa.json"

ok() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- Test 1: qa-agents.json is valid JSON ---
python3 -c "import json; json.load(open('$QA_AGENTS_JSON'))" 2>/dev/null \
  && ok "qa-agents.json is valid JSON" || fail "qa-agents.json is invalid JSON"

# --- Test 2: web-qa-agent entry exists ---
python3 -c "
import json
agents = json.load(open('$QA_AGENTS_JSON'))['agents']
names = [a['name'] for a in agents]
assert 'web-qa-agent' in names
" 2>/dev/null && ok "web-qa-agent entry exists in registry" || fail "web-qa-agent missing from registry"

# --- Test 3: web-qa-agent has detect_command field ---
python3 -c "
import json
agents = json.load(open('$QA_AGENTS_JSON'))['agents']
web = next(a for a in agents if a['name'] == 'web-qa-agent')
assert 'detect_command' in web
assert web['detect_command'] == 'scripts/qa/detect-web.sh'
" 2>/dev/null && ok "web-qa-agent detect_command points to detect-web.sh" || fail "web-qa-agent detect_command incorrect"

# --- Test 4: web-qa.json is valid JSON ---
python3 -c "import json; json.load(open('$WEB_QA_JSON'))" 2>/dev/null \
  && ok "web-qa.json is valid JSON" || fail "web-qa.json is invalid JSON"

# --- Test 5: health_score_weights sum to 100 ---
python3 -c "
import json
cfg = json.load(open('$WEB_QA_JSON'))
weights = cfg['health_score_weights']
total = sum(weights.values())
assert total == 100, f'Weights sum to {total}, expected 100'
assert len(weights) == 8, f'Expected 8 categories, got {len(weights)}'
" 2>/dev/null && ok "health_score_weights: 8 categories summing to 100" || fail "health_score_weights invalid"

# --- Test 6: port_scan list is non-empty ---
python3 -c "
import json
cfg = json.load(open('$WEB_QA_JSON'))
ports = cfg['port_scan']
assert isinstance(ports, list) and len(ports) > 0
" 2>/dev/null && ok "port_scan list is non-empty" || fail "port_scan invalid"

# --- Test 7: detect-web.sh is executable ---
[ -x "$ROOT/scripts/qa/detect-web.sh" ] \
  && ok "detect-web.sh is executable" || fail "detect-web.sh not executable"

# --- Test 8: detect-agents.sh supports detect_command (syntax check) ---
bash -n "$ROOT/scripts/qa/detect-agents.sh" 2>/dev/null \
  && ok "detect-agents.sh passes bash syntax check" || fail "detect-agents.sh syntax error"

# --- Test 9: ios-qa-agent still present (regression) ---
python3 -c "
import json
agents = json.load(open('$QA_AGENTS_JSON'))['agents']
names = [a['name'] for a in agents]
assert 'ios-qa-agent' in names
" 2>/dev/null && ok "ios-qa-agent still present (regression)" || fail "ios-qa-agent missing (regression)"

# --- Test 10: detect-agents.sh exits 0 on project without matching files ---
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q && git commit -q --allow-empty -m "init"
OUTPUT=$(bash "$ROOT/scripts/qa/detect-agents.sh" 2>/dev/null || true)
[ -z "$OUTPUT" ] && ok "detect-agents.sh returns empty output on non-matching project" \
  || fail "detect-agents.sh unexpected output on non-matching project"
cd "$ROOT"
rm -rf "$TMPDIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
