#!/usr/bin/env bash
# ccpm-pre-implementation: check-tests.sh
#
# Checks if test files exist for the current task.
# For FEATURE tasks (or unknown type), test stubs are required.
# Advisory only — exits 0 always.
#
# Usage: check-tests.sh [EPIC] [TASK_N]
# If not provided, reads from .claude/context/verify/state.json

set -uo pipefail

VERIFY_STATE=".claude/context/verify/state.json"

# --- Resolve task type ---

TASK_TYPE="FEATURE"  # default

if [ -f "$VERIFY_STATE" ] && command -v jq >/dev/null 2>&1; then
  TASK_TYPE=$(jq -r '.active_task.type // "FEATURE"' "$VERIFY_STATE" 2>/dev/null || echo "FEATURE")
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CCPM TEST GATE CHECK"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Task type: $TASK_TYPE"
echo ""

# --- Only enforce for FEATURE (or unknown) ---

if [ "$TASK_TYPE" != "FEATURE" ] && [ "$TASK_TYPE" != "UNKNOWN" ] && [ -n "$TASK_TYPE" ]; then
  echo "ℹ️  Task type is $TASK_TYPE — test gate not required."
  echo ""
  exit 0
fi

# --- Search for test files ---

TEST_COUNT=0

if command -v find >/dev/null 2>&1; then
  # Patterns: *.test.*, *_test.*, *.spec.*, test_*.py, test_*.sh
  TEST_COUNT=$(find . \
    \( -path './.git' -o -path './.venv' -o -path './node_modules' \) -prune \
    -o \( \
      -name '*.test.*' \
      -o -name '*_test.*' \
      -o -name '*.spec.*' \
      -o -name 'test_*.py' \
      -o -name 'test_*.sh' \
    \) -type f -print 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$TEST_COUNT" -gt 0 ]; then
  echo "✅ Test files found: $TEST_COUNT files"
else
  echo "❌ No test files found for FEATURE task"
  echo ""
  echo "→ Write test stubs before implementing. Tests should cover acceptance criteria."
  echo "   Supported patterns: *.test.*, *_test.*, *.spec.*, test_*.py, test_*.sh"
fi

echo ""
exit 0
