---
model: sonnet
allowed-tools: Bash, Read
---

# Verify Status

Display current verification state for the active task.

## Usage
```
/pm:verify-status
```

## Instructions

### 1. Read State File

Read `.gemini/context/verify/state.json`.

If the file doesn't exist or `active_task` is null:
```
No active verification task.
Run /pm:issue-start <number> to begin a task.
```

### 2. Display State

Format the output:

```
═══ Verification Status ═══

Task:       #{issue_number}
Epic:       {epic}
Type:       {type}
Mode:       {verify_mode}
Stack:      {tech_stack}
Profile:    {verify_profile}
Iterations: {current_iteration}/{max_iterations}
Started:    {started_at}

Last Result: {last iteration result or "No runs yet"}
```

### 3. Show Iteration History

If there are iterations, show the last 5:

```
Recent Iterations:
  #{N}: {result} at {timestamp}
  #{N-1}: {result} at {timestamp}
  ...
```

### 4. Suggest Next Steps

Based on current state:
- If last result is VERIFY_FAIL: "Run /pm:verify-run to retry or /pm:verify-skip <reason> to bypass"
- If last result is VERIFY_PASS: "Verification passed. Run /pm:issue-complete <number> to complete"
- If no runs: "Run /pm:verify-run to trigger verification"
