---
name: pm-epic-oneshot
description: Epic Oneshot
# tier: heavy
---

# Epic Oneshot

Decompose epic into tasks and sync to GitHub in one operation.

## Usage
```
/pm:epic-oneshot <feature_name>
```

## Preflight (silent — do not show progress to user)

1. **Validate `$EPIC_NAME`:**
   - If empty → `❌ Missing feature name. Usage: /pm:epic-oneshot <feature_name>` and stop.
   - MUST match `^[a-z0-9][a-z0-9-]*[a-z0-9]$`. If invalid → `❌ Feature name must be kebab-case. Got: '$EPIC_NAME'` and stop.

2. **Locate epic:**
   - If `.claude/epics/$EPIC_NAME/epic.md` doesn't exist → `❌ Epic not found. Run: /pm:prd-parse $EPIC_NAME` and stop.

3. **Check existing tasks:**
   - If task files (`[0-9]*.md`) exist in `.claude/epics/$EPIC_NAME/`:
     ```
     ⚠️ Found {count} existing tasks for '$EPIC_NAME'.
     Options:
       → Delete and recreate: answer 'recreate'
       → Sync existing tasks: run /pm:epic-sync $EPIC_NAME
       → Abort: answer 'abort'
     ```
   - If "recreate" → delete existing task files and continue.
   - If "abort" → stop.

4. **Check if already synced:**
   - Read epic frontmatter. If `github` field has a non-empty value (not `""`, not placeholder) → epic already synced:
     ```
     ⚠️ Epic '$EPIC_NAME' already synced to GitHub (#{issue_number}).
     Use /pm:epic-sync $EPIC_NAME to update instead.
     ```
     Stop.

5. **Verify GitHub CLI access:**
   - Run: `gh auth status 2>&1`
   - If not authenticated → `❌ GitHub CLI not authenticated. Run: gh auth login` and stop.
   - If authenticated → continue silently.

## Execution

This command orchestrates two commands in sequence with failure handling:

### Step 1: Decompose

```
⏳ Step 1/2: Decomposing epic into tasks...
```

Execute: `/pm:epic-decompose $EPIC_NAME`

**On success:** Continue to Step 2.
**On failure:** Stop and report:
```
❌ Decomposition failed for '$EPIC_NAME'.
Fix the issue above, then retry: /pm:epic-oneshot $EPIC_NAME
```

### Step 2: Sync to GitHub

```
⏳ Step 2/2: Syncing to GitHub Issues...
```

Execute: `/pm:epic-sync $EPIC_NAME`

**On success:** Continue to Output.
**On failure:** Report with recovery guidance:
```
⚠️ Decomposition succeeded but GitHub sync failed.

Tasks are saved locally in .claude/epics/$EPIC_NAME/
To retry sync only: /pm:epic-sync $EPIC_NAME
To start over:      delete task files and run /pm:epic-oneshot $EPIC_NAME
```

## Output

On full success:

```
🚀 Epic Oneshot Complete: $EPIC_NAME

Step 1: Decomposition ✅
  Tasks created: {count} ({parallel_count} parallel, {sequential_count} sequential)
  Critical path: ~{duration}

Step 2: GitHub Sync ✅
  Epic issue: #{epic_number}
  Sub-issues: {count} created
  Worktree: ../epic-$EPIC_NAME

📋 Next actions:
  → Start all parallel tasks:  /pm:epic-start $EPIC_NAME
  → Start single task:         /pm:issue-start {first_task_number}
  → View epic dashboard:       /pm:epic-show $EPIC_NAME
```

## Important Notes

- This is a convenience wrapper that runs `/pm:epic-decompose` then `/pm:epic-sync` in sequence.
- Both sub-commands handle their own validation, parallel execution, and quality checks. Tasks follow `rules/task-template.md`.
- If decompose includes a user confirmation step (task plan review), that interaction still happens — oneshot does NOT skip confirmations.
- Use this when you're confident the epic is ready and want to go from epic → GitHub Issues in one step.
- If you only need one half: use `/pm:epic-decompose` or `/pm:epic-sync` individually.
