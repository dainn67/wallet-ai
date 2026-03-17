---
model: sonnet
allowed-tools: Bash, Read
---

# Verify Run

Manually trigger the verification profile for the current active task.

## Usage
```
/pm:verify-run
```

## Instructions

### 1. Check Active Task

Read `.claude/context/verify/state.json`.

If no active task:
```
❌ No active task. Run /pm:issue-start <number> first.
```

### 2. Get Profile Path

```bash
source .claude/scripts/pm/lifecycle-helpers.sh
tech_stack=$(read_verify_state | jq -r '.active_task.tech_stack' 2>/dev/null || echo "generic")
profile=$(get_verify_profile "$tech_stack")
echo "Profile: $profile"
```

If profile doesn't exist, fall back to `.claude/context/verify/profiles/generic.sh`.

### 3. Run Profile

```bash
bash "$profile" .
```

Display the full output to the user.

### 4. Log Result

Append the run to `.claude/context/verify/results/task-{issue_number}-verify.log` with timestamp.

### 5. Report

- If VERIFY_PASS: "✅ Verification passed! Run /pm:issue-complete <number> to complete."
- If VERIFY_SKIP: "⏭️ Some checks skipped. Review output above."
- If VERIFY_FAIL: see Step 6 below.

Next: /pm:issue-complete <number> (if passed) or fix issues and /pm:verify-run (if failed)

**Important:** This command does NOT block or loop. It runs once and reports the result.

### 6. On VERIFY_FAIL: Reflection & Retry (ace-learning)

Run only when the verification result is VERIFY_FAIL.

```bash
source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null || true
if command -v ace_feature_enabled &>/dev/null && ace_feature_enabled "reflection" 2>/dev/null; then
  # Get task context
  epic=$(read_verify_state 2>/dev/null | jq -r '.active_task.epic // empty' 2>/dev/null || echo "")
  issue=$(read_verify_state 2>/dev/null | jq -r '.active_task.issue // empty' 2>/dev/null || echo "")

  if [ -n "$epic" ] && [ -n "$issue" ]; then
    # Generate reflection
    source .claude/scripts/pm/reflection-generate.sh 2>/dev/null || true
    if command -v generate_reflection &>/dev/null; then
      reflection_file=$(generate_reflection "$epic" "$issue" 2>/dev/null || echo "")
    fi

    # Check retry count vs max
    max_retries=$(read_ace_config "reflection" "max_retries" "2" 2>/dev/null || echo "2")
    attempt=$(get_attempt_number "$epic" "$issue" 2>/dev/null || echo "1")
    prev_attempt=$((attempt - 1))
  fi
fi
```

**Display to user:**
```
❌ Verification failed.

## Reflection (Attempt {prev_attempt})
[Show "What failed" and "Approach change for next attempt" sections from reflection file]

Retries used: {prev_attempt}/{max_retries}
```

**Present options (if retries available, i.e. prev_attempt < max_retries):**
```
What would you like to do?
  [retry]  — Re-attempt with reflection context injected (recommended)
  [manual] — Take over manually (reflection saved as reference)
  [skip]   — Mark task needs-attention and move on
```

**On [retry]:**
1. Source injection scripts and inject into context (cap at 300 tokens for reflection):
   - Task acceptance criteria from task file
   - Reflection approach change section
   - Relevant skillbook entries (if available, via `inject_relevant_skills`)
2. Re-run implementation with the enriched context.
3. If retry succeeds (VERIFY_PASS): call `extract_learnings` with the reflection as context candidate (pitfall+resolution pattern).
4. If retry also fails: increment attempt, loop back to Step 6 (up to max_retries).

**On [manual]:** Show reflection file path and stop. User takes over.

**On [skip] or max retries exhausted:**
```bash
if command -v ace_log &>/dev/null; then
  ace_log "RETRY" "task=$issue exhausted max_retries=$max_retries"
fi
```
Show: "⚠️ Task marked needs-attention. Review: .claude/epics/{epic}/reflections/"

**If reflection disabled or error:** Fall back to standard failure message:
```
❌ Verification failed. Fix the issues above and run /pm:verify-run again.
```
