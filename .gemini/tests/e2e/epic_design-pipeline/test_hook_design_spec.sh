#!/usr/bin/env bash
# Tests for pre-task.sh design spec integration (Issue #124)
# Validates Design Gate advisory changes when design_spec is present/absent.
# Uses temporary directories — no mocking.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOK_SCRIPT="$PROJECT_ROOT/hooks/pre-task.sh"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert_ok() {
  local desc="$1" result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" = "true" ]; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc"
    FAIL=$((FAIL + 1))
  fi
}

setup_ccpm_root() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # Minimal CCPM structure for pre-task.sh
  mkdir -p "$tmpdir/context/handoffs"
  mkdir -p "$tmpdir/context/verify"
  mkdir -p "$tmpdir/scripts/pm"
  mkdir -p "$tmpdir/config"
  # Minimal lifecycle.json with design_gate enabled
  cat > "$tmpdir/config/lifecycle.json" <<'LJSON'
{
  "design_gate": { "enabled": true }
}
LJSON
  # Minimal lifecycle-helpers.sh with stubs
  cat > "$tmpdir/scripts/pm/lifecycle-helpers.sh" <<'HELPERS'
read_config_bool() {
  local section="$1" key="$2" default="${3:-false}"
  local _cfg="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/config/lifecycle.json"
  if command -v jq &>/dev/null && [ -f "$_cfg" ]; then
    val=$(jq -r ".$section.$key // \"$default\"" "$_cfg" 2>/dev/null)
    [ "$val" = "true" ] && return 0 || return 1
  fi
  [ "$default" = "true" ] && return 0 || return 1
}
_json_get() {
  local file="$1" query="$2"
  if command -v jq &>/dev/null; then
    jq -r "$query" "$file" 2>/dev/null
  else
    echo ""
  fi
}
detect_superpowers() { return 1; }
HELPERS
  echo "$tmpdir"
}

echo "======================================="
echo " Tests: pre-task.sh Design Spec Integration"
echo "======================================="

# --- Test 1: Task with design_spec AND spec file exists → DESIGN REFERENCE AVAILABLE ---
echo ""
echo "Test 1: Design spec exists → reference advisory"
TMPDIR_TEST=$(setup_ccpm_root)
_epic="test-epic"
_issue="42"
mkdir -p "$TMPDIR_TEST/epics/$_epic"
mkdir -p "$TMPDIR_TEST/designs/$_epic/specs"
# Create spec file
echo "# Dashboard Spec" > "$TMPDIR_TEST/designs/$_epic/specs/dashboard-spec.md"
# Create task file with design_spec
cat > "$TMPDIR_TEST/epics/$_epic/${_issue}.md" <<EOF
---
name: Implement dashboard
status: open
design_spec: $TMPDIR_TEST/designs/$_epic/specs/dashboard-spec.md
---
# Task
EOF
# Create verify state that triggers Design Gate
cat > "$TMPDIR_TEST/context/verify/state.json" <<SJSON
{
  "active_task": {
    "type": "FEATURE",
    "epic": "$_epic",
    "issue_number": "$_issue"
  }
}
SJSON
output=$(bash "$HOOK_SCRIPT" "$TMPDIR_TEST" 2>&1)
has_ref=$(echo "$output" | grep -c "DESIGN REFERENCE AVAILABLE" || true)
has_spec_path=$(echo "$output" | grep -c "Read design spec at:" || true)
assert_ok "Output contains DESIGN REFERENCE AVAILABLE" "$([ "$has_ref" -ge 1 ] && echo true || echo false)"
assert_ok "Output contains spec path" "$([ "$has_spec_path" -ge 1 ] && echo true || echo false)"
# Should NOT contain "create a design file"
has_create=$(echo "$output" | grep -c "create a design file" || true)
assert_ok "Output does NOT contain 'create a design file'" "$([ "$has_create" -eq 0 ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 2: Task WITHOUT design_spec → original advisory ---
echo ""
echo "Test 2: No design_spec → original advisory"
TMPDIR_TEST=$(setup_ccpm_root)
_epic="test-epic"
_issue="43"
mkdir -p "$TMPDIR_TEST/epics/$_epic"
# Task without design_spec
cat > "$TMPDIR_TEST/epics/$_epic/${_issue}.md" <<EOF
---
name: Implement feature
status: open
---
# Task
EOF
cat > "$TMPDIR_TEST/context/verify/state.json" <<SJSON
{
  "active_task": {
    "type": "FEATURE",
    "epic": "$_epic",
    "issue_number": "$_issue"
  }
}
SJSON
output=$(bash "$HOOK_SCRIPT" "$TMPDIR_TEST" 2>&1)
has_create=$(echo "$output" | grep -c "create a design file" || true)
assert_ok "Output contains 'create a design file'" "$([ "$has_create" -ge 1 ] && echo true || echo false)"
has_ref=$(echo "$output" | grep -c "DESIGN REFERENCE AVAILABLE" || true)
assert_ok "Output does NOT contain DESIGN REFERENCE AVAILABLE" "$([ "$has_ref" -eq 0 ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Test 3: Task with design_spec pointing to non-existent file → falls back to original ---
echo ""
echo "Test 3: design_spec points to missing file → fallback"
TMPDIR_TEST=$(setup_ccpm_root)
_epic="test-epic"
_issue="44"
mkdir -p "$TMPDIR_TEST/epics/$_epic"
cat > "$TMPDIR_TEST/epics/$_epic/${_issue}.md" <<EOF
---
name: Implement screen
status: open
design_spec: $TMPDIR_TEST/designs/nonexistent/specs/missing-spec.md
---
# Task
EOF
cat > "$TMPDIR_TEST/context/verify/state.json" <<SJSON
{
  "active_task": {
    "type": "FEATURE",
    "epic": "$_epic",
    "issue_number": "$_issue"
  }
}
SJSON
output=$(bash "$HOOK_SCRIPT" "$TMPDIR_TEST" 2>&1)
has_create=$(echo "$output" | grep -c "create a design file" || true)
assert_ok "Fallback: output contains 'create a design file'" "$([ "$has_create" -ge 1 ] && echo true || echo false)"
has_ref=$(echo "$output" | grep -c "DESIGN REFERENCE AVAILABLE" || true)
assert_ok "Fallback: output does NOT contain DESIGN REFERENCE AVAILABLE" "$([ "$has_ref" -eq 0 ] && echo true || echo false)"
rm -rf "$TMPDIR_TEST"

# --- Summary ---
echo ""
echo "======================================="
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
