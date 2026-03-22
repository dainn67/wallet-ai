#!/bin/bash
# E2E Tests: QA Config validation
# Tests config/qa.json structure and content
set -euo pipefail

PASS=0
FAIL=0
CONFIG="config/qa.json"

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

echo "=== QA Config Tests ==="

# Test 1: Config file exists
if [ -f "$CONFIG" ]; then
  echo "  ✅ config/qa.json exists"
  (( PASS++ )) || true
else
  echo "  ❌ config/qa.json not found"
  (( FAIL++ )) || true
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Test 2: Valid JSON
if jq . "$CONFIG" >/dev/null 2>&1; then
  echo "  ✅ config/qa.json is valid JSON"
  (( PASS++ )) || true
else
  echo "  ❌ config/qa.json is not valid JSON"
  (( FAIL++ )) || true
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Test 3: Required fields exist
for field in enabled default_timeout health_score_threshold category_weights evidence_retention_runs; do
  val=$(jq -r "has(\"$field\")" "$CONFIG")
  assert_eq "has field '$field'" "true" "$val"
done

# Test 4: Category weights sum to 100
weights_sum=$(jq '[.category_weights | to_entries[] | .value] | add' "$CONFIG")
assert_eq "category_weights sum to 100" "100" "$weights_sum"

# Test 5: All 4 categories present
for cat in ui_layout navigation_flow data_display accessibility; do
  val=$(jq -r ".category_weights | has(\"$cat\")" "$CONFIG")
  assert_eq "category_weights has '$cat'" "true" "$val"
done

# Test 6: health_score_threshold is reasonable (0-100)
threshold=$(jq '.health_score_threshold' "$CONFIG")
if [ "$threshold" -ge 0 ] && [ "$threshold" -le 100 ] 2>/dev/null; then
  echo "  ✅ health_score_threshold ($threshold) is in range 0-100"
  (( PASS++ )) || true
else
  echo "  ❌ health_score_threshold ($threshold) out of range"
  (( FAIL++ )) || true
fi

# Test 7: default_timeout is positive
timeout_val=$(jq '.default_timeout' "$CONFIG")
if [ "$timeout_val" -gt 0 ] 2>/dev/null; then
  echo "  ✅ default_timeout ($timeout_val) is positive"
  (( PASS++ )) || true
else
  echo "  ❌ default_timeout ($timeout_val) is not positive"
  (( FAIL++ )) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
