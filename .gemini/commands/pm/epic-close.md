---
model: sonnet
allowed-tools: Bash, Read, Write, LS
---

# Epic Close

Mark an epic as complete when all tasks are done.

## Usage
```
/pm:epic-close <epic_name>
```

## Instructions

### 1. Verify All Tasks Complete

Check all task files in `.gemini/epics/$ARGUMENTS/`:
- Verify all have `status: closed` in frontmatter
- If any open tasks found: "❌ Cannot close epic. Open tasks remain: {list}"

### 2. Update Epic Status

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update epic.md frontmatter:
```yaml
status: completed
progress: 100%
updated: {current_datetime}
completed: {current_datetime}
```

### 3. Update PRD Status

If epic references a PRD, update its status to "complete".

### 4. Close Epic on GitHub

If epic has GitHub issue:
```bash
# Detect repo from epic's github: field
REPO=""
epic_github=$(grep '^github:' .gemini/epics/$ARGUMENTS/epic.md 2>/dev/null | head -1 | sed 's/^github: *//')
if [ -n "$epic_github" ]; then
  REPO=$(echo "$epic_github" | sed 's|https://github.com/||' | sed 's|/issues/.*||')
fi
if [ -z "$REPO" ]; then
  REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo-for-issue 2>/dev/null || echo "")
fi

gh issue close {epic_issue_number} --repo "$REPO" --comment "✅ Epic completed - all tasks done"
```

### 5. Archive Option

Ask user: "Archive completed epic? (yes/no)"

If yes:
- Move epic directory to `.gemini/epics/.archived/{epic_name}/`
- Create archive summary with completion date

### 6. Output

```
✅ Epic closed: $ARGUMENTS
  Tasks completed: {count}
  Duration: {days_from_created_to_completed}
  
{If archived}: Archived to .gemini/epics/.archived/

Next: /pm:status (overview) or /pm:prd-new <name> (start new feature)
```

## Important Notes

Only close epics with all tasks complete.
Preserve all data when archiving.
Update related PRD status.
