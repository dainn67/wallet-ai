#!/usr/bin/env bash
# test-build-command.sh — Integration tests for commands/pm/build.md
set -uo pipefail

PASS=0
FAIL=0
CMD_FILE="commands/pm/build.md"

assert() {
  local desc="$1" result="$2"
  if [ "$result" = "0" ]; then
    echo "  ✅ $desc"
    ((PASS++))
  else
    echo "  ❌ $desc"
    ((FAIL++))
  fi
}

echo "=== Test: build.md command file ==="

# --- Frontmatter tests ---
echo ""
echo "--- Frontmatter ---"

test -f "$CMD_FILE"
assert "build.md exists" $?

grep -q '^name: build$' "$CMD_FILE"
assert "frontmatter: name is 'build'" $?

grep -q '^model: opus$' "$CMD_FILE"
assert "frontmatter: model is opus" $?

grep -q 'allowed-tools:.*Skill' "$CMD_FILE"
assert "frontmatter: allowed-tools includes Skill" $?

grep -q 'allowed-tools:.*Bash' "$CMD_FILE"
assert "frontmatter: allowed-tools includes Bash" $?

# --- Workflow steps ---
echo ""
echo "--- Workflow steps ---"

steps=("prd-new" "prd-qualify" "prd-parse" "plan-review" "epic-decompose" "epic-sync" "epic-start" "epic-run" "epic-verify" "epic-merge")
for step in "${steps[@]}"; do
  grep -q "$step" "$CMD_FILE"
  assert "references step: $step" $?
done

# --- State management ---
echo ""
echo "--- State management ---"

grep -q 'build-state.sh' "$CMD_FILE"
assert "references build-state.sh" $?

grep -q 'load_state' "$CMD_FILE"
assert "uses load_state function" $?

grep -q 'advance_step' "$CMD_FILE"
assert "uses advance_step function" $?

grep -q 'init_state' "$CMD_FILE"
assert "uses init_state function" $?

# --- Gate logic ---
echo ""
echo "--- Gate logic ---"

grep -q 'GATE' "$CMD_FILE"
assert "gate display format present" $?

grep -q 'proceed.*skip.*abort' "$CMD_FILE" 2>/dev/null || grep -qi 'yes.*skip.*abort' "$CMD_FILE"
assert "gate options: proceed/skip/abort" $?

grep -q '\-\-no-gate' "$CMD_FILE"
assert "--no-gate flag documented" $?

# --- Progress format ---
echo ""
echo "--- Progress format ---"

grep -q '\[.*\/10\]' "$CMD_FILE"
assert "progress format: [N/10]" $?

grep -q '▶' "$CMD_FILE"
assert "progress symbol: ▶ (running)" $?

grep -q '✅' "$CMD_FILE"
assert "progress symbol: ✅ (complete)" $?

grep -q '❌' "$CMD_FILE"
assert "progress symbol: ❌ (failed)" $?

grep -q '⏭' "$CMD_FILE"
assert "progress symbol: ⏭ (skipped)" $?

# --- prd-qualify loop ---
echo ""
echo "--- prd-qualify loop ---"

grep -q 'max_loop' "$CMD_FILE"
assert "prd-qualify loop references max_loop" $?

grep -q 'prd-edit' "$CMD_FILE"
assert "prd-qualify loop invokes prd-edit" $?

grep -q 'prd-validate' "$CMD_FILE"
assert "prd-qualify loop invokes prd-validate" $?

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
