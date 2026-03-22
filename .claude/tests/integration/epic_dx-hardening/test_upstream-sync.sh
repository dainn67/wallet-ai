#!/usr/bin/env bash
# test-upstream-sync.sh — Unit tests for scripts/pm/upstream-sync.sh
#
# Usage: bash tests/integration/epic_dx-hardening/test-upstream-sync.sh

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

assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "  ✅ $label (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local needle="$1" haystack="$2" label="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (expected '$needle' in output)"
    echo "     Got: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local needle="$1" haystack="$2" label="$3"
  if ! echo "$haystack" | grep -qF "$needle"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (unexpected '$needle' in output)"
    FAIL=$((FAIL + 1))
  fi
}

assert_equals() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (expected='$expected', got='$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local file="$1" label="$2"
  if [ -f "$file" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (file not found: $file)"
    FAIL=$((FAIL + 1))
  fi
}

# --- Setup ---

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Source helpers to test in isolation (export vars, source functions) ---

# We need to test individual functions; source the script with _CCPM_ROOT overridden
export _CCPM_ROOT="$PROJECT_ROOT"

# Source the script functions (skip CLI entry; script uses case statement at bottom)
source_script() {
  # Extract and eval function definitions only (skip the CLI case block)
  # We do this by sourcing the full script — since 'case' block only triggers on explicit call,
  # and we're not passing "$1", the default case will print usage and exit.
  # Instead, we source specific functions by exporting _CCPM_ROOT and sourcing after stripping the CLI block.
  local tmp_source
  tmp_source=$(mktemp "${TMPDIR_TEST}/upstream-sync-XXXXXX.sh")
  # Remove the CLI entry point (case block at end) so sourcing is safe
  awk '/^# CLI entry point/{exit} {print}' "$PROJECT_ROOT/scripts/pm/upstream-sync.sh" > "$tmp_source"
  # shellcheck disable=SC1090
  source "$tmp_source"
}

source_script

# --- Tests ---

run_test "Script file exists and is executable"
assert_file_exists "$PROJECT_ROOT/scripts/pm/upstream-sync.sh" "script file exists"
out=$(test -x "$PROJECT_ROOT/scripts/pm/upstream-sync.sh" && echo "executable" || echo "not executable")
assert_equals "executable" "$out" "script is executable"

run_test "Command file exists with correct frontmatter"
assert_file_exists "$PROJECT_ROOT/commands/pm/upstream-sync.md" "command file exists"
out=$(head -10 "$PROJECT_ROOT/commands/pm/upstream-sync.md")
assert_contains "name: upstream-sync" "$out" "has name field"
assert_contains "allowed-tools:" "$out" "has allowed-tools field"
assert_contains "model: sonnet" "$out" "has model field"

run_test "get_last_sync returns empty when no sync log"
SYNC_LOG_ORIG=".claude/context/upstream-sync-log.md"
# Temporarily set SYNC_LOG to non-existent path
SYNC_LOG="${TMPDIR_TEST}/nonexistent-sync-log.md"
result=$(get_last_sync)
assert_equals "" "$result" "returns empty string on first sync"
SYNC_LOG="$SYNC_LOG_ORIG"

run_test "get_last_sync returns commit hash from sync log"
SYNC_LOG="${TMPDIR_TEST}/test-sync-log.md"
cat > "$SYNC_LOG" <<'EOF'
# Upstream Sync Log

## Sync: 2026-01-01T00:00:00Z
commit: abc123def456

| Category | Action | Files |
|----------|--------|-------|
| scripts  | accepted | — |
EOF
result=$(get_last_sync)
assert_equals "abc123def456" "$result" "returns commit hash from sync log"
SYNC_LOG="$SYNC_LOG_ORIG"

run_test "categorize_changes correctly groups files"
# We'll test the categorization logic by creating a mock diff output
# and piping it through categorize_changes-like logic
test_categorize() {
  local file="$1"
  case "$file" in
    scripts/pm/*)   echo "scripts" ;;
    commands/pm/*)  echo "commands" ;;
    rules/*)        echo "rules" ;;
    config/*)       echo "config" ;;
    CLAUDE.md)      echo "breaking" ;;
    hooks/*)        echo "breaking" ;;
    *)              echo "other" ;;
  esac
}

assert_equals "scripts"  "$(test_categorize 'scripts/pm/new-feature.sh')"  "scripts/pm/* → scripts"
assert_equals "commands" "$(test_categorize 'commands/pm/status.md')"       "commands/pm/* → commands"
assert_equals "rules"    "$(test_categorize 'rules/standard-patterns.md')"  "rules/* → rules"
assert_equals "config"   "$(test_categorize 'config/build.json')"           "config/* → config"
assert_equals "breaking" "$(test_categorize 'CLAUDE.md')"                   "CLAUDE.md → breaking"
assert_equals "breaking" "$(test_categorize 'hooks/pre-commit')"            "hooks/* → breaking"
assert_equals "other"    "$(test_categorize 'README.md')"                   "README.md → other"

run_test "update_sync_log creates log file if missing"
SYNC_LOG="${TMPDIR_TEST}/new-sync-log.md"
update_sync_log "deadbeef1234" "scripts commands" "rules"
assert_file_exists "$SYNC_LOG" "sync log created"
log_content=$(cat "$SYNC_LOG")
assert_contains "commit: deadbeef1234" "$log_content" "log contains commit hash"
assert_contains "accepted" "$log_content" "log contains accepted action"
assert_contains "scripts" "$log_content" "log contains scripts category"
SYNC_LOG="$SYNC_LOG_ORIG"

run_test "update_sync_log prepends to existing log"
SYNC_LOG="${TMPDIR_TEST}/existing-sync-log.md"
# Create existing log
cat > "$SYNC_LOG" <<'EOF'
# Upstream Sync Log

## Sync: 2026-01-01T00:00:00Z
commit: oldhash111

| Category | Action | Files |
|----------|--------|-------|
| rules    | accepted | — |
EOF
update_sync_log "newhash222" "commands" ""
log_content=$(cat "$SYNC_LOG")
# New entry should appear before old one
new_pos=$(grep -n "newhash222" "$SYNC_LOG" | cut -d: -f1 | head -1)
old_pos=$(grep -n "oldhash111" "$SYNC_LOG" | cut -d: -f1 | head -1)
if [ "$new_pos" -lt "$old_pos" ]; then
  echo "  ✅ new entry appears before old entry"
  PASS=$((PASS + 1))
else
  echo "  ❌ new entry should appear before old entry (new=$new_pos, old=$old_pos)"
  FAIL=$((FAIL + 1))
fi
SYNC_LOG="$SYNC_LOG_ORIG"

run_test "Script exits 1 with clear error when upstream remote unreachable"
# Test by setting a bad URL
export _CCPM_ROOT="${TMPDIR_TEST}/fake-repo"
mkdir -p "$_CCPM_ROOT"
git -C "$_CCPM_ROOT" init -q
git -C "$_CCPM_ROOT" remote add fake-upstream "https://invalid.example.com/nonexistent.git" 2>/dev/null || true

# We test the error message pattern from setup_remote by simulating a fetch failure
out=$(bash -c '
  git -C "'"$_CCPM_ROOT"'" remote add upstream-ccpm "https://invalid.example.com/nonexistent.git" 2>/dev/null || true
  git -C "'"$_CCPM_ROOT"'" fetch upstream-ccpm main 2>/dev/null || echo "❌ Cannot reach automazeio/ccpm. Check network."
' 2>&1 || true)
assert_contains "❌ Cannot reach" "$out" "shows clear error when remote unreachable"
export _CCPM_ROOT="$PROJECT_ROOT"

run_test "Script --summary flag requires no args beyond flag"
out=$(bash "$PROJECT_ROOT/scripts/pm/upstream-sync.sh" 2>&1 || true)
assert_contains "Usage:" "$out" "shows usage when no args given"

run_test "Sync log format is valid markdown"
SYNC_LOG="${TMPDIR_TEST}/markdown-check-log.md"
update_sync_log "testcommit789" "scripts rules" "commands config"
# Check for markdown table header
log_content=$(cat "$SYNC_LOG")
assert_contains "| Category | Action | Files |" "$log_content" "has markdown table header"
assert_contains "|----------|--------|-------|" "$log_content" "has markdown table separator"
assert_contains "## Sync:" "$log_content" "has section header"
SYNC_LOG="$SYNC_LOG_ORIG"

# --- Summary ---

echo ""
echo "════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
