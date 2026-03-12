---
model: opus
allowed-tools: Bash, Read, Write, Glob
---

# Epic Fix Gap

Create a GitHub issue from a gap found in a Phase A report.

## Usage
```
/pm:epic-fix-gap <epic-name> <gap-id>
```

Example:
```
/pm:epic-fix-gap PRD-epic-verify 2
```

## Instructions

### 1. Find Latest Report

```bash
EPIC_NAME="${ARGUMENTS%% *}"
GAP_ID="${ARGUMENTS##* }"
LATEST=$(ls -t .gemini/context/verify/epic-reports/${EPIC_NAME}-*.md 2>/dev/null | head -1)
```

If not found: "❌ Phase A report not found. Run: /pm:epic-verify-a {epic-name}"

### 2. Read Report and Find Gap

Read the report. Find the gap matching `**Gap #${GAP_ID}:`.

Extract:
- Gap name
- Category
- Severity
- Related issues
- Description
- Evidence
- Recommendation
- Estimated effort

If gap not found: "❌ Gap #{GAP_ID} not found in report. Available gaps: #{x}, #{y}, ..."

### 3. Check Remote Origin

```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]]; then
  echo "❌ Cannot create issues on template repo. Update your remote origin."
  exit 1
fi
REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
```

### 4. Create GitHub Issue

Build issue body from gap details:

```markdown
# Gap Fix: [Gap name]

**Source:** Phase A Semantic Review
**Gap ID:** #{N}
**Category:** [category]
**Severity:** [severity]
**Related issues:** #X, #Y

## Problem

[Description from gap report]

## Evidence

[Evidence from gap report]

## Recommendation

[Recommendation from gap report]

## Effort Estimate

[Estimated effort]
```

Create the issue:
```bash
gh issue create --repo "$REPO" \
  --title "Gap Fix: [gap name]" \
  --body-file /tmp/gap-fix-body.md \
  --label "epic:${EPIC_NAME}" \
  --label "gap-fix"
```

### 5. Update Report

Add a note in the report's Gap Report section, after the gap entry:

```markdown
> 📌 Fix issue created: #[new-issue-number] ([datetime])
```

### 6. Output

```
✅ Created fix issue for Gap #{N}

Issue: #{new-number} — [title]
URL: [issue-url]
Labels: epic:{name}, gap-fix

Report updated: {report_path}

Next: Fix the issue, then /pm:epic-verify-a {epic-name} to re-verify
```

## Error Handling

- No arguments → show usage
- Report not found → suggest running epic-verify-a
- Invalid gap ID → list available gap IDs
- GitHub CLI fails → suggest `gh auth login`
