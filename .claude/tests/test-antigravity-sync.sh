#!/usr/bin/env bash
# Tests: antigravity-sync.sh (Issue #106)
# Validates detect_gaps, transform_workflow, transform_rule, and sync functions.
# Uses a temp directory with fixture files — does NOT modify real project files.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/pm/antigravity-sync.sh"

PASS=0
FAIL=0
TOTAL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# --- Assert helpers ---

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" -eq "$actual" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc (expected=$expected, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" output="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$output" | grep -q "$pattern"; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc — pattern not found: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" output="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if ! echo "$output" | grep -q "$pattern"; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc — pattern should NOT be present: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  TOTAL=$((TOTAL + 1))
  if [ -e "$path" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc — not found: $path"
    FAIL=$((FAIL + 1))
  fi
}

# --- Fixture setup ---

TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# Create a fake project structure for isolated testing
setup_fixtures() {
  local root="$TMPDIR_ROOT/project"
  rm -rf "$root"
  mkdir -p "$root/commands/pm"
  mkdir -p "$root/rules"
  mkdir -p "$root/antigravity/workflows"
  mkdir -p "$root/antigravity/rules"
  mkdir -p "$root/config"

  # Config file
  cat > "$root/config/antigravity-sync.json" << 'CONF'
{
  "mappings": {
    "rules": {
      "source": "rules",
      "target": "antigravity/rules",
      "naming": "ccpm-{name}.md",
      "transform": "rule"
    },
    "workflows": {
      "source": "commands/pm",
      "target": "antigravity/workflows",
      "naming": "pm-{name}.md",
      "transform": "workflow"
    }
  },
  "frontmatter": {
    "remove_fields": ["model", "allowed-tools"],
    "add_fields": {
      "name": "pm-{filename}",
      "description": "{first_heading_or_summary}"
    },
    "tier_comment": true
  },
  "variable_map": {
    "epic-*": "$EPIC_NAME",
    "issue-*": "$ISSUE_NUMBER",
    "prd-*": "$FEATURE_NAME",
    "default": "$ARGUMENTS"
  },
  "skip_patterns": [
    "antigravity-sync"
  ]
}
CONF

  # Model tiers config
  cat > "$root/config/model-tiers.json" << 'TIERS'
{
  "commands": {
    "status": "light",
    "epic-start": "medium",
    "prd-parse": "heavy"
  }
}
TIERS

  # Source command files
  cat > "$root/commands/pm/status.md" << 'CMD'
---
model: sonnet
allowed-tools: Bash, Read
---

# Project Status

Show current project status.

Run `bash .claude/scripts/pm/status.sh` and display the output to the user.
CMD

  cat > "$root/commands/pm/epic-start.md" << 'CMD'
---
model: opus
allowed-tools: Bash, Read, Write, Glob
---

# Epic Start

Start working on epic `$ARGUMENTS`.

## Instructions
1. Read epic from `.claude/epics/$ARGUMENTS/epic.md`
2. Create branch `epic/$ARGUMENTS`
CMD

  cat > "$root/commands/pm/antigravity-sync.md" << 'CMD'
---
model: sonnet
allowed-tools: Bash, Read
---

# Antigravity Sync

This should be skipped.
CMD

  # Source rule files
  cat > "$root/rules/frontmatter.md" << 'RULE'
# Frontmatter

Always use ISO 8601 UTC format for dates.
RULE

  cat > "$root/rules/git-workflows.md" << 'RULE'
# Git Workflows

One branch per epic.
RULE

  echo "$root"
}

# ═══════════════════════════════════════
# TEST SUITE 1: detect_gaps
# ═══════════════════════════════════════

test_detect_gaps() {
  echo ""
  echo "═══ Test Suite 1: detect_gaps ═══"

  local root
  root=$(setup_fixtures)

  # Test 1.1: Detect missing workflows and rules
  echo ""
  echo "Test 1.1: Detect all missing files"
  local output
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" detect 2>&1)
  local exit_code=$?

  assert_exit "detect exits 0" 0 "$exit_code"
  assert_contains "reports missing workflows" "$output" "workflows:.*missing"
  assert_contains "reports missing rules" "$output" "rules:.*missing"
  assert_contains "shows total gaps" "$output" "Total:.*gaps"

  # Test 1.2: Skip pattern works (antigravity-sync should be excluded)
  echo ""
  echo "Test 1.2: Skip patterns exclude antigravity-sync"
  assert_not_contains "antigravity-sync excluded from output" "$output" "antigravity-sync"

  # Test 1.3: Detect reports correct count (2 workflows: status + epic-start, antigravity-sync skipped)
  echo ""
  echo "Test 1.3: Correct gap count"
  assert_contains "2 workflows missing" "$output" "workflows: 2 missing"
  assert_contains "2 rules missing" "$output" "rules: 2 missing"

  # Test 1.4: After syncing, gaps = 0
  echo ""
  echo "Test 1.4: Zero gaps after files exist"
  # Sync files properly (touch creates empty files which detect marks as outdated)
  _CCPM_ROOT="$root" bash "$SCRIPT" sync >/dev/null 2>&1

  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" detect 2>&1)
  assert_contains "reports zero gaps" "$output" "Total: 0 gaps"
}

