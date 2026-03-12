---
model: sonnet
allowed-tools: Bash, Read, Write, LS
---

# Issue Close

Mark an issue as complete and close it on GitHub.

## Usage
```
/pm:issue-close <issue_number> [completion_notes]
```

## Instructions

### 0. Detect GitHub Repo

```bash
REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo-for-issue $ARGUMENTS 2>/dev/null || echo "")
```
If empty: "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."

Use `--repo "$REPO"` in ALL `gh` commands below.

### 1. Find Local Task File

First check if `.gemini/epics/*/$ARGUMENTS.md` exists (new naming).
If not found, search for task file with `github:.*issues/$ARGUMENTS` in frontmatter (old naming).
If not found: "❌ No local task for issue #$ARGUMENTS"

### 2. Update Local Status

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update task file frontmatter:
```yaml
status: closed
updated: {current_datetime}
```

### 3. Update Progress File

If progress file exists at `.gemini/epics/{epic}/updates/$ARGUMENTS/progress.md`:
- Set completion: 100%
- Add completion note with timestamp
- Update last_sync with current datetime

### 4. Close on GitHub

Add completion comment and close:
```bash
# Add final comment
echo "✅ Task completed

$ARGUMENTS

---
Closed at: {timestamp}" | gh issue comment $ARGUMENTS --repo "$REPO" --body-file -

# Close the issue
gh issue close $ARGUMENTS --repo "$REPO"
```

### 5. Update Epic Task List on GitHub

Check the task checkbox in the epic issue:

```bash
# Get epic name from local task file path
epic_name={extract_from_path}

# Get epic issue number from epic.md
epic_issue=$(grep 'github:' .gemini/epics/$epic_name/epic.md | grep -oE '[0-9]+$')

if [ ! -z "$epic_issue" ]; then
  # Get current epic body
  gh issue view $epic_issue --repo "$REPO" --json body -q .body > /tmp/epic-body.md
  
  # Check off this task
  sed -i "s/- \[ \] #$ARGUMENTS/- [x] #$ARGUMENTS/" /tmp/epic-body.md
  
  # Update epic issue
  gh issue edit $epic_issue --repo "$REPO" --body-file /tmp/epic-body.md
  
  echo "✓ Updated epic progress on GitHub"
fi
```

### 6. Update Epic Progress

```bash
# Find epic name from the task file path
epic_name=$(ls .gemini/epics/*/[0-9]*.md 2>/dev/null | grep "/${ARGUMENTS}.md$" | head -1 | sed 's|.gemini/epics/||' | cut -d'/' -f1)

if [ -n "$epic_name" ] && [ -f ".gemini/epics/$epic_name/epic.md" ]; then
  # Count tasks
  total=0
  closed=0
  for task_file in .gemini/epics/$epic_name/[0-9]*.md; do
    [ -f "$task_file" ] || continue
    ((total++))
    task_status=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
    if [ "$task_status" = "closed" ] || [ "$task_status" = "completed" ]; then
      ((closed++))
    fi
  done

  # Calculate percentage and update epic.md
  if [ $total -gt 0 ]; then
    percent=$((closed * 100 / total))
    updated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    sed -i.bak "s/^progress: .*/progress: ${percent}%/" ".gemini/epics/$epic_name/epic.md" && rm -f ".gemini/epics/$epic_name/epic.md.bak"
    sed -i.bak "s/^updated: .*/updated: ${updated_at}/" ".gemini/epics/$epic_name/epic.md" && rm -f ".gemini/epics/$epic_name/epic.md.bak"
    echo "✓ Epic progress updated: ${percent}% (${closed}/${total} tasks closed)"
  fi
fi
```

### 7. Output

```
✅ Closed issue #$ARGUMENTS
  Local: Task marked complete
  GitHub: Issue closed & epic updated
  Epic progress: {new_progress}% ({closed}/{total} tasks complete)
  
Next:
  - More issues to do: /pm:next
  - All issues closed: /pm:epic-verify {epic_name}
```

## Important Notes

Follow `.gemini/rules/frontmatter.md` for updates.
Follow `.gemini/rules/github-operations.md` for GitHub commands.
Always sync local state before GitHub.
