---
model: sonnet
allowed-tools: Bash, Read
---

# Context Reset

Safely clear conversation context after ensuring all work is persisted.

## Usage
```
/pm:context-reset
```

## Instructions

### 1. Safety Checks

Run these checks before clearing:

**Check 1: Handoff note exists and is fresh**
```bash
test -f .claude/context/handoffs/latest.md && find .claude/context/handoffs/latest.md -mmin -10 -print | grep -q .
```
If missing or stale: "❌ Write a handoff note first: /pm:handoff-write"

**Check 2: No uncommitted changes**
```bash
git status --porcelain
```
If changes exist: "❌ Uncommitted changes found. Commit or stash first."

**Check 3: Verification state**
Read `.claude/context/verify/state.json`. If active task with verify_mode=STRICT and no VERIFY_PASS:
"⚠️ Active task has not passed verification. Run /pm:verify-run first."

### 2. Clear Verify State

If all checks pass, reset the verify state:
```bash
echo '{"active_task": null}' > .claude/context/verify/state.json
```

### 3. Suggest Clear

```
✅ Context is safe to clear.
  - Handoff note: ✅ Written and fresh
  - Git state: ✅ Clean
  - Verification: ✅ Passed or N/A

Run /clear to reset the conversation context.
Your work is preserved in:
  - .claude/context/handoffs/latest.md (handoff note)
  - .claude/context/verify/results/ (verify logs)
  - Git commits (all code changes)
```

**Important:** This command does NOT automatically run `/clear`. It only validates that it's safe to do so.

Next: Run /clear to reset context, then /pm:issue-start <number> or /pm:next to continue work
