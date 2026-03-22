---
model: opus
name: build
description: Full workflow orchestrator — ships a feature from idea to merge
allowed-tools: Bash, Skill, Read, Write, Edit, Glob, Grep, Agent
---

# Build

Orchestrate the full feature-shipping workflow: prd-new → prd-qualify → prd-parse → plan-review → epic-decompose → epic-sync → epic-start → epic-run → epic-verify → epic-merge. Pauses at 4 mandatory gates for human judgment.

## Usage
```
/pm:build <feature-name> [flags]
```

**Flags:**
- `--resume` — resume from last saved state (continues from `current_step + 1`)
- `--dry-run` — show planned steps with gate positions and token estimates; does NOT execute
- `--no-gate=<gate>` — skip specified gate (can repeat: `--no-gate=plan-review --no-gate=epic-merge`)

## Preflight

```bash
# 1. Validate arguments
[ -z "$ARGUMENTS" ] && { echo "❌ Usage: /pm:build <feature-name> [flags]"; exit 1; }

# 2. Extract feature name and flags
feature_name=$(echo "$ARGUMENTS" | awk '{print $1}')

# 3. Validate kebab-case
echo "$feature_name" | grep -qE '^[a-z][a-z0-9-]*[a-z0-9]$' || { echo "❌ Feature name must be kebab-case. Got: '$feature_name'"; exit 1; }
```

## Flag Parsing

```bash
no_gates=()
flag_resume=false
flag_dry_run=false
shift_args=$(echo "$ARGUMENTS" | cut -d' ' -f2-)
while [ -n "$shift_args" ]; do
  flag=$(echo "$shift_args" | awk '{print $1}')
  case "$flag" in
    --no-gate=*) no_gates+=("${flag#--no-gate=}") ;;
    --resume)    flag_resume=true ;;
    --dry-run)   flag_dry_run=true ;;
    --*)         echo "⚠️ Unknown flag: $flag (ignoring)" ;;
    *)           break ;;
  esac
  shift_args=$(echo "$shift_args" | cut -d' ' -f2-)
done
```

## Workflow Definition

Load workflow config and state:

```bash
source scripts/pm/build-state.sh

# --resume: require existing state; fail clearly if missing
if [ "$flag_resume" = "true" ]; then
  state_json=$(load_state "$feature_name" 2>&1) || {
    echo "❌ No build state found for '$feature_name'. Start with: pm:build $feature_name"
    exit 1
  }
else
  # Normal start: load existing state or initialize fresh
  state_json=$(load_state "$feature_name" 2>/dev/null) || {
    init_state "$feature_name"
    state_json=$(load_state "$feature_name")
  }
fi
```

The 10-step workflow from `config/build.json`:

| # | Step | Gate | Tier |
|---|------|------|------|
| 1 | prd-new | YES | heavy |
| 2 | prd-qualify | no (loop) | heavy |
| 3 | prd-parse | no | heavy |
| 4 | plan-review | YES | heavy |
| 5 | epic-decompose | no | heavy |
| 6 | epic-sync | no | medium |
| 7 | epic-start | no | medium |
| 8 | epic-run | YES | heavy |
| 9 | epic-verify | no | heavy |
| 10 | epic-merge | YES | medium |

## Instructions

### Step 0: Determine Start Point

Get the current step from state:

```bash
current_step_idx=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['current_step'])" "$state_json")
```

If `--resume` is set, display resume summary and continue from the recorded step:
```
Resuming '{feature_name}' from step [{current_step_idx + 1}/10]: {step_name}
```

If `current_step_idx >= 10`, display "Build already complete for '{feature_name}'" and exit.

Record the overall start time:
```bash
build_start_time=$(date +%s)
```

### Step 0b: Dry Run (if --dry-run)

If `flag_dry_run` is `true`, output the planned workflow and exit WITHOUT executing any step:

```bash
config_json=$(cat config/build.json)
```

Extract `tokens_per_tier` from config. Check if `scripts/pm/budget.sh` exists:
```bash
budget_note=""
[ ! -f "scripts/pm/budget.sh" ] && budget_note=" (N/A — budget script not available)"
```

Output table with columns: `Step  Name  Gate  Tier  Est. Tokens  Status`