# ═══════════════════════════════════════
# TEST SUITE 2: transform_workflow
# ═══════════════════════════════════════

test_transform_workflow() {
  echo ""
  echo "═══ Test Suite 2: transform_workflow ═══"

  local root
  root=$(setup_fixtures)
  local out_file="$TMPDIR_ROOT/out-workflow.md"

  # Test 2.1: Basic transform
  echo ""
  echo "Test 2.1: Transform status.md"
  local output
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" transform-workflow "$root/commands/pm/status.md" "$out_file" 2>&1)
  local exit_code=$?

  assert_exit "transform exits 0" 0 "$exit_code"
  assert_file_exists "output file created" "$out_file"

  local content
  content=$(cat "$out_file")

  # Test 2.2: Frontmatter has name field
  echo ""
  echo "Test 2.2: Frontmatter fields"
  assert_contains "has name: field" "$content" "^name: pm-status"
  assert_contains "has description: field" "$content" "^description:"

  # Test 2.3: Frontmatter does NOT have model/allowed-tools
  echo ""
  echo "Test 2.3: Removed fields"
  assert_not_contains "no model: field" "$content" "^model:"
  assert_not_contains "no allowed-tools: field" "$content" "^allowed-tools:"

  # Test 2.4: Tier comment present
  echo ""
  echo "Test 2.4: Tier comment"
  assert_contains "has tier comment" "$content" "^# tier: light"

  # Test 2.5: Content body preserved
  echo ""
  echo "Test 2.5: Content preserved"
  assert_contains "body has original content" "$content" "Show current project status"
  assert_contains "body has script reference" "$content" "status.sh"

  # Test 2.6: Variable replacement for epic-* commands
  echo ""
  echo "Test 2.6: Variable replacement"
  local out_epic="$TMPDIR_ROOT/out-epic-start.md"
  _CCPM_ROOT="$root" bash "$SCRIPT" transform-workflow "$root/commands/pm/epic-start.md" "$out_epic" 2>&1
  local epic_content
  epic_content=$(cat "$out_epic")

  assert_contains "ARGUMENTS replaced with EPIC_NAME" "$epic_content" '\$EPIC_NAME'
  assert_not_contains "no raw ARGUMENTS in epic command" "$epic_content" '\$ARGUMENTS'

  # Test 2.7: Tier for epic-start = medium
  echo ""
  echo "Test 2.7: Correct tier for epic-start"
  assert_contains "epic-start has medium tier" "$epic_content" "^# tier: medium"

  # Test 2.8: Missing source file
  echo ""
  echo "Test 2.8: Missing source file"
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" transform-workflow "/nonexistent/file.md" "$TMPDIR_ROOT/nope.md" 2>&1)
  exit_code=$?
  assert_exit "missing source exits 1" 1 "$exit_code"
}

# ═══════════════════════════════════════
# TEST SUITE 3: transform_rule
# ═══════════════════════════════════════

