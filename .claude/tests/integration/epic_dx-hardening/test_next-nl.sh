#!/usr/bin/env bash
# test-next-nl.sh — Integration tests for pm:next NL intent matching (Task #185)
#
# Usage: bash tests/integration/epic_dx-hardening/test-next-nl.sh

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

assert_contains() {
  local needle="$1" haystack="$2" label="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label"
    echo "     Expected to find: $needle"
    echo "     Got: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_empty() {
  local value="$1" label="$2"
  if [ -n "$value" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (was empty)"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "  ✅ $label (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_count_ge() {
  local min="$1" actual="$2" label="$3"
  if [ "$actual" -ge "$min" ]; then
    echo "  ✅ $label ($actual >= $min)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (expected >= $min, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# --- Tests ---

run_test "commands/pm/next.md has correct frontmatter — name field"
NEXT_MD="$PROJECT_ROOT/commands/pm/next.md"
if [ -f "$NEXT_MD" ]; then
  name_field=$(grep -m1 "^name:" "$NEXT_MD" | sed 's/name: *//')
  assert_contains "next" "$name_field" "name: next present"
else
  echo "  ❌ commands/pm/next.md not found"
  FAIL=$((FAIL + 1))
  TOTAL=$((TOTAL + 1))
fi

run_test "commands/pm/next.md has allowed-tools with Bash, Glob, Read"
allowed=$(grep -m1 "^allowed-tools:" "$NEXT_MD" 2>/dev/null || echo "")
assert_contains "Bash" "$allowed" "Bash in allowed-tools"
assert_contains "Glob" "$allowed" "Glob in allowed-tools"
assert_contains "Read" "$allowed" "Read in allowed-tools"

run_test "commands/pm/next.md has NL matching section"
content=$(cat "$NEXT_MD")
assert_contains "NL Intent Matching" "$content" "NL Intent Matching section present"
assert_contains "ARGUMENTS" "$content" "ARGUMENTS branching logic present"

run_test "commands/pm/next.md references script fallback for empty args"
assert_contains "next.sh --smart" "$content" "script fallback (next.sh --smart) present"

run_test "commands/pm/next.md has auto-discovery script"
assert_contains "commands/pm/\*.md" "$content" "auto-discovery glob pattern present"

run_test "Auto-discovery script finds all commands in commands/pm/"
catalog_output=$(
  for f in "$PROJECT_ROOT/commands/pm/"*.md; do
    name=$(grep -m1 "^name:" "$f" 2>/dev/null | sed 's/name: *//')
    desc=$(grep -m1 "^description:" "$f" 2>/dev/null | sed 's/description: *//')
    [ -n "$name" ] && [ -n "$desc" ] && echo "- pm:$name — $desc"
  done
)
# Count entries
entry_count=$(echo "$catalog_output" | grep -c "^- pm:" 2>/dev/null || echo 0)
assert_count_ge 5 "$entry_count" "at least 5 commands discovered"

run_test "Auto-discovery output format matches expected pattern"
if [ -n "$catalog_output" ]; then
  first_entry=$(echo "$catalog_output" | grep "^- pm:" | head -1)
  assert_contains "^- pm:" "$first_entry" "entry starts with '- pm:'"
  assert_contains " — " "$first_entry" "entry has ' — ' separator"
else
  echo "  ❌ No catalog output"
  FAIL=$((FAIL + 1))
  TOTAL=$((TOTAL + 1))
fi

run_test "Auto-discovery finds pm:next itself (has name+description)"
assert_contains "pm:next" "$catalog_output" "pm:next appears in catalog"

run_test "Auto-discovery finds pm:build (has name+description)"
assert_contains "pm:build" "$catalog_output" "pm:build appears in catalog"

run_test "commands/pm/next.md mentions Vietnamese query examples"
assert_contains "tiến độ" "$content" "Vietnamese 'tiến độ' example present"
assert_contains "prd-new" "$content" "prd-new hint present"

run_test "config/model-tiers.json exists and has 'next' command entry"
tiers_file="$PROJECT_ROOT/config/model-tiers.json"
if [ -f "$tiers_file" ]; then
  tiers_content=$(cat "$tiers_file")
  assert_contains '"next"' "$tiers_content" "'next' in model-tiers.json"
else
  echo "  ⚠️  config/model-tiers.json not found — tier annotations will be omitted (acceptable per spec)"
  PASS=$((PASS + 1))  # Not failing — spec says omit if missing
  TOTAL=$((TOTAL + 1))
fi

run_test "commands/pm/next.md handles 'No matching commands found' edge case"
assert_contains "No matching commands found" "$content" "no-match fallback message present"

run_test "commands/pm/next.md has top-3 suggestions for ambiguous intent"
assert_contains "top-3" "$content" "top-3 ambiguous suggestion logic present"

run_test "commands/pm/next.md truncates long queries (100 chars)"
assert_contains "100" "$content" "100-char truncation rule present"

# --- Summary ---

echo ""
echo "══════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"

if [ "$FAIL" -eq 0 ]; then
  echo "✅ All tests passed"
  exit 0
else
  echo "❌ $FAIL test(s) failed"
  exit 1
fi
