---
model: sonnet
allowed-tools: Bash, Read, Write, LS
---

# Issue Sync

Push local progress updates to GitHub as an issue comment.

## Usage
```
/pm:issue-sync <issue_number>
```

## Preflight

```bash
# 1. Detect GitHub repo
REPO=$(bash .claude/scripts/pm/github-helpers.sh get-repo-for-issue $ARGUMENTS 2>/dev/null || echo "")
[ -z "$REPO" ] && { echo "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."; exit 1; }

# 2. Check remote is not CCPM template
[[ "$REPO" == *"automazeio/ccpm"* ]] && { echo "❌ Cannot sync to CCPM template repo."; exit 1; }

# 3. Verify issue exists on GitHub
gh issue view $ARGUMENTS --repo "$REPO" --json state -q .state || { echo "❌ Issue #$ARGUMENTS not found on GitHub."; exit 1; }

# 3. Check local updates exist
updates_dir=$(find .claude/epics/*/updates/$ARGUMENTS -type d 2>/dev/null | head -1)
[ -z "$updates_dir" ] && { echo "❌ No local updates for #$ARGUMENTS. Run: /pm:issue-start $ARGUMENTS"; exit 1; }
echo "Updates directory: $updates_dir"
```

## Lifecycle Check

Before syncing, check if a handoff note should be written:
```bash
# If active task exists in verify state, warn about missing handoff
if [ -f .claude/context/verify/state.json ]; then
  active=$(jq -r '.active_task // empty' .claude/context/verify/state.json 2>/dev/null)
  if [ -n "$active" ] && [ "$active" != "null" ]; then
    if [ ! -f .claude/context/handoffs/latest.md ] || [ -z "$(find .claude/context/handoffs/latest.md -mmin -10 -print 2>/dev/null)" ]; then
      echo "⚠️ Handoff note missing or stale. Consider running /pm:handoff-write"
    fi
  fi
fi
```

## Instructions

### Step 1: Gather Updates

Read all files in the updates directory for this issue:
- `progress.md` - Development progress
- `stream-*.md` - Work stream updates
- Any other `.md` files

Also check recent git commits for this issue:
```bash
git log --oneline --grep="Issue #$ARGUMENTS" -10 2>/dev/null
```

### Step 2: Build Comment

Create a progress comment. Include only sections that have content:

```markdown
## Progress Update - {date}

### Completed
- {completed items from updates}

### In Progress
- {current work items}

### Recent Commits
- {commit summaries from git log}

### Blockers
- {any blockers, or "None"}

---
*Progress: {completion}% | Synced at {timestamp}*
```

Write the comment to a temp file.

### Step 3: Post to GitHub

```bash
gh issue comment $ARGUMENTS --repo "$REPO" --body-file /tmp/issue-sync-comment.md
```

### Step 4: Update Local Frontmatter

Update `progress.md` frontmatter with `last_sync` timestamp.

If task is 100% complete, also:
- Update task file `status: closed`
- Recalculate epic progress: `(closed_tasks / total_tasks) * 100`
- Update epic frontmatter `progress:` field

### Output

```
✅ Synced to GitHub Issue #$ARGUMENTS
  Comment posted with {item_count} updates
  Progress: {completion}%

Next steps:
  - View: gh issue view $ARGUMENTS --comments
  - Complete when done: /pm:issue-complete $ARGUMENTS
```
