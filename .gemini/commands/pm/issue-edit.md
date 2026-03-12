---
model: sonnet
allowed-tools: Bash, Read, Write, LS
---

# Issue Edit

Edit issue details locally and on GitHub.

## Usage
```
/pm:issue-edit <issue_number>
```

## Instructions

### 0. Detect GitHub Repo
```bash
REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo-for-issue $ARGUMENTS 2>/dev/null || echo "")
```
If empty: "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."

Use `--repo "$REPO"` in ALL `gh` commands below.

### 1. Get Current Issue State

```bash
# Get from GitHub
gh issue view $ARGUMENTS --repo "$REPO" --json title,body,labels

# Find local task file
# Search for file with github:.*issues/$ARGUMENTS
```

### 2. Interactive Edit

Ask user what to edit:
- Title
- Description/Body
- Labels
- Acceptance criteria (local only)
- Priority/Size (local only)

### 3. Update Local File

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update task file with changes:
- Update frontmatter `name` if title changed
- Update body content if description changed
- Update `updated` field with current datetime

### 4. Update GitHub

If title changed:
```bash
gh issue edit $ARGUMENTS --repo "$REPO" --title "{new_title}"
```

If body changed:
```bash
gh issue edit $ARGUMENTS --repo "$REPO" --body-file {updated_task_file}
```

If labels changed:
```bash
gh issue edit $ARGUMENTS --repo "$REPO" --add-label "{new_labels}"
gh issue edit $ARGUMENTS --repo "$REPO" --remove-label "{removed_labels}"
```

### 5. Output

```
✅ Updated issue #$ARGUMENTS
  Changes:
    {list_of_changes_made}
  
Synced to GitHub: ✅
```

## Important Notes

Always update local first, then GitHub.
Preserve frontmatter fields not being edited.
Follow `.gemini/rules/frontmatter.md`.
