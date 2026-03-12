---
model: sonnet
allowed-tools: Bash, Read, Write, Glob
---

# Epic Accept Gaps

Mark gaps from a Phase A report as "accepted" (acknowledged technical debt).

## Usage
```
/pm:epic-accept-gaps <epic-name> <gap-ids>
```

Examples:
```
/pm:epic-accept-gaps PRD-epic-verify 1,3
/pm:epic-accept-gaps PRD-epic-verify all
```

## Instructions

### 1. Find Latest Report

```bash
LATEST=$(ls -t .gemini/context/verify/epic-reports/${ARGUMENTS%% *}-*.md 2>/dev/null | head -1)
```

If not found: "❌ Phase A report not found. Run: /pm:epic-verify-a {epic-name}"

### 2. Parse Arguments

- First argument: epic name
- Second argument: comma-separated gap IDs (numbers) or "all"

### 3. Read Report

Read the report file. Find all gaps matching the format `**Gap #{N}: [name]**`.

### 4. Validate Gap IDs

Check that each requested gap ID exists in the report. If not found: "❌ Gap #{N} not found in report."

### 5. Update Report

Append an "## Accepted Gaps" section at the end of the report (before any existing "Accepted Gaps" section — replace it if exists).

Format:
```markdown
## Accepted Gaps

The following gaps have been reviewed and accepted as technical debt:

| Gap | Name | Severity | Accepted |
|-----|------|----------|----------|
| #{N} | [name] | [severity] | {current ISO datetime} |

**Accepted by:** Developer (manual review)
```

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

### 6. Output

```
✅ Accepted {count} gap(s) in Phase A report

Report: {report_path}
Accepted: Gap #{x}, Gap #{y}

These gaps are acknowledged as technical debt and will not block Phase B.

Next: /pm:epic-verify-b {epic-name} (proceed to Phase B)
```

## Error Handling

- No arguments → show usage
- Report not found → suggest running epic-verify-a
- Invalid gap ID → list available gap IDs
