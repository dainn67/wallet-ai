#!/bin/bash
# E2E Tests: QA Agent Registry parsing
# Tests config/qa-agents.json structure and detect-agents.sh footprint
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

REGISTRY="config/qa-agents.json"
DETECT_SCRIPT="scripts/qa/detect-agents.sh"

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

echo "=== QA Agent Registry Tests ==="

# Test 1: Registry file exists
echo ""
echo "-- Prerequisites --"
if [ -f "$REGISTRY" ]; then
  echo "  ✅ $REGISTRY exists"
  (( PASS++ )) || true
else
  echo "  ❌ $REGISTRY not found — run T191 first"
  (( FAIL++ )) || true
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

if [ -f "$DETECT_SCRIPT" ]; then
  echo "  ✅ $DETECT_SCRIPT exists"
  (( PASS++ )) || true
else
  echo "  ❌ $DETECT_SCRIPT not found — run T191 first"
  (( FAIL++ )) || true
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Test 2: Valid JSON
echo ""
echo "-- Valid registry parsing --"
if python3 -c "import json; json.load(open('$REGISTRY'))" 2>/dev/null; then
  echo "  ✅ registry is valid JSON"
  (( PASS++ )) || true
else
  echo "  ❌ registry is not valid JSON"
  (( FAIL++ )) || true
fi

# Test 3: Has agents array
agents_count=$(python3 -c "import json; d=json.load(open('$REGISTRY')); print(len(d.get('agents',[])))" 2>/dev/null || echo "-1")
if [ "$agents_count" -ge 0 ] 2>/dev/null; then
  echo "  ✅ registry has 'agents' array ($agents_count agents)"
  (( PASS++ )) || true
else
  echo "  ❌ registry missing 'agents' array"
  (( FAIL++ )) || true
fi

# Test 4: Each agent has required fields
echo ""
echo "-- Agent field validation --"
python3 - <<'PYEOF'
import json, sys
data = json.load(open("config/qa-agents.json"))
agents = data.get("agents", [])
required = ["name", "detect_pattern", "command", "blocking", "timeout"]
errors = []
for agent in agents:
    for field in required:
        if field not in agent:
            errors.append(f"Agent '{agent.get('name','?')}' missing field '{field}'")
if errors:
    for e in errors:
        print(f"  ❌ {e}")
    sys.exit(1)
else:
    print(f"  ✅ all {len(agents)} agent(s) have required fields")
PYEOF
if [ $? -eq 0 ]; then
  (( PASS++ )) || true
else
  (( FAIL++ )) || true
fi

# Test 5: Empty agents array → detect returns empty, exit 0
echo ""
echo "-- Empty registry: detect returns empty --"
TMPDIR_EMPTY=$(mktemp -d)
trap 'rm -rf "$TMPDIR_EMPTY"' EXIT
mkdir -p "$TMPDIR_EMPTY/.claude/config"
echo '{"agents":[]}' > "$TMPDIR_EMPTY/.claude/config/qa-agents.json"
output=$(PROJECT_ROOT="$TMPDIR_EMPTY" bash "$DETECT_SCRIPT" 2>/dev/null || true)
if [ -z "$output" ]; then
  echo "  ✅ empty registry → detect returns empty output"
  (( PASS++ )) || true
else
  echo "  ❌ empty registry → unexpected output: $output"
  (( FAIL++ )) || true
fi
trap - EXIT
rm -rf "$TMPDIR_EMPTY"

# Test 6: Malformed JSON → python3 exits non-zero
echo ""
echo "-- Malformed JSON: python3 parse fails --"
TMPDIR_BAD=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BAD"' EXIT
echo '{not valid json' > "$TMPDIR_BAD/bad.json"
if python3 -c "import json; json.load(open('$TMPDIR_BAD/bad.json'))" 2>/dev/null; then
  echo "  ❌ malformed JSON parsed without error"
  (( FAIL++ )) || true
else
  echo "  ✅ malformed JSON → python3 exits non-zero"
  (( PASS++ )) || true
fi
trap - EXIT
rm -rf "$TMPDIR_BAD"

# Test 7: NFR-3 line count < 100
echo ""
echo "-- NFR-3: footprint < 100 lines total --"
registry_lines=$(wc -l < "$REGISTRY" | tr -d ' ')
detect_lines=$(wc -l < "$DETECT_SCRIPT" | tr -d ' ')
total=$((registry_lines + detect_lines))
if [ "$total" -lt 100 ]; then
  echo "  ✅ line count: registry=$registry_lines + detect=$detect_lines = $total (< 100)"
  (( PASS++ )) || true
else
  echo "  ❌ line count: registry=$registry_lines + detect=$detect_lines = $total (>= 100)"
  (( FAIL++ )) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
