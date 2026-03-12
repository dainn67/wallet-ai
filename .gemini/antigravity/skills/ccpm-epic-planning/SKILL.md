---
name: ccpm-epic-planning
description: Use when fix gaps, plan gap fixes, address epic gaps, create issues for gaps, epic has gaps. NOT for: verifying epic, merging epic, task-level work, general issue creation.
---

# CCPM Epic Planning (Gap Fixes)

Parse the epic gap report and generate `gh issue create` commands for each gap found.

## Steps

**SEQUENTIAL — present to user before executing.**

### Step 1 — Read Gap Report

Run `antigravity/skills/ccpm-epic-planning/scripts/plan-gaps.sh` to read the latest gap report.

The script will:
- Find the most recent gap report in `.gemini/context/verify/epic-reports/`
- Parse gaps from the report (lines starting with "- GAP:" or "## Gap" sections)
- Output ready-to-run `gh issue create` commands for each gap
- Show total gap count

If the script outputs "❌ No gap reports found", stop and tell the user:
"Run epic verify first to generate a gap report: `/pm:epic-verify {epic_name}`"

### Step 2 — Present to User

Present the gap summary and the generated `gh issue create` commands.

Format:
```
Gap report: {N} gaps found

Gaps:
1. [{SEVERITY}] {gap description}
2. [{SEVERITY}] {gap description}
...

Suggested commands (review before running):
gh issue create --title "Gap: {description}" --body "..." --label "tech-debt,epic:{name}"
...

Run these? (y/n)
```

### Step 3 — Wait for Confirmation

**Do NOT execute `gh issue create` commands automatically.**

Wait for explicit user confirmation before running any GitHub commands.

- If user confirms → run each command sequentially
- If user declines → show the commands for manual reference only

### Step 4 — Report Results

After execution (if confirmed):
```
Created {N} issues for epic gaps:
  #{issue_number}: {title}
  ...

Next:
  - Fix issues and re-run: /pm:epic-verify {epic_name}
  - Accept minor gaps: /pm:epic-accept-gaps {epic_name}
```

## Gap Severity Guide

- **CRITICAL**: Blocks epic completion — must fix
- **HIGH**: Significant missing requirement — should fix
- **MEDIUM**: Minor gap — consider fixing or accepting as tech debt
- **LOW**: Nice to have — likely accept as tech debt

## Note on Tech Debt

Gaps are tech debt. Not all gaps require immediate issues.

- Accept minor gaps with `/pm:epic-accept-gaps {epic_name}`
- Fix critical gaps by creating issues (this skill)
- Document accepted gaps in the final epic report
