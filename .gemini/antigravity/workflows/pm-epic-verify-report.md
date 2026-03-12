---
name: pm-epic-verify-report
description: Epic Verify — View Report
# tier: medium
---

# Epic Verify — View Report

Display the most recent verification report for an epic. Prioritizes final reports over Phase A reports.

## Usage
```
/pm:epic-verify-report <epic-name>
```

## Instructions

### 1. Find Report

```bash
EPIC_NAME="$EPIC_NAME"

# Prefer final report
REPORT=$(ls -t .gemini/context/verify/epic-reports/${EPIC_NAME}-final-*.md 2>/dev/null | head -1)

# Fall back to Phase A report
if [ -z "$REPORT" ]; then
  REPORT=$(ls -t .gemini/context/verify/epic-reports/${EPIC_NAME}-*.md 2>/dev/null | head -1)
fi
```

If no report found:
```
❌ No verification report found for epic '$EPIC_NAME'.
   Run: /pm:epic-verify-a $EPIC_NAME to generate a Phase A report.
```

### 2. Display Report

Read the report file and display its full content.

If the report has frontmatter, show a summary header first:
```
═══ Epic Verification Report ═══

Epic:       {epic_name}
Phase:      {phase from frontmatter}
Assessment: {assessment from frontmatter}
Quality:    {quality_score from frontmatter}
Generated:  {generated from frontmatter}
Report:     {report file path}

───────────────────────────────
```

Then display the full report content (without frontmatter).

## Error Handling

- No arguments → "❌ Usage: /pm:epic-verify-report <epic-name>"
- No reports found → Clear message with next step
- File read error → "❌ Cannot read report: {error}"
