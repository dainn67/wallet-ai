---
name: pm-epic-verify-abort
description: Epic Verify — Abort
# tier: medium
---

# Epic Verify — Abort

Abort an active epic verification, clearing the Ralph loop state.

## Usage
```
/pm:epic-verify-abort <epic-name>
```

## Instructions

### 1. Check Active State

```bash
STATE_FILE=".gemini/context/verify/epic-state.json"
```

Read the state file. If it doesn't exist or `active_epic` is null:
```
❌ No active verification to abort for epic '$EPIC_NAME'.
```
Stop here.

### 2. Verify Epic Match

Check that `active_epic.epic_name` matches `$EPIC_NAME`. If not:
```
❌ Active verification is for epic '{active_epic_name}', not '$EPIC_NAME'.
   To abort that one: /pm:epic-verify-abort {active_epic_name}
```

### 3. Ask for Reason

Prompt the developer for an abort reason:
```
Aborting verification for epic '$EPIC_NAME'.

Current state:
  Phase:     {phase}
  Iteration: {current_iteration}/{max_iterations}
  Started:   {started_at}

Why are you aborting? (This will be logged)
```

Wait for the developer's response.

### 4. Clear State

Get current datetime:
```bash
ABORT_DT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

Write abort record to state file:
```bash
bash .gemini/scripts/pm/lifecycle-helpers.sh write-epic-verify-state "{\"active_epic\": null, \"last_abort\": {\"epic_name\": \"$EPIC_NAME\", \"aborted_at\": \"$ABORT_DT\", \"reason\": \"DEVELOPER_REASON\", \"iteration_at_abort\": CURRENT_ITER}}"
```

Replace `DEVELOPER_REASON` with the actual reason provided, and `CURRENT_ITER` with the iteration count before abort.

### 5. Confirm

```
✅ Verification aborted for epic '$EPIC_NAME'.

  Reason:    {reason}
  Aborted at iteration: {current_iteration}/{max_iterations}
  Ralph Hook: ❌ Deactivated

To resume later: /pm:epic-verify-resume $EPIC_NAME
To restart:      /pm:epic-verify $EPIC_NAME
```

## Error Handling

- No arguments → "❌ Usage: /pm:epic-verify-abort <epic-name>"
- No active verification → Clear message
- State write fails → "❌ Cannot update state: {error}"
