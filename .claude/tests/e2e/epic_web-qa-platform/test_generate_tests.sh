#!/bin/bash
# test_generate_tests.sh — Unit tests for scripts/qa/generate-tests.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
GENERATE="$REPO_ROOT/scripts/qa/generate-tests.sh"

PASS=0
FAIL=0
TMP_OUT=""

cleanup() {
  [ -n "$TMP_OUT" ] && rm -rf "$TMP_OUT" 2>/dev/null || true
}
trap cleanup EXIT

assert_contains() {
  local desc="$1"
  local file="$2"
  local expected="$3"
  if grep -q "$expected" "$file" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected '$expected' in $file)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local desc="$1"
  local file="$2"
  if [ -f "$file" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (file not found: $file)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1"
  local file="$2"
  local unexpected="$3"
  if ! grep -q "$unexpected" "$file" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (unexpected '$unexpected' found in $file)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== generate-tests.sh unit tests ==="
echo ""

# --- Test 1: goto + click → page.goto() + page.locator().click() ---
echo "[Test 1: goto + click scenario]"
TMP_OUT=$(mktemp -d)

INPUT=$(cat <<'EOF'
{
  "scenarios": [
    {
      "name": "submit form",
      "steps": [
        {"command": "goto", "args": ["http://localhost:3000"]},
        {"command": "click", "args": ["@e5"]}
      ],
      "passed": true,
      "selectors": {"@e5": "button >> text=Submit"}
    }
  ]
}
EOF
)

echo "$INPUT" | bash "$GENERATE" "$TMP_OUT" >/dev/null 2>&1

SPEC="$TMP_OUT/submit-form.spec.ts"
assert_file_exists "spec file created" "$SPEC"
assert_contains "has page.goto()" "$SPEC" "page.goto("
assert_contains "goto uses correct url" "$SPEC" "http://localhost:3000"
assert_contains "has locator click" "$SPEC" "page.locator("
assert_contains "uses resolved selector" "$SPEC" "button >> text=Submit"
assert_contains "has .click()" "$SPEC" ".click();"
assert_contains "has playwright import" "$SPEC" "from '@playwright/test'"

echo ""

# --- Test 2: fill → page.locator().fill() ---
echo "[Test 2: fill scenario]"
TMP_OUT2=$(mktemp -d)

INPUT2=$(cat <<'EOF'
{
  "scenarios": [
    {
      "name": "fill username",
      "steps": [
        {"command": "goto", "args": ["http://localhost:3000"]},
        {"command": "fill", "args": ["@e2", "testuser"]}
      ],
      "passed": true,
      "selectors": {"@e2": "input[name=username]"}
    }
  ]
}
EOF
)

echo "$INPUT2" | bash "$GENERATE" "$TMP_OUT2" >/dev/null 2>&1

SPEC2="$TMP_OUT2/fill-username.spec.ts"
assert_file_exists "spec file created for fill" "$SPEC2"
assert_contains "has page.locator fill" "$SPEC2" "page.locator("
assert_contains "uses fill selector" "$SPEC2" "input\[name=username\]"
assert_contains "has .fill()" "$SPEC2" ".fill("
assert_contains "fill has correct value" "$SPEC2" "testuser"

rm -rf "$TMP_OUT2"
echo ""

# --- Test 3: navigation-only scenario → valid test with title assertion ---
echo "[Test 3: navigation-only scenario]"
TMP_OUT3=$(mktemp -d)

INPUT3=$(cat <<'EOF'
{
  "scenarios": [
    {
      "name": "visit homepage",
      "steps": [
        {"command": "goto", "args": ["http://example.com"]}
      ],
      "passed": true,
      "selectors": {}
    }
  ]
}
EOF
)

echo "$INPUT3" | bash "$GENERATE" "$TMP_OUT3" >/dev/null 2>&1

SPEC3="$TMP_OUT3/visit-homepage.spec.ts"
assert_file_exists "spec file created for nav-only" "$SPEC3"
assert_contains "has page.goto()" "$SPEC3" "page.goto("
assert_contains "has title assertion" "$SPEC3" "toHaveTitle"

rm -rf "$TMP_OUT3"
echo ""

# --- Test 4: failed scenario is skipped ---
echo "[Test 4: failed scenario is skipped]"
TMP_OUT4=$(mktemp -d)

INPUT4=$(cat <<'EOF'
{
  "scenarios": [
    {
      "name": "failing test",
      "steps": [
        {"command": "goto", "args": ["http://localhost:9999"]}
      ],
      "passed": false,
      "selectors": {}
    }
  ]
}
EOF
)

# Should exit 0 but generate no files (or warn)
echo "$INPUT4" | bash "$GENERATE" "$TMP_OUT4" >/dev/null 2>&1 || true
SPEC4="$TMP_OUT4/failing-test.spec.ts"
if [ ! -f "$SPEC4" ]; then
  echo "  PASS: failed scenario not written to disk"
  PASS=$((PASS + 1))
else
  echo "  FAIL: failed scenario should not be written to disk"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMP_OUT4"
echo ""

# --- Test 5: ref without selector → getByRole fallback ---
echo "[Test 5: ref without selector falls back to getByRole]"
TMP_OUT5=$(mktemp -d)

INPUT5=$(cat <<'EOF'
{
  "scenarios": [
    {
      "name": "click with role fallback",
      "steps": [
        {"command": "goto", "args": ["http://localhost:3000"]},
        {"command": "click", "args": ["@e3"]}
      ],
      "passed": true,
      "selectors": {},
      "refs": [
        {"ref": "@e3", "role": "button", "name": "Login"}
      ]
    }
  ]
}
EOF
)

echo "$INPUT5" | bash "$GENERATE" "$TMP_OUT5" >/dev/null 2>&1

SPEC5="$TMP_OUT5/click-with-role-fallback.spec.ts"
assert_file_exists "spec file created for role fallback" "$SPEC5"
assert_contains "uses getByRole" "$SPEC5" "getByRole"
assert_contains "getByRole has role" "$SPEC5" "button"
assert_contains "getByRole has name" "$SPEC5" "Login"

rm -rf "$TMP_OUT5"
echo ""

# --- Test 6: output directory detection without playwright.config.ts ---
echo "[Test 6: default output dir (no playwright.config.ts in temp context)]"
TMP_OUT6=$(mktemp -d)

# The script uses REPO_ROOT detection; just verify it creates output dir
INPUT6='{"scenarios": [{"name": "dir test", "steps": [{"command": "goto", "args": ["http://example.com"]}], "passed": true, "selectors": {}}]}'
echo "$INPUT6" | bash "$GENERATE" "$TMP_OUT6" >/dev/null 2>&1

SPEC6="$TMP_OUT6/dir-test.spec.ts"
assert_file_exists "output created in specified dir" "$SPEC6"

rm -rf "$TMP_OUT6"
echo ""

# --- Summary ---
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
