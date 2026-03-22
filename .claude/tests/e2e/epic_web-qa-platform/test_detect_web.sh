#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DETECT_WEB="$REPO_ROOT/scripts/qa/detect-web.sh"
FIXTURES="$REPO_ROOT/tests/fixtures/web-qa"

pass=0
fail=0

run_test() {
    local name="$1"
    local result="$2"
    local expected_key="$3"
    local expected_val="$4"
    local actual
    actual=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('$expected_key','')).lower())" 2>/dev/null || echo "parse_error")
    if [[ "$actual" == "$expected_val" ]]; then
        echo "  PASS: $name"
        pass=$((pass + 1))
    else
        echo "  FAIL: $name — expected $expected_key=$expected_val, got: $actual"
        fail=$((fail + 1))
    fi
}

echo "=== detect-web.sh tests ==="

# Test 1: Next.js fixture
result=$(bash "$DETECT_WEB" "$FIXTURES/package-nextjs.json")
run_test "nextjs detected=true" "$result" "detected" "true"
run_test "nextjs framework=nextjs" "$result" "framework" "nextjs"

# Test 2: Nuxt fixture
result=$(bash "$DETECT_WEB" "$FIXTURES/package-nuxt.json")
run_test "nuxt detected=true" "$result" "detected" "true"
run_test "nuxt framework=nuxt" "$result" "framework" "nuxt"

# Test 3: Plain Node.js fixture
result=$(bash "$DETECT_WEB" "$FIXTURES/package-plain.json")
run_test "plain detected=false" "$result" "detected" "false"

# Test 4: Non-existent file
result=$(bash "$DETECT_WEB" "/nonexistent/package.json")
exit_code=$?
run_test "no file detected=false" "$result" "detected" "false"
if [[ $exit_code -eq 0 ]]; then
    echo "  PASS: no file exits 0"
    pass=$((pass + 1))
else
    echo "  FAIL: no file should exit 0, got $exit_code"
    fail=$((fail + 1))
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
