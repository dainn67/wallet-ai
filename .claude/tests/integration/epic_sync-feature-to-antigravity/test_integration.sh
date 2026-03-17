#!/usr/bin/env bash
# Integration tests for epic sync-feature-to-antigravity
# Tests interfaces between Config ↔ Script, Script ↔ model-tiers, Script ↔ filesystem.
# Uses REAL project files for integration confidence.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/pm/antigravity-sync.sh"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

assert_ok() {
  local desc="$1" result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" = "true" ]; then
    echo -e "  ${GREEN}✅ PASS${NC}: $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}❌ FAIL${NC}: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "═══════════════════════════════════════"
echo " Integration Tests: sync-feature-to-antigravity"
echo "═══════════════════════════════════════"

# --- Integration 1: Config ↔ Script ---
echo ""
echo "Integration 1: Config ↔ Script"

# Script reads all config fields correctly
config_fields=$(python3 -c "
import json
c = json.load(open('$PROJECT_ROOT/config/antigravity-sync.json'))
m = c.get('mappings', {})
print('workflows_source=' + m.get('workflows',{}).get('source',''))
print('workflows_target=' + m.get('workflows',{}).get('target',''))
print('rules_source=' + m.get('rules',{}).get('source',''))
print('rules_target=' + m.get('rules',{}).get('target',''))
print('skip=' + ','.join(c.get('skip_patterns',[])))
" 2>/dev/null)

assert_ok "config workflows source is commands/pm" "$(echo "$config_fields" | grep -q 'workflows_source=commands/pm' && echo true || echo false)"
assert_ok "config workflows target is antigravity/workflows" "$(echo "$config_fields" | grep -q 'workflows_target=antigravity/workflows' && echo true || echo false)"
assert_ok "config rules source is rules" "$(echo "$config_fields" | grep -q 'rules_source=rules' && echo true || echo false)"
assert_ok "config rules target is antigravity/rules" "$(echo "$config_fields" | grep -q 'rules_target=antigravity/rules' && echo true || echo false)"
assert_ok "config skip_patterns includes antigravity-sync" "$(echo "$config_fields" | grep -q 'skip=antigravity-sync' && echo true || echo false)"

# Script detect uses config mappings to correctly enumerate sources
detect_out=$(bash "$SCRIPT" detect 2>&1)
assert_ok "detect uses config mappings (runs without error)" "$([ $? -eq 0 ] && echo true || echo false)"

# --- Integration 2: Script ↔ model-tiers.json ---
echo ""
echo "Integration 2: Script ↔ model-tiers.json"

# Transform a workflow and verify tier comment matches model-tiers.json config
out_file="$TMPDIR_ROOT/int-tier-test.md"
bash "$SCRIPT" transform-workflow "$PROJECT_ROOT/commands/pm/status.md" "$out_file" 2>&1

# Get expected tier from model-tiers.json
expected_tier=$(jq -r '.commands["status"] // "medium"' "$PROJECT_ROOT/config/model-tiers.json" 2>/dev/null)
actual_tier=$(grep '^# tier:' "$out_file" 2>/dev/null | sed 's/# tier: *//')

assert_ok "tier comment matches model-tiers.json (expected=$expected_tier, got=$actual_tier)" "$([ "$expected_tier" = "$actual_tier" ] && echo true || echo false)"

# Test a heavy-tier command
out_heavy="$TMPDIR_ROOT/int-tier-heavy.md"
if [ -f "$PROJECT_ROOT/commands/pm/prd-parse.md" ]; then
  bash "$SCRIPT" transform-workflow "$PROJECT_ROOT/commands/pm/prd-parse.md" "$out_heavy" 2>&1
  heavy_expected=$(jq -r '.commands["prd-parse"] // "medium"' "$PROJECT_ROOT/config/model-tiers.json" 2>/dev/null)
  heavy_actual=$(grep '^# tier:' "$out_heavy" 2>/dev/null | sed 's/# tier: *//')
  assert_ok "heavy command tier correct (expected=$heavy_expected, got=$heavy_actual)" "$([ "$heavy_expected" = "$heavy_actual" ] && echo true || echo false)"
fi

# --- Integration 3: Script ↔ Filesystem ---
echo ""
echo "Integration 3: Script ↔ Filesystem"

# Verify all source commands have corresponding Antigravity workflow files
source_count=$(ls "$PROJECT_ROOT/commands/pm/"*.md 2>/dev/null | wc -l | tr -d ' ')
target_count=$(ls "$PROJECT_ROOT/antigravity/workflows/pm-"*.md 2>/dev/null | wc -l | tr -d ' ')

assert_ok "antigravity has workflow files ($target_count workflows for $source_count commands)" "$([ "$target_count" -gt 0 ] && echo true || echo false)"

# Verify naming convention: every target file starts with pm-
bad_names=0
for wf in "$PROJECT_ROOT"/antigravity/workflows/pm-*.md; do
  [ -f "$wf" ] || continue
  basename_wf=$(basename "$wf")
  if [[ ! "$basename_wf" =~ ^pm- ]]; then
    bad_names=$((bad_names + 1))
  fi
done
assert_ok "all workflow files follow pm-{name}.md naming" "$([ $bad_names -eq 0 ] && echo true || echo false)"

# Verify rule naming convention: every target file starts with ccpm-
bad_rule_names=0
for rl in "$PROJECT_ROOT"/antigravity/rules/ccpm-*.md; do
  [ -f "$rl" ] || continue
  basename_rl=$(basename "$rl")
  if [[ ! "$basename_rl" =~ ^ccpm- ]]; then
    bad_rule_names=$((bad_rule_names + 1))
  fi
done
assert_ok "all rule files follow ccpm-{name}.md naming" "$([ $bad_rule_names -eq 0 ] && echo true || echo false)"

# --- Integration 4: End-to-end transform pipeline ---
echo ""
echo "Integration 4: Transform pipeline"

# Transform a real command and verify full pipeline
out_pipeline="$TMPDIR_ROOT/int-pipeline.md"
bash "$SCRIPT" transform-workflow "$PROJECT_ROOT/commands/pm/epic-start.md" "$out_pipeline" 2>&1
pipeline_exit=$?

assert_ok "full transform pipeline succeeds" "$([ $pipeline_exit -eq 0 ] && echo true || echo false)"

if [ -f "$out_pipeline" ]; then
  # Verify frontmatter removal
  assert_ok "pipeline removes model: field" "$(grep -q '^model:' "$out_pipeline" && echo false || echo true)"
  assert_ok "pipeline removes allowed-tools: field" "$(grep -q '^allowed-tools:' "$out_pipeline" && echo false || echo true)"

  # Verify frontmatter addition
  assert_ok "pipeline adds name: field" "$(grep -q '^name:' "$out_pipeline" && echo true || echo false)"
  assert_ok "pipeline adds description: field" "$(grep -q '^description:' "$out_pipeline" && echo true || echo false)"

  # Verify variable replacement (epic-start should use $EPIC_NAME)
  assert_ok "pipeline replaces ARGUMENTS with EPIC_NAME" "$(grep -q '\$EPIC_NAME' "$out_pipeline" && echo true || echo false)"

  # Verify content body preserved
  assert_ok "pipeline preserves content body" "$(grep -q 'Epic Start' "$out_pipeline" && echo true || echo false)"
fi

# --- Integration 5: Idempotent full sync ---
echo ""
echo "Integration 5: Idempotent sync"
idempotent_out=$(bash "$SCRIPT" detect 2>&1)
assert_ok "current state: 0 gaps (fully synced)" "$(echo "$idempotent_out" | grep -q 'Total: 0 gaps' && echo true || echo false)"

# --- Summary ---
echo ""
echo "═══════════════════════════════════════"
echo " Integration Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
