#!/usr/bin/env bash
# ccpm-context-loader: load-context.sh
#
# Reads handoff notes, verify state, and epic context from .gemini/context/
# Outputs a formatted summary to stdout.
# Always exits 0 — never crashes.

set -uo pipefail

CONTEXT_DIR=".gemini/context"
HANDOFF_FILE="$CONTEXT_DIR/handoffs/latest.md"
VERIFY_STATE="$CONTEXT_DIR/verify/state.json"
EPICS_DIR="$CONTEXT_DIR/epics"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CCPM CONTEXT LOADER"
echo "═══════════════════════════════════════════════════════"
echo ""

# --- Handoff Notes ---

echo "## Handoff Notes"
echo ""

if [ -f "$HANDOFF_FILE" ]; then
  echo "Found: $HANDOFF_FILE"
  echo ""
  cat "$HANDOFF_FILE" 2>/dev/null || echo "⚠️  Could not read handoff file."
else
  echo "⚠️  No handoff found at $HANDOFF_FILE — this may be a fresh start."
fi

echo ""

# --- Verify State ---

echo "## Verify State"
echo ""

if [ -f "$VERIFY_STATE" ]; then
  echo "Found: $VERIFY_STATE"
  echo ""
  # Show key fields if jq is available, else show raw
  if command -v jq >/dev/null 2>&1; then
    status=$(jq -r '.status // "unknown"' "$VERIFY_STATE" 2>/dev/null || echo "unknown")
    iterations=$(jq -r '.iterations // 0' "$VERIFY_STATE" 2>/dev/null || echo "0")
    active_task=$(jq -r '.active_task.issue_number // "none"' "$VERIFY_STATE" 2>/dev/null || echo "none")
    echo "  Status:      $status"
    echo "  Iterations:  $iterations"
    echo "  Active task: #$active_task"
  else
    cat "$VERIFY_STATE" 2>/dev/null || echo "⚠️  Could not read verify state."
  fi
else
  echo "⚠️  No verify state found at $VERIFY_STATE — verification not yet run."
fi

echo ""

# --- Epic Context ---

echo "## Epic Context"
echo ""

if [ -d "$EPICS_DIR" ]; then
  # Find first .md file in epics dir
  epic_file=$(find "$EPICS_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | head -1)
  if [ -n "$epic_file" ]; then
    echo "Found: $epic_file"
    echo ""
    cat "$epic_file" 2>/dev/null || echo "⚠️  Could not read epic context file."
  else
    echo "⚠️  No epic context files found in $EPICS_DIR"
  fi
else
  echo "⚠️  No epics directory found at $EPICS_DIR"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Context loading complete. Review above before proceeding."
echo "═══════════════════════════════════════════════════════"
echo ""

exit 0