For each step (index 0–9): Status = `✅ done` / `▶ next` / `⏳ pending`; Gate = `🚧` if `"gate": true` else `—`; Tokens from `tokens_per_tier[tier]` in config.
Print row: `{N}/10  {name:<15}  {gate:<4}  {tier:<6}  ~{tokens:>7,}  {status}`

Footer: `Total estimated tokens: ~{sum}{budget_note}` / `Gates: 4 (prd-new, plan-review, epic-run, epic-merge)`

Then `exit 0` — do NOT proceed to step execution loop.

### Step 1: Artifact Detection (Skip Completed Steps)

Before executing each step, check if its artifact already exists. If so, skip it and advance state:

**Detection rules:**
- `prd-new`: `.claude/prds/<feature>.md` exists
- `prd-qualify`: PRD file has `status: validated` in frontmatter AND `.claude/prds/.validation-<feature>.md` exists with `status: passed` in frontmatter
- `prd-parse`: `.claude/epics/<feature>/epic.md` exists
- `plan-review`: `.claude/epics/<feature>/plan-review.md` exists AND frontmatter `verdict:` is NOT `blocked`
- `epic-decompose`: task files (`[0-9]*.md`) exist in `.claude/epics/<feature>/`
- `epic-sync`: epic frontmatter `github` field is non-empty
- `epic-start`: current git branch is `epic/<feature>`
- `epic-run`: all tasks in epic have `status: closed`
- `epic-verify`: `.claude/epics/<feature>/verify-report.md` exists AND report contains `## .*QA.*Results` section
- `epic-merge`: epic frontmatter has `status: completed`

For each step from `current_step_idx` to end:

```bash
# Example check for prd-new
if [ -f ".claude/prds/${feature_name}.md" ]; then
  echo "[1/10] ⏭ prd-new (already complete)"
  source scripts/pm/build-state.sh && advance_step "$feature_name"
  continue
fi

# Enhanced: check existence AND quality (prd-qualify example)
if [ -f ".claude/prds/${feature_name}.md" ]; then
  status=$(grep '^status:' ".claude/prds/${feature_name}.md" | head -1 | awk '{print $2}')
  val_status=""
  if [ -f ".claude/prds/.validation-${feature_name}.md" ]; then
    val_status=$(grep '^status:' ".claude/prds/.validation-${feature_name}.md" | head -1 | awk '{print $2}')
  fi
  if [ "$status" = "validated" ] && [ "$val_status" = "passed" ]; then
    echo "[2/10] ⏭ prd-qualify (already complete)"
    source scripts/pm/build-state.sh && advance_step "$feature_name"
    continue
  fi
fi
```

### Step 2: Gate Check

Before executing a gate step, display the gate summary and ask for user input.

**Gate steps:** prd-new, plan-review, epic-run, epic-merge

Check if gate is in `--no-gate` list → auto-proceed if yes.

Gate display format:
```
═══════════════════════════════════════
🚧 GATE: {step-name}
═══════════════════════════════════════
Completed: {list of completed steps with ✅}
Next: {current step} → {remaining steps}

Proceed? (yes / skip / abort)
```

- **yes** → execute the step
- **skip** → advance state, skip execution, continue to next step
- **abort** → save state, display progress summary, exit

### Step 3: Execute Step

Display progress before execution:
```
[{N}/10] ▶ {step-name} (0:00)
```

Record step start time:
```bash
step_start=$(date +%s)
```

#### Regular Steps

Invoke the corresponding command via Skill tool:

```
Skill: pm:{step-name}
Args: {feature_name}
```

#### Special: prd-qualify Loop

The prd-qualify step loops prd-edit → prd-validate up to `max_loop` times (5 from config):

Record loop start time and PRD hash before loop begins:
```bash
loop_start=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
prd_hash_before=$(md5 -q ".claude/prds/${feature_name}.md" 2>/dev/null || md5sum ".claude/prds/${feature_name}.md" 2>/dev/null | awk '{print $1}')
```

