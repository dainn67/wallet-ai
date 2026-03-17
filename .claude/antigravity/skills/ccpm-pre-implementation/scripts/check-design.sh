#!/usr/bin/env bash
# ccpm-pre-implementation: check-design.sh
#
# Checks if the design file exists for the current task.
# Advisory only — exits 0 always.
#
# Usage: check-design.sh [EPIC] [TASK_N]
# If not provided, reads from .claude/context/verify/state.json

set -uo pipefail

VERIFY_STATE=".claude/context/verify/state.json"

# --- Resolve EPIC and TASK_N ---

EPIC="${1:-}"
TASK_N="${2:-}"

if [ -z "$EPIC" ] || [ -z "$TASK_N" ]; then
  if [ -f "$VERIFY_STATE" ] && command -v jq >/dev/null 2>&1; then
    EPIC=$(jq -r '.active_task.epic // ""' "$VERIFY_STATE" 2>/dev/null || echo "")
    TASK_N=$(jq -r '.active_task.issue_number // ""' "$VERIFY_STATE" 2>/dev/null || echo "")
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CCPM DESIGN GATE CHECK"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ -z "$EPIC" ] || [ -z "$TASK_N" ]; then
  echo "⚠️  Cannot determine epic/task — no arguments and no verify state."
  echo "   Usage: check-design.sh EPIC TASK_N"
  echo "   Example: check-design.sh my-epic 42"
  echo ""
  echo "→ Provide epic name and task number, or ensure .claude/context/verify/state.json is populated."
  echo ""
  exit 0
fi

DESIGN_FILE=".claude/epics/${EPIC}/designs/task-${TASK_N}-design.md"

echo "Checking: $DESIGN_FILE"
echo ""

if [ -f "$DESIGN_FILE" ]; then
  echo "✅ Design file found: $DESIGN_FILE"
else
  echo "❌ Design file missing: $DESIGN_FILE"
  echo ""
  echo "→ Create design file first. Template sections:"
  echo "   ## Problem"
  echo "   ## Approach"
  echo "   ## Files to Change"
  echo "   ## Rejected Alternatives"
fi

echo ""
exit 0
