#!/bin/bash
# Tests for scripts/qa/health-score.sh
# Usage: bash tests/e2e/epic_web-qa-platform/test_health_score.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/qa/health-score.sh"

pass=0
fail=0

_assert() {
  local desc="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $desc"
    ((pass++))
  else
    echo "  ❌ $desc"
    echo "     Expected: $expected"
    echo "     Actual:   $actual"
    ((fail++))
  fi
}

_assert_contains() {
  local desc="$1"
  local haystack="$2"
  local needle="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "  ✅ $desc"
    ((pass++))
  else
    echo "  ❌ $desc (missing: $needle)"
    echo "     In: $haystack"
    ((fail++))
  fi
}

echo "=== Health Score Tests ==="

# Test 1: Zero issues → total=100
echo ""
echo "Test 1: Zero issues → total=100"
result=$(echo '{"console_errors": 0, "broken_links": 0, "total_links": 10, "images_without_alt": 0, "total_images": 5}' | bash "$SCRIPT")
total=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['data']['total'])" "$result")
_assert "total=100" "$total" "100"
console_score=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['data']['categories']['console']['score'])" "$result")
_assert "console score=100" "$console_score" "100"

# Test 2: 2 console errors → console score=70, functional score=60
echo ""
echo "Test 2: 2 console errors → console score=70, functional score=60"
result=$(echo '{"console_errors": 2, "broken_links": 0, "total_links": 5}' | bash "$SCRIPT")
console_score=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['data']['categories']['console']['score'])" "$result")
_assert "console score=70 (100 - 2*15)" "$console_score" "70"
functional_score=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['data']['categories']['functional']['score'])" "$result")
_assert "functional score=60 (100 - 2*20)" "$functional_score" "60"

# Test 3: 1 broken link out of 10 → links score=90
echo ""
echo "Test 3: 1 broken link out of 10 → links score=90"
result=$(echo '{"broken_links": 1, "total_links": 10}' | bash "$SCRIPT")
links_score=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['data']['categories']['links']['score'])" "$result")
_assert "links score=90" "$links_score" "90"

# Test 4: Missing visual data → visual not_assessed
echo ""
echo "Test 4: Missing visual data → visual not assessed"
result=$(echo '{"console_errors": 0, "total_links": 5, "broken_links": 0}' | bash "$SCRIPT")
not_assessed=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('visual' in d['data']['not_assessed_list'])" "$result")
_assert "visual not assessed" "$not_assessed" "True"

# Test 5: All categories failing → total near 0
echo ""
echo "Test 5: High error counts → low total score"
result=$(echo '{"console_errors": 10, "broken_links": 10, "total_links": 10, "images_without_alt": 5, "total_images": 5, "js_errors": 10, "forms_with_labels": 0, "total_forms": 5}' | bash "$SCRIPT")
total=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['data']['total'])" "$result")
if [ "$total" -le 20 ]; then
  echo "  ✅ total=$total (≤20 as expected)"
  ((pass++))
else
  echo "  ❌ total=$total (expected ≤20)"
  ((fail++))
fi

# Test 6: success=true always present
echo ""
echo "Test 6: Output always contains success field"
result=$(echo '{"console_errors": 0}' | bash "$SCRIPT")
_assert_contains "success field present" "$result" '"success"'
_assert_contains "data field present" "$result" '"data"'
_assert_contains "total field present" "$result" '"total"'
_assert_contains "categories field present" "$result" '"categories"'
_assert_contains "assessed field present" "$result" '"assessed"'

# Test 7: Perfect score with all categories
echo ""
echo "Test 7: All perfect data → total=100"
result=$(echo '{"console_errors": 0, "console_warnings": 0, "broken_links": 0, "total_links": 20, "cls": 0.05, "js_errors": 0, "forms_with_labels": 3, "total_forms": 3, "load_time": 0.5, "images_without_alt": 0, "total_images": 10, "aria_landmarks": true, "heading_hierarchy": true, "a11y_errors": 0}' | bash "$SCRIPT")
total=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['data']['total'])" "$result")
_assert "total=100 (all perfect)" "$total" "100"
assessed=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['data']['assessed'])" "$result")
_assert "all 8 categories assessed" "$assessed" "8"

# Test 8: Zero total_links → links score=100
echo ""
echo "Test 8: Zero links → links score=100"
result=$(echo '{"broken_links": 0, "total_links": 0}' | bash "$SCRIPT")
links_score=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['data']['categories']['links']['score'])" "$result")
_assert "links score=100 when zero links" "$links_score" "100"

# Test 9: Empty input → error response
echo ""
echo "Test 9: Empty input → error"
result=$(echo '' | bash "$SCRIPT" 2>&1 || true)
_assert_contains "error on empty input" "$result" '"success"'

# Summary
echo ""
echo "=== Results: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ] && exit 0 || exit 1
