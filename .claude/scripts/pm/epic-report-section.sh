#!/usr/bin/env bash
# Extract a section from the latest Phase A report for an epic.
# Usage: epic-report-section.sh <epic-name> <section-keyword>
# Example: epic-report-section.sh PRD-epic-verify "Gap Report"
# Example: epic-report-section.sh PRD-epic-verify "Coverage Matrix"

set -euo pipefail

EPIC_NAME="${1:-}"
SECTION_KEYWORD="${2:-}"

if [ -z "$EPIC_NAME" ] || [ -z "$SECTION_KEYWORD" ]; then
  echo "Usage: epic-report-section.sh <epic-name> <section-keyword>"
  exit 1
fi

REPORTS_DIR=".claude/context/verify/epic-reports"

# Find latest report for this epic
LATEST_REPORT=$(ls -t "$REPORTS_DIR"/${EPIC_NAME}-*.md 2>/dev/null | head -1)

if [ -z "$LATEST_REPORT" ]; then
  echo "❌ Phase A report not found. Run: /pm:epic-verify-a $EPIC_NAME"
  exit 1
fi

echo "📄 Report: $LATEST_REPORT"
echo ""

# Extract section: find header containing keyword, print until next same-level header
awk -v keyword="$SECTION_KEYWORD" '
  BEGIN { found=0; level=0 }
  # Match header containing keyword (case-insensitive)
  tolower($0) ~ tolower(keyword) && /^#/ {
    found=1
    # Count header level
    match($0, /^#+/)
    level=RLENGTH
    print
    next
  }
  # If found, print until next header of same or higher level
  found && /^#+/ {
    match($0, /^#+/)
    if (RLENGTH <= level) exit
    print
    next
  }
  found { print }
' "$LATEST_REPORT"
