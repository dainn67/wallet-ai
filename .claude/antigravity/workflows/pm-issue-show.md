---
name: pm-issue-show
description: Issue Show
# tier: medium
---

# Issue Show

Display issue and sub-issues with detailed information.

## Usage
```
/pm:issue-show <issue_number>
```

## Instructions

You are displaying comprehensive information about a GitHub issue and related sub-issues for: **Issue #$ISSUE_NUMBER**

### 0. Detect GitHub Repo
```bash
REPO=$(bash .claude/scripts/pm/github-helpers.sh get-repo-for-issue $ISSUE_NUMBER 2>/dev/null || echo "")
```
If empty: "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."

Use `--repo "$REPO"` in ALL `gh` commands below.

### 1. Fetch Issue Data
- Use `gh issue view $ISSUE_NUMBER --repo "$REPO"` to get GitHub issue details
- Look for local task file: first check `.claude/epics/*/$ISSUE_NUMBER.md` (new naming)
- If not found, search for file with `github:.*issues/$ISSUE_NUMBER` in frontmatter (old naming)
- Check for related issues and sub-tasks

### 2. Issue Overview
Display issue header:
```
🎫 Issue #$ISSUE_NUMBER: {Issue Title}
   Status: {open/closed}
   Labels: {labels}
   Assignee: {assignee}
   Created: {creation_date}
   Updated: {last_update}
   
📝 Description:
{issue_description}
```

### 3. Local File Mapping
If local task file exists:
```
📁 Local Files:
   Task file: .claude/epics/{epic_name}/{task_file}
   Updates: .claude/epics/{epic_name}/updates/$ISSUE_NUMBER/
   Last local update: {timestamp}
```

### 4. Sub-Issues and Dependencies
Show related issues:
```
🔗 Related Issues:
   Parent Epic: #{epic_issue_number}
   Dependencies: #{dep1}, #{dep2}
   Blocking: #{blocked1}, #{blocked2}
   Sub-tasks: #{sub1}, #{sub2}
```

### 5. Recent Activity
Display recent comments and updates:
```
💬 Recent Activity:
   {timestamp} - {author}: {comment_preview}
   {timestamp} - {author}: {comment_preview}
   
   View full thread: gh issue view #$ISSUE_NUMBER --comments
```

### 6. Progress Tracking
If task file exists, show progress:
```
✅ Acceptance Criteria:
   ✅ Criterion 1 (completed)
   🔄 Criterion 2 (in progress)
   ⏸️ Criterion 3 (blocked)
   □ Criterion 4 (not started)
```

### 7. Quick Actions
```
🚀 Quick Actions:
   Start work: /pm:issue-start $ISSUE_NUMBER
   Sync updates: /pm:issue-sync $ISSUE_NUMBER
   Add comment: gh issue comment #$ISSUE_NUMBER --body "your comment"
   View in browser: gh issue view #$ISSUE_NUMBER --web
```

### 8. Error Handling
- Handle invalid issue numbers gracefully
- Check for network/authentication issues
- Provide helpful error messages and alternatives

Provide comprehensive issue information to help developers understand context and current status for Issue #$ISSUE_NUMBER.
