---
name: pm-issue-reopen
description: Issue Reopen
# tier: medium
---

# Issue Reopen

Reopen a closed issue.

## Usage
```
/pm:issue-reopen <issue_number> [reason]
```

## Instructions

### 0. Detect GitHub Repo
```bash
REPO=$(bash .claude/scripts/pm/github-helpers.sh get-repo-for-issue $ISSUE_NUMBER 2>/dev/null || echo "")
```
If empty: "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."

Use `--repo "$REPO"` in ALL `gh` commands below.

### 1. Find Local Task File

Search for task file with `github:.*issues/$ISSUE_NUMBER` in frontmatter.
If not found: "❌ No local task for issue #$ISSUE_NUMBER"

### 2. Update Local Status

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update task file frontmatter:
```yaml
status: open
updated: {current_datetime}
```

### 3. Reset Progress

If progress file exists:
- Keep original started date
- Reset completion to previous value or 0%
- Add note about reopening with reason

### 4. Reopen on GitHub

```bash
# Reopen with comment
echo "🔄 Reopening issue

Reason: $ISSUE_NUMBER

---
Reopened at: {timestamp}" | gh issue comment $ISSUE_NUMBER --repo "$REPO" --body-file -

# Reopen the issue
gh issue reopen $ISSUE_NUMBER --repo "$REPO"
```

### 5. Update Epic Progress

Recalculate epic progress with this task now open again.

### 6. Output

```
🔄 Reopened issue #$ISSUE_NUMBER
  Reason: {reason_if_provided}
  Epic progress: {updated_progress}%
  
Start work with: /pm:issue-start $ISSUE_NUMBER
```

## Important Notes

Preserve work history in progress files.
Don't delete previous progress, just reset status.