```
loop_count=0
max_loop=5

while loop_count < max_loop:
  1. Invoke Skill("pm:prd-edit", args=feature_name)
  2. Invoke Skill("pm:prd-validate", args=feature_name)
  3. Post-condition check (after each prd-validate iteration):

     a. Validation report freshness:
     ```bash
     val_report=".claude/prds/.validation-${feature_name}.md"
     if [ -f "$val_report" ]; then
       report_date=$(grep '^date:' "$val_report" | head -1 | awk '{print $2}')
       # If report_date < loop_start → treat iteration as failed (stale report)
     fi
     ```
     If report is stale or missing → treat iteration as failed.

     b. Suspicious first-pass detection (iteration 1 only):
     If loop_count == 1 AND validation report has `status: passed` AND "Critical Issues"
     section contains "None" AND "Warnings" section contains "None":
     ```
     ⚠️ Suspicious: 0 findings on first validation. Re-running validation...
     ```
     Trigger one additional Skill("pm:prd-validate") pass. Accept result of re-run regardless.

     c. PRD modification check:
     ```bash
     prd_hash_after=$(md5 -q ".claude/prds/${feature_name}.md" 2>/dev/null || md5sum ".claude/prds/${feature_name}.md" 2>/dev/null | awk '{print $1}')
     ```
     If prd_hash_before == prd_hash_after AND validation status != passed → warn:
     ```
     ⚠️ PRD was not modified during prd-edit, but validation found issues. Edits may not have been applied.
     Options: (1) Re-run prd-edit, (2) Skip and proceed
     ```
     Ask user; proceed based on response.

  4. Check validation result
     - If passes → break loop
     - If fails → increment loop_count, continue
  5. If loop_count >= max_loop → warn user, break

Display: "[2/10] 🔄 prd-qualify — iteration {loop_count}/{max_loop}"
```

#### Post-loop verification (prd-qualify):

After the loop exits (by pass or max iterations), verify final validation state:

```bash
val_report=".claude/prds/.validation-${feature_name}.md"
```

- If `val_report` doesn't exist → enter failure menu (treat as step failure)
- If `status:` in val_report is not `passed` → warn and ask: proceed anyway or re-run
- If all checks pass → mark prd-qualify as complete and advance

#### Special: Plan-review Apply (between step 4 and step 5)

After plan-review completes (step 4), apply its findings to epic.md before decompose (step 5):

1. Read plan-review frontmatter:
```bash
review_file=".claude/epics/${feature_name}/plan-review.md"
if [ -f "$review_file" ]; then
  verdict=$(grep '^verdict:' "$review_file" | head -1 | awk '{print $2}')
  critical=$(grep '^critical_gaps:' "$review_file" | head -1 | awk '{print $2}')
  warnings=$(grep '^warnings:' "$review_file" | head -1 | awk '{print $2}')
else
  # plan-review.md doesn't exist (step was skipped) — skip apply and proceed
  verdict="skip"
fi
```

2. **If verdict is empty/missing** → default to `ready-with-warnings` (fail-safe).

3. **If verdict is `blocked`:**
```
❌ Plan-review verdict: BLOCKED
{Display critical issues from plan-review.md}

Options:
  → fix:   Fix the issues, then resume (pm:build {feature_name} --resume)
  → skip:  Skip plan-review apply and continue to decompose
  → abort: Stop the build
```
Wait for user choice. Handle like existing failure menu.

4. **If verdict is `ready` with critical_gaps=0 AND warnings=0:**
```
[4/10] ✅ plan-review — READY (0 issues, skipping apply)
```
Proceed directly to decompose.

5. **If verdict is `ready-with-warnings` OR warnings > 0:**

Record epic.md hash before apply:
```bash
epic_hash_before=$(md5 -q ".claude/epics/${feature_name}/epic.md" 2>/dev/null || md5sum ".claude/epics/${feature_name}/epic.md" 2>/dev/null | awk '{print $1}')
```

Read the full `plan-review.md` content. Apply all recommended changes from the review to `epic.md`:
- Architecture Decision corrections
- Task breakdown adjustments
- Failure mode additions
- Dependency updates
- Any other specific recommendations

After applying, verify changes:
```bash
epic_hash_after=$(md5 -q ".claude/epics/${feature_name}/epic.md" 2>/dev/null || md5sum ".claude/epics/${feature_name}/epic.md" 2>/dev/null | awk '{print $1}')
```

6. **If epic_hash_before == epic_hash_after** (no changes made):
```
⚠️ Plan-review had {warnings} warnings but epic.md was not modified.
Options:
  → proceed: Continue to decompose without changes
  → retry:   Re-read plan-review and try applying again
```
Wait for user choice.

7. **If changes were made:**
```
[4/10] ✅ plan-review — applied {N} changes to epic.md
```
Proceed to decompose.

