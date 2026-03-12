---
name: pm-issue-verified
description: Issue Verified
# tier: medium
---

# Issue Verified

Full lifecycle command: load context, initialize verification, and set up for verified work.

This is an enhanced version of `/pm:issue-start` that integrates the verification lifecycle. Use this instead of `issue-start` when you want full lifecycle enforcement.

## Usage
```
/pm:issue-verified <issue_number>
```

## Instructions

### 0. Detect GitHub Repo
```bash
REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo-for-issue $ISSUE_NUMBER 2>/dev/null || echo "")
```
If empty: "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."

Use `--repo "$REPO"` in ALL `gh` commands below.

### 1. Validate Arguments

If no issue number provided: "❌ Usage: /pm:issue-verified <issue_number>"

### 2. Load Context (Pre-Task)

Run the pre-task hook to load previous context:
```bash
bash .gemini/hooks/pre-task.sh
```

Follow the context loading protocol output by the hook.

### 3. Find Task Details

Get issue details:
```bash
gh issue view $ISSUE_NUMBER --repo "$REPO" --json state,title,labels,body
```

Find local task file in `.gemini/epics/*/$ISSUE_NUMBER.md`.

### 4. Initialize Verification State

```bash
source .gemini/scripts/pm/lifecycle-helpers.sh

# Detect epic name from task file path
epic_name=$(basename $(dirname $(ls .gemini/epics/*/$ISSUE_NUMBER.md 2>/dev/null | head -1)))

init_verify_state $ISSUE_NUMBER "$epic_name"
```

This sets up:
- Task type detection (BUG_FIX/FEATURE/REFACTOR/DOCS/CONFIG)
- Tech stack detection (python/node/swift/rust/go/generic)
- Verify mode (STRICT/RELAXED/SKIP)
- Max iterations based on task type

### 5. Display Task Briefing

```
═══ Task #$ISSUE_NUMBER: {title} ═══

Lifecycle Mode: VERIFIED
  Type:       {task_type}
  Verify:     {verify_mode}
  Stack:      {tech_stack}
  Max iters:  {max_iterations}

When you're done:
  1. Write handoff: /pm:handoff-write
  2. Complete task: /pm:issue-complete $ISSUE_NUMBER

The stop hook will automatically verify your work before allowing exit.
```

### 6. Begin Work

Read the full task file and begin implementation.

Follow the same analysis/implementation flow as `/pm:issue-start`, but with verification lifecycle awareness.

## Important Notes

- The stop hook (`.gemini/hooks/stop-verify.sh`) will run automatically when you try to exit
- In STRICT mode, you cannot exit without passing verification
- Write your handoff note BEFORE completing the task
- Use `/pm:verify-status` to check verification state anytime
- Use `/pm:verify-skip <reason>` to bypass verification if needed
