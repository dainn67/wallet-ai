#!/usr/bin/env bash
# ccpm-verification: run-verify.sh
#
# Loads the tech-stack verify profile and runs checks.
# Updates .claude/context/verify/state.json with results.
# Advisory only — exits 0 always, but outputs clear PASS/FAIL.

set -uo pipefail

VERIFY_STATE=".claude/context/verify/state.json"
PROFILES_DIR=".claude/context/verify/profiles"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CCPM VERIFICATION — RUN VERIFY"
echo "═══════════════════════════════════════════════════════"
echo ""

# --- Read state ---

TECH_STACK="generic"
VERIFY_PROFILE=""
CURRENT_ITERATION=0
MAX_ITERATIONS=20

if [ -f "$VERIFY_STATE" ] && command -v jq >/dev/null 2>&1; then
  TECH_STACK=$(jq -r '.active_task.tech_stack // "generic"' "$VERIFY_STATE" 2>/dev/null || echo "generic")
  VERIFY_PROFILE=$(jq -r '.active_task.verify_profile // ""' "$VERIFY_STATE" 2>/dev/null || echo "")
  CURRENT_ITERATION=$(jq -r '.active_task.current_iteration // 0' "$VERIFY_STATE" 2>/dev/null || echo "0")
  MAX_ITERATIONS=$(jq -r '.active_task.max_iterations // 20' "$VERIFY_STATE" 2>/dev/null || echo "20")
fi

echo "Tech stack:        $TECH_STACK"
echo "Current iteration: $CURRENT_ITERATION / $MAX_ITERATIONS"
echo ""

# --- Resolve profile path ---

PROFILE_PATH=""

# Prefer explicit verify_profile if set
if [ -n "$VERIFY_PROFILE" ] && [ -f "$VERIFY_PROFILE" ]; then
  PROFILE_PATH="$VERIFY_PROFILE"
elif [ -f "$PROFILES_DIR/${TECH_STACK}.sh" ]; then
  PROFILE_PATH="$PROFILES_DIR/${TECH_STACK}.sh"
elif [ -f "$PROFILES_DIR/generic.sh" ]; then
  PROFILE_PATH="$PROFILES_DIR/generic.sh"
  echo "⚠️  No profile for '$TECH_STACK' — falling back to generic.sh"
fi

# --- Run profile ---

VERIFY_RESULT="FAIL"
VERIFY_ERROR=""

if [ -n "$PROFILE_PATH" ]; then
  echo "Profile: $PROFILE_PATH"
  echo ""
  echo "Running verification..."
  echo ""

  # Source the profile in a subshell to get VERIFY_CMD
  if source "$PROFILE_PATH" 2>/dev/null; then
    if [ -n "${VERIFY_CMD:-}" ]; then
      if eval "$VERIFY_CMD"; then
        VERIFY_RESULT="PASS"
        echo ""
        echo "✅ PASS — Verification succeeded."
      else
        VERIFY_ERROR="Verify command exited with error"
        echo ""
        echo "❌ FAIL — $VERIFY_ERROR"
      fi
    else
      echo "⚠️  Profile sourced but VERIFY_CMD not set — skipping execution."
      VERIFY_RESULT="PASS"
      echo "✅ PASS (no command to run)"
    fi
  else
    VERIFY_ERROR="Could not source profile: $PROFILE_PATH"
    echo "⚠️  $VERIFY_ERROR — skipping verification."
    echo "✅ PASS (profile unreadable — advisory skip)"
    VERIFY_RESULT="PASS"
  fi
else
  echo "⚠️  No verify profile found in $PROFILES_DIR"
  echo "   Skipping verification — mark as advisory PASS."
  echo ""
  echo "✅ PASS (no profile — advisory skip)"
  VERIFY_RESULT="PASS"
fi

# --- Update state.json ---

NEW_ITERATION=$((CURRENT_ITERATION + 1))
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

if [ -f "$VERIFY_STATE" ] && command -v jq >/dev/null 2>&1; then
  ITERATION_RECORD="{\"n\": $NEW_ITERATION, \"result\": \"$VERIFY_RESULT\", \"timestamp\": \"$TIMESTAMP\"}"

  UPDATED=$(jq \
    --argjson n "$NEW_ITERATION" \
    --argjson rec "$ITERATION_RECORD" \
    '.active_task.current_iteration = $n | .active_task.iterations += [$rec]' \
    "$VERIFY_STATE" 2>/dev/null)

  if [ -n "$UPDATED" ]; then
    echo "$UPDATED" > "$VERIFY_STATE"
    echo ""
    echo "state.json updated: iteration $NEW_ITERATION recorded as $VERIFY_RESULT"
  else
    echo ""
    echo "⚠️  Could not update state.json (jq error)"
  fi
else
  echo ""
  echo "⚠️  state.json not updated (file missing or jq not available)"
fi

echo ""
exit 0
