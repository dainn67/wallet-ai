---
name: pm-build
description: Build
# tier: heavy
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
| 2 | prd-qualify | no (loop) | medium |
| 3 | prd-parse | no | heavy |
| 4 | plan-review | YES | heavy |
| 5 | epic-decompose | no | heavy |
| 6 | epic-sync | no | medium |
| 7 | epic-start | no | medium |
| 8 | epic-run | YES | medium |
| 9 | epic-verify | no | medium |
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

Output table:
```
Dry Run: {feature_name}

Step  Name             Gate  Tier    Est. Tokens  Status
────  ───────────────  ────  ──────  ───────────  ──────
```

For each step (index 0–9):
- Determine `Status`:
  - If step index < `current_step_idx` → `✅ done`
  - If step index == `current_step_idx` → `▶ next`
  - Else → `⏳ pending`
- Determine `Gate`: step has `"gate": true` → `🚧` else `—`
- Determine `Est. Tokens`: use `tokens_per_tier[tier]` from config; append `budget_note` once in footer
- Print row: `{N}/10  {name:<15}  {gate:<4}  {tier:<6}  ~{tokens:>7,}  {status}`

Footer:
```
Total estimated tokens: ~{sum}{budget_note}
Gates: 4 (prd-new, plan-review, epic-run, epic-merge)
```

Then `exit 0` — do NOT proceed to step execution loop.

### Step 1: Artifact Detection (Skip Completed Steps)

Before executing each step, check if its artifact already exists. If so, skip it and advance state:

**Detection rules:**
- `prd-new`: `.claude/prds/<feature>.md` exists
- `prd-qualify`: PRD file has `status: validated` in frontmatter
- `prd-parse`: `.claude/epics/<feature>/epic.md` exists
- `plan-review`: `.claude/epics/<feature>/plan-review.md` exists OR task files exist
- `epic-decompose`: task files (`[0-9]*.md`) exist in `.claude/epics/<feature>/`
- `epic-sync`: epic frontmatter `github` field is non-empty
- `epic-start`: current git branch is `epic/<feature>`
- `epic-run`: all tasks in epic have `status: closed`
- `epic-verify`: `.claude/epics/<feature>/verify-report.md` exists
- `epic-merge`: epic frontmatter has `status: completed`

For each step from `current_step_idx` to end:

```bash
# Example check for prd-new
if [ -f ".claude/prds/${feature_name}.md" ]; then
  echo "[1/10] ⏭ prd-new (already complete)"
  source scripts/pm/build-state.sh && advance_step "$feature_name"
  continue
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

```
loop_count=0
max_loop=5

while loop_count < max_loop:
  1. Invoke Skill("pm:prd-edit", args=feature_name)
  2. Invoke Skill("pm:prd-validate", args=feature_name)
  3. Check validation result
     - If passes → break loop
     - If fails → increment loop_count, continue
  4. If loop_count >= max_loop → warn user, break

Display: "[2/10] 🔄 prd-qualify — iteration {loop_count}/{max_loop}"
```

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
| 1 | prd-new | ✅ | 2:15 |
| 2 | prd-qualify | ✅ | 5:30 |
| ... | ... | ... | ... |

Total time: {total_min}m
Steps completed: {completed}/{10}

{if all complete}
🎉 Feature shipped! Check your PR.

{if aborted/partial}
Resume later: /pm:build {feature_name} --resume
```

## Important Notes

- This command is the **single entry point** for shipping features. It replaces manually running 11 commands.
- State persists via `scripts/pm/build-state.sh` — safe to interrupt and resume.
- Gates are mandatory checkpoints where human judgment is required. Use `--no-gate` only when confident.
- Each step delegates to existing pm commands via the Skill tool, keeping the orchestrator thin.
- The prd-qualify loop is the only step with iteration logic (edit → validate cycle).
