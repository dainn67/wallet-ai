---
model: opus
allowed-tools: Bash, Read, Write, Edit
---

# Epic Verify — Resume

Resume an aborted or interrupted epic verification from the last iteration.

## Usage
```
/pm:epic-verify-resume <epic-name>
```

## Instructions

### 1. Check State

```bash
EPIC_NAME="$ARGUMENTS"
STATE_FILE=".gemini/context/verify/epic-state.json"
```

Read the state file.

**If `active_epic` is non-null and matches `$ARGUMENTS`:**
- Verification is still active (possibly from a crashed session)
- Continue from current state

**If `active_epic` is null but `last_abort` exists and matches `$ARGUMENTS`:**
- Verification was explicitly aborted
- Can resume from abort point

**If neither:**
```
❌ No verification state found for epic '$ARGUMENTS'.
   Start new: /pm:epic-verify $ARGUMENTS
```
Stop here.

### 2. Restore State

If resuming from abort, re-initialize the state using the abort record:

```bash
bash .gemini/scripts/pm/lifecycle-helpers.sh init-epic-verify-state "$EPIC_NAME" "{phase_a_report_from_abort_or_latest}"
```

Then update the iteration count to where it was aborted:
- Read the newly initialized state
- Set `current_iteration` to the value from `last_abort.iteration_at_abort`
- Write back the updated state

If resuming from active (crashed session), no state changes needed.

### 3. Show Resume Info

```
═══ Resuming Epic Verification ═══

Epic:         {epic_name}
Phase:        B
Resuming at:  Iteration {current_iteration}/{max_iterations}
Mode:         {verify_mode}
Phase A:      {phase_a_report}
Ralph Hook:   ✅ Reactivated

Previous iterations:
  {compact iteration history if any}
```

### 4. Continue Phase B

Read and execute Phase B instructions from `.gemini/commands/pm/epic-verify-b.md`, but skip steps that have already been completed:
- Skip test writing (tests should already exist)
- Skip state initialization (already restored)
- Run verification from current iteration
- Enter fix loop if tests fail

```bash
bash .gemini/context/verify/epic-verify.sh "$EPIC_NAME"
```

Display results and follow Phase B's result handling logic.

## Error Handling

- No arguments → "❌ Usage: /pm:epic-verify-resume <epic-name>"
- No state to resume → Clear message with alternatives
- Phase A report missing → "❌ Phase A report not found. Run /pm:epic-verify $ARGUMENTS to start fresh."
- epic-verify.sh missing → "❌ epic-verify.sh not found"
