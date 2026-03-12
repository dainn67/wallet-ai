---
name: pm-epic-verify-status
description: Epic Verify — Status
# tier: medium
---

# Epic Verify — Status

Display the current epic verification state from `epic-state.json`.

## Usage
```
/pm:epic-verify-status <epic-name>
```

## Instructions

### 1. Read State

```bash
EPIC_NAME="$EPIC_NAME"
STATE_FILE=".gemini/context/verify/epic-state.json"
```

Read the state file. If it doesn't exist or `active_epic` is null:
```
No active verification for epic '$EPIC_NAME'.

Last reports:
  Run: /pm:epic-verify-history $EPIC_NAME to see past runs.
Start new:
  Run: /pm:epic-verify $EPIC_NAME
```

### 2. Check Epic Match

Verify the `active_epic.epic_name` matches `$EPIC_NAME`. If not:
```
⚠️ Active verification is for epic '{active_epic_name}', not '$EPIC_NAME'.

Active: /pm:epic-verify-status {active_epic_name}
History: /pm:epic-verify-history $EPIC_NAME
```

### 3. Display Status

Extract fields from `epic-state.json` and display:

```
═══ Epic Verify Status ═══

Epic:         {epic_name}
Phase:        {phase} (A/B/Complete)
Mode:         {verify_mode} (STRICT/RELAXED)
Iteration:    {current_iteration}/{max_iterations}
Mid-clear at: {mid_clear_at}
Started:      {started_at}
Phase A:      {phase_a_report or "N/A"}

Last iteration:
  Result: {last iteration result or "No iterations yet"}
  Time:   {last iteration timestamp}

Ralph Hook: {✅ Active / ❌ Inactive}
```

To determine Ralph Hook status, check if `active_epic` is non-null (active = hook is armed).

### 4. Show Iteration History (if any)

If there are iterations in the `iterations` array, show a compact table:

```
Iteration History:
  #1  FAIL     2026-02-20T10:00:00Z  failures: test_a, test_b
  #2  FAIL     2026-02-20T10:15:00Z  failures: test_b
  #3  PASS     2026-02-20T10:30:00Z  —
```

## Error Handling

- No arguments → "❌ Usage: /pm:epic-verify-status <epic-name>"
- State file missing → Show "no active verification" message
- JSON parse error → "❌ Cannot parse epic-state.json: {error}"
