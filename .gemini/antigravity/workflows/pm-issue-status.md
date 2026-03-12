---
name: pm-issue-status
description: Issue Status
# tier: medium
---

# Issue Status

Check issue status (open/closed) and current state.

## Usage
```
/pm:issue-status <issue_number>
```

## Instructions

You are checking the current status of a GitHub issue and providing a quick status report for: **Issue #$ISSUE_NUMBER**

### 0. Detect GitHub Repo
```bash
REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo-for-issue $ISSUE_NUMBER 2>/dev/null || echo "")
```
If empty: "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."

Use `--repo "$REPO"` in ALL `gh` commands below.

### 1. Fetch Issue Status
Use GitHub CLI to get current status:
```bash
gh issue view $ISSUE_NUMBER --repo "$REPO" --json state,title,labels,assignees,updatedAt
```

### 2. Status Display
Show concise status information:
```
🎫 Issue #$ISSUE_NUMBER: {Title}
   
📊 Status: {OPEN/CLOSED}
   Last update: {timestamp}
   Assignee: {assignee or "Unassigned"}
   
🏷️ Labels: {label1}, {label2}, {label3}
```

### 3. Epic Context
If issue is part of an epic:
```
📚 Epic Context:
   Epic: {epic_name}
   Epic progress: {completed_tasks}/{total_tasks} tasks complete
   This task: {task_position} of {total_tasks}
```

### 4. Local Sync Status
Check if local files are in sync:
```
💾 Local Sync:
   Local file: {exists/missing}
   Last local update: {timestamp}
   Sync status: {in_sync/needs_sync/local_ahead/remote_ahead}
```

### 5. Quick Status Indicators
Use clear visual indicators:
- 🟢 Open and ready
- 🟡 Open with blockers  
- 🔴 Open and overdue
- ✅ Closed and complete
- ❌ Closed without completion

### 6. Actionable Next Steps
Based on status, suggest actions:
```
🚀 Suggested Actions:
   - Start work: /pm:issue-start $ISSUE_NUMBER
   - During work: /pm:verify-run (check your work)
   - Complete: /pm:issue-complete $ISSUE_NUMBER (handoff + verify + close)
   - Reopen: /pm:issue-reopen $ISSUE_NUMBER
```

### 7. Batch Status
If checking multiple issues, support comma-separated list:
```
/pm:issue-status 123,124,125
```

Keep the output concise but informative, perfect for quick status checks during development of Issue #$ISSUE_NUMBER.
