#!/usr/bin/env bash
# ccpm-epic-planning: plan-gaps.sh
#
# Reads the latest gap report from .gemini/context/verify/epic-reports/
# and outputs ready-to-run gh issue create commands for each gap found.
# Always exits 0 — advisory only.

set -uo pipefail

REPORTS_DIR=".gemini/context/verify/epic-reports"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  EPIC GAP PLANNER"
echo "═══════════════════════════════════════════════════════"
echo ""

# --- Find latest gap report ---

if [ ! -d "$REPORTS_DIR" ]; then
  echo "❌ No gap reports found. Reports directory does not exist at $REPORTS_DIR"
  echo "   Run epic verify first: /pm:epic-verify {epic_name}"
  echo ""
  exit 0
fi

# Find most recently modified report file (exclude final reports)
LATEST_REPORT=$(find "$REPORTS_DIR" -name "*.md" -type f 2>/dev/null \
  | grep -v "\-final\-" \
  | sort -t/ -k1 2>/dev/null \
  | xargs ls -t 2>/dev/null \
  | head -1)

if [ -z "$LATEST_REPORT" ]; then
  # Try including all reports if no non-final found
  LATEST_REPORT=$(find "$REPORTS_DIR" -name "*.md" -type f 2>/dev/null \
    | xargs ls -t 2>/dev/null \
    | head -1)
fi

if [ -z "$LATEST_REPORT" ]; then
  echo "❌ No gap reports found. Run epic verify first to generate a gap report."
  echo "   Run: /pm:epic-verify {epic_name}"
  echo ""
  exit 0
fi

echo "Found report: $LATEST_REPORT"
echo ""

# --- Extract epic name from report filename or frontmatter ---

EPIC_NAME=$(basename "$LATEST_REPORT" | sed 's/-[0-9]*-[0-9]*\.md$//' | sed 's/-[0-9]*\.md$//' 2>/dev/null || echo "unknown")

# Try to get epic name from frontmatter
if command -v python3 >/dev/null 2>&1; then
  FM_EPIC=$(python3 -c "
import sys
content = open('$LATEST_REPORT').read()
lines = content.split('\n')
in_fm = False
for line in lines:
    if line.strip() == '---':
        if not in_fm:
            in_fm = True
            continue
        else:
            break
    if in_fm and line.startswith('epic:'):
        print(line.split(':', 1)[1].strip())
        break
" 2>/dev/null || echo "")
  if [ -n "$FM_EPIC" ]; then
    EPIC_NAME="$FM_EPIC"
  fi
fi

echo "Epic: $EPIC_NAME"
echo ""

# --- Parse gaps from the report ---

echo "## Parsing Gaps"
echo ""

# Read the report content
REPORT_CONTENT=$(cat "$LATEST_REPORT" 2>/dev/null || echo "")

if [ -z "$REPORT_CONTENT" ]; then
  echo "⚠️  Could not read report file."
  exit 0
fi

# Find gaps — look for lines starting with "- GAP:" or table rows in Gap Report section
GAP_COUNT=0
GAPS_FOUND=""

# Strategy 1: Lines starting with "- GAP:"
while IFS= read -r line; do
  if echo "$line" | grep -qE "^- GAP:" 2>/dev/null; then
    GAP_DESCRIPTION=$(echo "$line" | sed 's/^- GAP://' | sed 's/^[[:space:]]*//' 2>/dev/null || echo "$line")
    GAP_COUNT=$((GAP_COUNT + 1))
    GAPS_FOUND="$GAPS_FOUND\n${GAP_COUNT}|MEDIUM|${GAP_DESCRIPTION}"
  fi
done <<< "$REPORT_CONTENT"

# Strategy 2: Table rows in Gap Report section (| N | SEVERITY | description | ... |)
IN_GAP_SECTION=false
while IFS= read -r line; do
  if echo "$line" | grep -qiE "## Gap Report|### Gap" 2>/dev/null; then
    IN_GAP_SECTION=true
    continue
  fi
  if [ "$IN_GAP_SECTION" = true ]; then
    if echo "$line" | grep -qE "^## " 2>/dev/null; then
      IN_GAP_SECTION=false
      continue
    fi
    # Match table rows with severity keywords
    if echo "$line" | grep -qiE "CRITICAL|HIGH|MEDIUM|LOW" 2>/dev/null; then
      # Extract from pipe-delimited table: | N | SEVERITY | description | recommendation |
      SEVERITY=$(echo "$line" | grep -oiE "CRITICAL|HIGH|MEDIUM|LOW" | head -1 | tr '[:lower:]' '[:upper:]' 2>/dev/null || echo "MEDIUM")
      # Get description — 3rd column in table
      GAP_DESC=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' 2>/dev/null || echo "")
      if [ -n "$GAP_DESC" ] && [ "$GAP_DESC" != "{description}" ]; then
        # Avoid duplicates from strategy 1
        GAP_COUNT=$((GAP_COUNT + 1))
        GAPS_FOUND="$GAPS_FOUND\n${GAP_COUNT}|${SEVERITY}|${GAP_DESC}"
      fi
    fi
  fi
done <<< "$REPORT_CONTENT"

echo ""

if [ "$GAP_COUNT" -eq 0 ]; then
  echo "No gaps found in report."
  echo ""
  echo "Either:"
  echo "  - The epic has no gaps (assessment was EPIC_READY)"
  echo "  - The gap format in the report is non-standard"
  echo ""
  echo "Review the report manually: $LATEST_REPORT"
  exit 0
fi

echo "Found $GAP_COUNT gap(s)."
echo ""

# --- Output gh issue create commands ---

echo "## Suggested GitHub Issues"
echo ""
echo "Review and run these commands to create issues for each gap:"
echo ""

ISSUE_NUM=0
while IFS='|' read -r num severity description; do
  if [ -z "$num" ]; then continue; fi
  ISSUE_NUM=$((ISSUE_NUM + 1))
  ISSUE_TITLE="Gap: $description"
  ISSUE_BODY="## Gap Details

**Epic:** $EPIC_NAME
**Severity:** $severity
**Source:** $LATEST_REPORT

## Description

$description

## Acceptance Criteria

- [ ] Gap addressed and verified
- [ ] Re-run \`/pm:epic-verify $EPIC_NAME\` to confirm resolution

## Notes

This issue was generated from the epic gap report. See the full report for context."

  echo "### Gap $ISSUE_NUM [$severity]: $description"
  echo ""
  echo "gh issue create \\"
  echo "  --title \"Gap: $description\" \\"
  echo "  --body \"$ISSUE_BODY\" \\"
  echo "  --label \"tech-debt,epic:$EPIC_NAME\""
  echo ""
done <<< "$(printf '%b' "$GAPS_FOUND")"

echo "═══════════════════════════════════════════════════════"
echo "  Total gaps: $GAP_COUNT"
echo "  Review commands above before executing."
echo "═══════════════════════════════════════════════════════"
echo ""

exit 0
