---
model: sonnet
allowed-tools: Bash, Read, Write
---

# Verify Skip

Bypass verification for the current task with a required reason.

## Usage
```
/pm:verify-skip <reason>
```

## Instructions

### 1. Validate Arguments

If no reason provided (`$ARGUMENTS` is empty):
```
❌ Reason required. Usage: /pm:verify-skip <reason>
Example: /pm:verify-skip "docs-only change, no code to verify"
```

### 2. Check Active Task

Read `.gemini/context/verify/state.json`.

If no active task:
```
❌ No active task. Run /pm:issue-start <number> first.
```

### 3. Update State

Update `.gemini/context/verify/state.json`:
- Set `active_task.verify_mode` to `"SKIP"`
- Add `active_task.skip_reason` with the provided reason
- Add `active_task.skipped_at` with current datetime

Use `jq` or Python3 to update the JSON:
```bash
source .gemini/scripts/pm/lifecycle-helpers.sh
state=$(read_verify_state)
# Update verify_mode to SKIP and add skip_reason
```

### 4. Warn

```
⚠️ Verification SKIPPED for task #{issue_number}
  Reason: {reason}

  The stop hook will no longer block exit for this task.
  Make sure you've manually verified your changes.

Next: /pm:issue-complete {issue_number}
```
