#!/bin/bash
# CCPM Verification Profile: Generic
set -o pipefail

FAIL=0
PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

echo "═══ CCPM Verify: Generic ═══"
echo ""

# Step 1: Check for uncommitted changes that might indicate incomplete work
echo "── Step 1: Git State ──"
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNTRACKED" -gt 0 ]; then
    echo "⚠️ $UNTRACKED untracked files found"
    git ls-files --others --exclude-standard 2>/dev/null | head -10
fi
echo "✅ Git: State checked"

# Step 2: Look for common error indicators
echo ""
echo "── Step 2: Error Pattern Scan ──"
ERROR_PATTERNS="TODO:|FIXME:|HACK:|XXX:|BUG:|BROKEN:"
FOUND=$(grep -rn "$ERROR_PATTERNS" --include="*.py" --include="*.ts" \
  --include="*.js" --include="*.swift" --include="*.rs" --include="*.go" \
  . 2>/dev/null | grep -v "node_modules" | grep -v ".venv" | head -20)
if [ -n "$FOUND" ]; then
    echo "⚠️ Found TODO/FIXME markers:"
    echo "$FOUND"
else
    echo "✅ No TODO/FIXME markers found"
fi

# Step 3: Try to detect and run project test command
echo ""
echo "── Step 3: Auto-detect Test Runner ──"
if [ -f "Makefile" ] && grep -q "^test:" Makefile; then
    echo "Running: make test"
    if make test 2>&1; then
        echo "✅ Tests: Passed"
    else
        echo "❌ Tests: Failed"
        FAIL=1
    fi
elif [ -f "justfile" ] && grep -q "^test:" justfile 2>/dev/null; then
    echo "Running: just test"
    if just test 2>&1; then
        echo "✅ Tests: Passed"
    else
        echo "❌ Tests: Failed"
        FAIL=1
    fi
else
    echo "⏭️ Tests: No test runner detected, skipping"
fi

echo ""
echo "═══════════════════════════"
if [ $FAIL -eq 0 ]; then
    echo "VERIFY_PASS"
    exit 0
else
    echo "VERIFY_FAIL: One or more checks failed."
    exit 1
fi
