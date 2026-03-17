#!/usr/bin/env bash
# ccpm-verification: ralph-loop.sh
#
# Outputs the Ralph loop protocol for Claude to follow.
# Advisory only — exits 0 always.
#
# Usage: ralph-loop.sh [MAX_ITERATIONS]

set -uo pipefail

VERIFY_STATE=".claude/context/verify/state.json"

MAX_ITERATIONS="${1:-20}"
CURRENT_ITERATION=0

if [ -f "$VERIFY_STATE" ] && command -v jq >/dev/null 2>&1; then
  CURRENT_ITERATION=$(jq -r '.active_task.current_iteration // 0' "$VERIFY_STATE" 2>/dev/null || echo "0")
  STORED_MAX=$(jq -r '.active_task.max_iterations // 0' "$VERIFY_STATE" 2>/dev/null || echo "0")
  if [ "$STORED_MAX" -gt 0 ] && [ "${1:-}" = "" ]; then
    MAX_ITERATIONS="$STORED_MAX"
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CCPM RALPH LOOP"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Current iteration: $CURRENT_ITERATION / $MAX_ITERATIONS"
echo ""

# --- Check max iterations ---

if [ "$CURRENT_ITERATION" -ge "$MAX_ITERATIONS" ]; then
  echo "❌ Max iterations ($MAX_ITERATIONS) reached."
  echo ""
  echo "→ Escalate: Stop the loop and report to the user."
  echo "  The issue cannot be resolved automatically after $MAX_ITERATIONS attempts."
  echo "  Human review required."
  echo ""
  exit 0
fi

# --- Output Ralph loop protocol ---

NEXT_ITERATION=$((CURRENT_ITERATION + 1))

echo "Iteration $NEXT_ITERATION / $MAX_ITERATIONS — Ralph loop protocol:"
echo ""
echo "  1. Run verification:"
echo "     antigravity/skills/ccpm-verification/scripts/run-verify.sh"
echo ""
echo "  2. If PASS → exit loop, proceed to semantic review."
echo ""
echo "  3. If FAIL → fix the failing issue:"
echo "     - Read the error output carefully"
echo "     - Identify the root cause"
echo "     - Make the minimal fix"
echo "     - Do NOT change unrelated code"
echo ""
echo "  4. After fixing → return to step 1 (run verify again)."
echo ""
echo "  5. If iteration reaches $MAX_ITERATIONS → escalate."
echo ""
echo "───────────────────────────────────────────────────────"
echo "  Follow this loop until PASS or max iterations."
echo "───────────────────────────────────────────────────────"
echo ""

exit 0
