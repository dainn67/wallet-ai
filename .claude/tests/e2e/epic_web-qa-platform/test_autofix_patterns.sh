#!/usr/bin/env bash
# Test: Auto-Fix Pipeline patterns in web QA prompt
# Task: #210

set -uo pipefail

PROMPT="prompts/web-qa-agent-prompt.md"
CONFIG="config/web-qa.json"
PASS=0
FAIL=0

assert() {
  local desc="$1" pattern="$2" file="$3"
  if grep -q "$pattern" "$file"; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — pattern '$pattern' not found in $file"
    FAIL=$((FAIL + 1))
  fi
}

# --- Prompt content tests ---

assert "Prompt contains auto-fix section" "Auto-Fix Pipeline" "$PROMPT"
assert "Prompt contains WTF heuristic" "WTF" "$PROMPT"
assert "Prompt contains git revert flow" "git revert" "$PROMPT"
assert "Prompt contains auto-fix keyword" "auto-fix" "$PROMPT"

# 5 fixable patterns
assert "Pattern 1: Console TypeError/ReferenceError" "TypeError/ReferenceError" "$PROMPT"
assert "Pattern 2: Broken internal link" "Broken internal link" "$PROMPT"
assert "Pattern 3: Missing alt text" "Missing alt text" "$PROMPT"
assert "Pattern 4: Missing form label" "Missing form label" "$PROMPT"
assert "Pattern 5: Uncaught promise rejection" "Uncaught promise rejection" "$PROMPT"

# WTF base values
assert "WTF base 10% for console errors" "| 1 | Console TypeError" "$PROMPT"
assert "WTF base 5% for broken links" "| 2 | Broken internal link | 5%" "$PROMPT"
assert "WTF base 25% for promise rejection" "| 5 | Uncaught promise rejection | 25%" "$PROMPT"

# WTF multipliers
assert "WTF multiplier: >3 files" "affected_files > 3" "$PROMPT"
assert "WTF multiplier: unfamiliar file type" "unfamiliar_file_type" "$PROMPT"
assert "WTF multiplier: no test coverage" "no_test_coverage" "$PROMPT"

# Threshold reference
assert "Prompt references wtf_threshold from config" "wtf_threshold" "$PROMPT"
assert "Prompt references max_fixes from config" "max_fixes" "$PROMPT"

# Fix-verify-commit flow
assert "Prompt has atomic commit pattern" 'QA auto-fix:' "$PROMPT"
assert "Prompt has deferred logging" "deferred" "$PROMPT"
assert "Prompt has reverted logging" "reverted" "$PROMPT"

# Reporting table
assert "Report table has Issue column" "| Issue |" "$PROMPT"
assert "Report table has WTF% column" "| WTF% |" "$PROMPT"
assert "Report table has Action column" "| Action |" "$PROMPT"
assert "Report table has Status column" "| Status |" "$PROMPT"

# Edge cases
assert "Edge case: minified files" "minified" "$PROMPT"
assert "Edge case: node_modules" "node_modules" "$PROMPT"

# --- Config tests ---

assert "Config has wtf_threshold" "wtf_threshold" "$CONFIG"
assert "Config has max_fixes" "max_fixes" "$CONFIG"

# Check wtf_threshold value is 20
if python3 -c "import json; d=json.load(open('$CONFIG')); assert d['auto_fix']['wtf_threshold']==20" 2>/dev/null; then
  echo "PASS: wtf_threshold defaults to 20"
  PASS=$((PASS + 1))
else
  echo "FAIL: wtf_threshold should be 20"
  FAIL=$((FAIL + 1))
fi

# Check max_fixes value is 5
if python3 -c "import json; d=json.load(open('$CONFIG')); assert d['auto_fix']['max_fixes']==5" 2>/dev/null; then
  echo "PASS: max_fixes defaults to 5"
  PASS=$((PASS + 1))
else
  echo "FAIL: max_fixes should be 5"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
