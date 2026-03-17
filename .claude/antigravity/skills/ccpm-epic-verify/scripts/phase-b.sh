#!/usr/bin/env bash
# ccpm-epic-verify: phase-b.sh
#
# Runs integration verification (Phase B) — the Ralph loop.
# Checks for epic-verify.sh, falls back to generic profiles if missing.
# Outputs PASS/FAIL with iteration status.
# Always exits 0 — advisory only.

set -uo pipefail

CONTEXT_DIR=".claude/context"
CONFIG_DIR=".claude/config"
EPIC_VERIFY_SCRIPT="$CONTEXT_DIR/verify/epic-verify.sh"
EPIC_VERIFY_CONFIG="$CONFIG_DIR/epic-verify.json"
GENERIC_PROFILES_DIR="$CONTEXT_DIR/verify/profiles"

# --- Read MAX_ITERATIONS from config ---

MAX_ITERATIONS=30

if [ -f "$EPIC_VERIFY_CONFIG" ]; then
  if command -v python3 >/dev/null 2>&1; then
    CONFIG_MAX=$(python3 -c "
import json, sys
try:
    with open('$EPIC_VERIFY_CONFIG') as f:
        c = json.load(f)
    print(c.get('phase_b', {}).get('max_iterations', 30))
except Exception:
    print(30)
" 2>/dev/null)
    if [ -n "$CONFIG_MAX" ] && [ "$CONFIG_MAX" -eq "$CONFIG_MAX" ] 2>/dev/null; then
      MAX_ITERATIONS="$CONFIG_MAX"
    fi
  elif command -v jq >/dev/null 2>&1; then
    CONFIG_MAX=$(jq -r '.phase_b.max_iterations // 30' "$EPIC_VERIFY_CONFIG" 2>/dev/null || echo "30")
    MAX_ITERATIONS="$CONFIG_MAX"
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  PHASE B: INTEGRATION VERIFICATION"
echo "  Max iterations: $MAX_ITERATIONS"
echo "═══════════════════════════════════════════════════════"
echo ""

# --- Check for epic-verify.sh ---

echo "## Verification Script"
echo ""

if [ -f "$EPIC_VERIFY_SCRIPT" ]; then
  echo "Found: $EPIC_VERIFY_SCRIPT"
  echo ""
  echo "Running epic verification..."
  echo ""

  # Run and capture output + exit code
  set +e
  VERIFY_OUTPUT=$(bash "$EPIC_VERIFY_SCRIPT" 2>&1)
  VERIFY_EXIT=$?
  set -e

  echo "$VERIFY_OUTPUT"
  echo ""

  if [ "$VERIFY_EXIT" -eq 0 ]; then
    echo "═══════════════════════════════════════════════════════"
    echo "  RESULT: PASS"
    echo "  All verification checks passed."
    echo "═══════════════════════════════════════════════════════"
  else
    echo "═══════════════════════════════════════════════════════"
    echo "  RESULT: FAIL (exit code: $VERIFY_EXIT)"
    echo "═══════════════════════════════════════════════════════"
  fi

else
  echo "⚠️  No epic-verify.sh found at $EPIC_VERIFY_SCRIPT"
  echo "    Checking for generic profiles..."
  echo ""

  # --- Fall back to generic profiles ---

  if [ -d "$GENERIC_PROFILES_DIR" ]; then
    PROFILES=$(find "$GENERIC_PROFILES_DIR" -name "*.sh" -type f 2>/dev/null | sort)
    if [ -n "$PROFILES" ]; then
      echo "Found generic profiles:"
      echo "$PROFILES" | while read -r profile; do
        echo "  - $profile"
      done
      echo ""

      OVERALL_PASS=true
      echo "Running generic profiles..."
      echo ""

      echo "$PROFILES" | while read -r profile; do
        profile_name=$(basename "$profile" .sh)
        echo "### Profile: $profile_name"
        set +e
        bash "$profile" 2>&1
        PROFILE_EXIT=$?
        set -e
        if [ "$PROFILE_EXIT" -ne 0 ]; then
          echo "❌ Profile $profile_name: FAIL (exit code: $PROFILE_EXIT)"
        else
          echo "✅ Profile $profile_name: PASS"
        fi
        echo ""
      done
    else
      echo "⚠️  No generic profiles found in $GENERIC_PROFILES_DIR"
    fi
  else
    echo "⚠️  No generic profiles directory found at $GENERIC_PROFILES_DIR"
    echo ""
    echo "    Cannot run integration verification — no verification script or profiles available."
    echo "    Create $EPIC_VERIFY_SCRIPT to enable epic verification."
  fi
fi

echo ""

# --- Ralph Loop Instructions ---

echo "═══════════════════════════════════════════════════════"
echo "  RALPH LOOP INSTRUCTIONS"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "If the result above shows FAIL:"
echo ""
echo "  1. Read the failing test output carefully"
echo "  2. Identify the root cause"
echo "  3. Fix the issue in the relevant source files"
echo "  4. Re-run this script: phase-b.sh"
echo "  5. Repeat until PASS or max iterations ($MAX_ITERATIONS) reached"
echo ""
echo "4-tier test sequence (in order):"
echo "  1. Smoke tests       — basic connectivity and startup"
echo "  2. Integration tests — component interaction"
echo "  3. Regression tests  — previously passing behavior"
echo "  4. Performance tests — latency and throughput thresholds"
echo ""
echo "If max iterations ($MAX_ITERATIONS) reached without PASS:"
echo "  → Result: EPIC_BLOCKED"
echo "  → Create GitHub issues for remaining failures"
echo "  → Discuss with team before proceeding to merge"
echo ""

exit 0