test_transform_rule() {
  echo ""
  echo "═══ Test Suite 3: transform_rule ═══"

  local root
  root=$(setup_fixtures)
  local out_file="$TMPDIR_ROOT/out-rule.md"

  # Test 3.1: Basic rule transform
  echo ""
  echo "Test 3.1: Transform frontmatter.md"
  local output
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" transform-rule "$root/rules/frontmatter.md" "$out_file" 2>&1)
  local exit_code=$?

  assert_exit "transform exits 0" 0 "$exit_code"
  assert_file_exists "output file created" "$out_file"

  # Test 3.2: Content preserved byte-for-byte
  echo ""
  echo "Test 3.2: Content preserved"
  local diff_result
  diff_result=$(diff "$root/rules/frontmatter.md" "$out_file" 2>&1)
  TOTAL=$((TOTAL + 1))
  if [ -z "$diff_result" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: content byte-for-byte identical"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: content differs"
    FAIL=$((FAIL + 1))
  fi

  # Test 3.3: Idempotent — transform same file again, should skip
  echo ""
  echo "Test 3.3: Idempotent (skip identical)"
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" transform-rule "$root/rules/frontmatter.md" "$out_file" 2>&1)
  assert_contains "skips identical file" "$output" "Skipped.*identical"

  # Test 3.4: Missing source file
  echo ""
  echo "Test 3.4: Missing source file"
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" transform-rule "/nonexistent/file.md" "$TMPDIR_ROOT/nope.md" 2>&1)
  exit_code=$?
  assert_exit "missing source exits 1" 1 "$exit_code"
}

# ═══════════════════════════════════════
# TEST SUITE 4: sync (end-to-end)
# ═══════════════════════════════════════

test_sync_e2e() {
  echo ""
  echo "═══ Test Suite 4: sync end-to-end ═══"

  local root
  root=$(setup_fixtures)

  # Test 4.1: Sync all with --yes flag
  echo ""
  echo "Test 4.1: Full sync"
  local output
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" sync --yes 2>&1)
  local exit_code=$?

  assert_exit "sync exits 0" 0 "$exit_code"
  assert_file_exists "workflow created: pm-status.md" "$root/antigravity/workflows/pm-status.md"
  assert_file_exists "workflow created: pm-epic-start.md" "$root/antigravity/workflows/pm-epic-start.md"
  assert_file_exists "rule created: ccpm-frontmatter.md" "$root/antigravity/rules/ccpm-frontmatter.md"
  assert_file_exists "rule created: ccpm-git-workflows.md" "$root/antigravity/rules/ccpm-git-workflows.md"

  # Test 4.2: Antigravity-sync skipped
  echo ""
  echo "Test 4.2: Skip pattern applied"
  TOTAL=$((TOTAL + 1))
  if [ ! -f "$root/antigravity/workflows/pm-antigravity-sync.md" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: antigravity-sync not synced"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: antigravity-sync should not have been synced"
    FAIL=$((FAIL + 1))
  fi

  # Test 4.3: Idempotent — second sync reports 0 gaps
  echo ""
  echo "Test 4.3: Idempotent sync"
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" sync --yes 2>&1)
  assert_contains "zero gaps on re-sync" "$output" "Already in sync"

  # Test 4.4: Type filter — only workflows
  echo ""
  echo "Test 4.4: Type filter"
  root=$(setup_fixtures)  # fresh fixtures
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" sync --type workflows --yes 2>&1)
  assert_file_exists "workflow synced" "$root/antigravity/workflows/pm-status.md"
  TOTAL=$((TOTAL + 1))
  if [ ! -f "$root/antigravity/rules/ccpm-frontmatter.md" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: rules not synced with --type workflows"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: rules should NOT be synced with --type workflows"
    FAIL=$((FAIL + 1))
  fi

  # Test 4.5: Config missing → fail fast
  echo ""
  echo "Test 4.5: Missing config fails fast"
  local no_config_root="$TMPDIR_ROOT/no-config"
  mkdir -p "$no_config_root"
  output=$(_CCPM_ROOT="$no_config_root" bash "$SCRIPT" detect 2>&1)
  exit_code=$?
  assert_exit "missing config exits 1" 1 "$exit_code"
  assert_contains "error message for missing config" "$output" "Config not found"
}

# ═══════════════════════════════════════
# TEST SUITE 5: CLI interface
# ═══════════════════════════════════════

test_cli() {
  echo ""
  echo "═══ Test Suite 5: CLI interface ═══"

  local root
  root=$(setup_fixtures)

  # Test 5.1: No args shows usage
  echo ""
  echo "Test 5.1: Usage on no args"
  local output
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" 2>&1)
  local exit_code=$?
  assert_exit "no args exits 1" 1 "$exit_code"
  assert_contains "shows usage" "$output" "Usage:"

  # Test 5.2: transform-workflow requires source file arg
  echo ""
  echo "Test 5.2: transform-workflow requires args"
  output=$(_CCPM_ROOT="$root" bash "$SCRIPT" transform-workflow 2>&1)
  exit_code=$?
  assert_exit "no source exits 1" 1 "$exit_code"
  assert_contains "shows usage" "$output" "Usage:"
}

# ═══════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════

echo "═══════════════════════════════════════"
echo " antigravity-sync.sh Test Suite"
echo "═══════════════════════════════════════"

test_detect_gaps
test_transform_workflow
test_transform_rule
test_sync_e2e
test_cli

echo ""
echo "═══════════════════════════════════════"
echo " Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