### Step 4: Handle Result

**On success:**
```bash
step_end=$(date +%s)
elapsed=$((step_end - step_start))
minutes=$((elapsed / 60))
seconds=$((elapsed % 60))
```

Display:
```
[{N}/10] ✅ {step-name} ({minutes}:{seconds formatted as 2 digits})
```

Advance state:
```bash
source scripts/pm/build-state.sh && advance_step "$feature_name"
```

**On failure — transient vs permanent:**

When a step fails, inspect the error output for transient error keywords:
- Transient keywords: `network`, `rate limit`, `ECONNREFUSED`, `lock`, `timeout`

**Transient error → retry once automatically:**
```
⚠️ Transient error detected in '{step-name}', retrying...
```
Re-invoke the same step. If retry succeeds → continue normally.

If retry also fails (or error is non-transient) → pause with failure menu:

Display:
```
[{N}/10] ❌ {step-name} — {error summary (first 200 chars of error output)}

Options:
  → fix:   Fix the issue, then resume (pm:build {feature_name} --resume)
  → skip:  Skip this step and continue
  → abort: Stop the build
```

- **fix** → save state, display current progress, exit (user resumes via `--resume`)
- **skip** → advance state, continue to next step
- **abort** → save state, exit with summary

### Step 5: Completion Summary

After all 10 steps complete (or on abort):

```bash
build_end=$(date +%s)
total_elapsed=$((build_end - build_start_time))
total_min=$((total_elapsed / 60))
```

Display:
```
═══════════════════════════════════════
  Build Complete: {feature_name}
═══════════════════════════════════════

| # | Step | Status | Duration |
|---|------|--------|----------|
| {N} | {name} | {✅/❌/⏭} | {m:ss} |

Total time: {total_min}m  |  Steps completed: {completed}/10
🎉 Feature shipped! Check your PR.    {if all complete}
Resume later: /pm:build {feature_name} --resume    {if partial}
```

## Important Notes

- Single entry point for shipping features. State persists via `scripts/pm/build-state.sh` — safe to interrupt and resume.
- Gates are mandatory checkpoints. Use `--no-gate` only when confident.
- Each step delegates to existing pm commands via Skill tool. prd-qualify is the only step with iteration logic.

#### Special: Delegation Guards

When delegating complex steps to subagents (due to context pressure or parallel work),
follow the delegation protocol in `rules/delegation-protocol.md`.

For epic-verify specifically, the subagent prompt MUST include:
1. "Read and follow `.claude/commands/pm/epic-verify.md`"
2. "Read and follow `.claude/commands/pm/epic-verify-a.md`"
3. "Read and follow `.claude/commands/pm/epic-verify-b.md` (includes Step 8: QA Agent Tier)"
4. "Execute ALL steps as written. Do NOT summarize or skip sub-steps."

Do NOT summarize command file content in the agent prompt.

#### Post-condition: QA completeness check (after epic-verify)

After epic-verify completes, verify QA Agent Tier was executed:

```bash
# Locate verify report — try final report first, then verify-report.md
report_file=$(ls -t .claude/context/verify/epic-reports/${feature_name}-final-*.md 2>/dev/null | head -1)
if [ -z "$report_file" ]; then
  report_file=".claude/epics/${feature_name}/verify-report.md"
fi

if [ -f "$report_file" ]; then
  if grep -q "## .*QA.*Results" "$report_file"; then
    echo "✅ QA Agent Tier verified in report"
  else
    echo "QA_MISSING"
  fi
else
  echo "REPORT_MISSING"
fi
```

**If QA_MISSING:**
```
⚠️ QA Agent Tier was not executed during epic-verify.
   The verify report does not contain a QA Results section.

Options:
  → qa:    Run /qa:run now to execute QA checks
  → skip:  Skip QA and proceed to epic-merge
```
Wait for user choice.
- If `qa` → invoke `Skill("qa:run", args=feature_name)`, then re-check report
- If `skip` → proceed without QA

**If REPORT_MISSING:**
```
⚠️ No verify report found after epic-verify.
   Expected: .claude/context/verify/epic-reports/${feature_name}-final-*.md
   or: .claude/epics/${feature_name}/verify-report.md

This may indicate epic-verify did not complete successfully.
Options:
  → retry: Re-run epic-verify
  → skip:  Skip verification and proceed
```
Wait for user choice.
