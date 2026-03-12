---
model: opus
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Run

Automate full epic execution: plan → execute → verify. Auto-continues between tasks (AD-4).

## Usage
```
/pm:epic-run <epic_name> [flags]
```

**Flags:**
- `--dry-run` — show execution plan without executing any tasks
- `--sequential` — force all tasks to run sequentially (disable parallel)
- `--confirm` — pause for user confirmation between each task
- `--start-from <task-id>` — skip tasks before specified task ID
- `--max-parallel N` — override max concurrent agents (default from config)
- `--model-override <model>` — force all tasks to use specified model

## Preflight

Run these checks and **stop immediately** if any fail:

```bash
# 1. Validate arguments
[ -z "$ARGUMENTS" ] && { echo "❌ Usage: /pm:epic-run <epic_name> [flags]"; exit 1; }

# 2. Extract epic name (first argument) and flags
epic_name=$(echo "$ARGUMENTS" | awk '{print $1}')

# 3. Epic must exist
test -f .gemini/epics/$epic_name/epic.md || { echo "❌ Epic not found. Run: /pm:prd-parse $epic_name"; exit 1; }

# 4. Must be synced to GitHub
grep -q '^github:' .gemini/epics/$epic_name/epic.md || { echo "❌ Epic not synced. Run: /pm:epic-sync $epic_name"; exit 1; }

# 5. Must be on epic branch
current_branch=$(git branch --show-current)
if [ "$current_branch" != "epic/$epic_name" ]; then
  echo "❌ Not on epic branch. Run: /pm:epic-start $epic_name"
  exit 1
fi
```

## Flag Parsing

Parse flags from `$ARGUMENTS` after the epic name:

```bash
# Defaults
flag_dry_run=false
flag_sequential=false
flag_confirm=false
flag_start_from=""
flag_max_parallel=""
flag_model_override=""

# Parse flags
shift_args=$(echo "$ARGUMENTS" | cut -d' ' -f2-)
while [ -n "$shift_args" ]; do
  flag=$(echo "$shift_args" | awk '{print $1}')
  case "$flag" in
    --dry-run)      flag_dry_run=true ;;
    --sequential)   flag_sequential=true ;;
    --confirm)      flag_confirm=true ;;
    --start-from)   flag_start_from=$(echo "$shift_args" | awk '{print $2}'); shift_args=$(echo "$shift_args" | cut -d' ' -f2-) ;;
    --max-parallel) flag_max_parallel=$(echo "$shift_args" | awk '{print $2}'); shift_args=$(echo "$shift_args" | cut -d' ' -f2-) ;;
    --model-override) flag_model_override=$(echo "$shift_args" | awk '{print $2}'); shift_args=$(echo "$shift_args" | cut -d' ' -f2-) ;;
    --*)            echo "⚠️ Unknown flag: $flag (ignoring)" ;;
    *)              break ;;
  esac
  shift_args=$(echo "$shift_args" | cut -d' ' -f2-)
done
```

**Use `$epic_name` instead of `$ARGUMENTS`** for all epic references below.

## Instructions

### Step 1: Generate Execution Plan

Run the plan generation script:
```bash
bash .gemini/scripts/pm/epic-run-plan.sh $epic_name
```

Parse the output:
- **Header lines** (starting with `#`): extract total, ready, blocked, closed counts
- **Data lines**: pipe-delimited format `STATUS|TASK_NUM|NAME|MODEL|PHASE|DEPENDS_ON|GITHUB|PARALLEL`

**If no READY tasks and no BLOCKED tasks:**
```
✅ All tasks complete for epic: $epic_name
→ Run: /pm:epic-verify $epic_name
```
Stop execution.

**If no READY tasks but BLOCKED tasks exist:**
```
❌ No tasks ready — all remaining tasks are blocked.
Blocked tasks:
  #XX - Task name (blocked by: deps)
→ Check: /pm:epic-status $epic_name
```
Stop execution.

### Step 2: Apply `--start-from` Filter

If `flag_start_from` is set, filter out READY tasks with task number < `flag_start_from`:
- Remove those tasks from the READY list
- Display: `⏩ Skipping tasks before #${flag_start_from}`
- If `flag_start_from` doesn't match any task, warn: `⚠️ Task #${flag_start_from} not found, starting from beginning`

### Step 3: Display Execution Plan

Present the plan as a table. If `flag_model_override` is set, show the override model instead of task-specific models:
```
📋 Execution Plan: $epic_name

| # | Task | Model | Phase | Status |
|---|------|-------|-------|--------|
| 75 | Build epic-run... | opus | 2 | ✅ Ready |
| 76 | Add parallel... | opus | 3 | 🔒 Blocked |
| 77 | Add flags... | sonnet | 3 | 🔒 Blocked |

Ready: {ready_count} | Blocked: {blocked_count} | Closed: {closed_count}/{total_count}
{if flags active: "Flags: --dry-run --sequential ..."}
```

**If `flag_dry_run` is true:** Display the plan and stop execution immediately:
```
🏁 Dry run complete — no tasks executed.
```

### Step 4: Auto-Proceed (AD-4)

**Do NOT ask for confirmation** (unless `--confirm` flag is set). Begin execution immediately after displaying the plan.

Record the epic-run start time:
```bash
epic_start_time=$(date +%s)
```

### Step 5: Execution Engine

#### 5a. Load Config and Apply Flag Overrides

```bash
max_parallel=3
graceful_degradation=true
model_override=""
skip_verification=false
if [ -f .gemini/config/epic-run.json ]; then
  max_parallel=$(grep -o '"max_parallel": *[0-9]*' .gemini/config/epic-run.json | grep -o '[0-9]*')
  graceful_degradation=$(grep -o '"graceful_degradation": *[a-z]*' .gemini/config/epic-run.json | grep -o '[a-z]*$')
  model_override=$(grep -o '"model_override": *"[^"]*"' .gemini/config/epic-run.json | grep -o '"[^"]*"$' | tr -d '"')
  skip_verification=$(grep -o '"skip_verification": *[a-z]*' .gemini/config/epic-run.json | grep -o '[a-z]*$')
fi
[ -z "$max_parallel" ] && max_parallel=3
[ -z "$graceful_degradation" ] && graceful_degradation=true
[ -z "$skip_verification" ] && skip_verification=false

# Flag overrides (CLI > config > defaults)
[ -n "$flag_max_parallel" ] && max_parallel=$flag_max_parallel
[ -n "$flag_model_override" ] && model_override=$flag_model_override
[ "$flag_sequential" = "true" ] && max_parallel=1

# Context management config
sequential_subagent=true
max_result_length=500
warn_after_tasks=15
completed_count=0
if [ -f .gemini/config/epic-run.json ]; then
  seq_sub=$(grep -o '"sequential_subagent": *[a-z]*' .gemini/config/epic-run.json | grep -o '[a-z]*$')
  max_len=$(grep -o '"max_result_length": *[0-9]*' .gemini/config/epic-run.json | grep -o '[0-9]*')
  warn_n=$(grep -o '"warn_after_tasks": *[0-9]*' .gemini/config/epic-run.json | grep -o '[0-9]*')
  [ -n "$seq_sub" ] && sequential_subagent=$seq_sub
  [ -n "$max_len" ] && max_result_length=$max_len
  [ -n "$warn_n" ] && warn_after_tasks=$warn_n
fi
```

#### 5b. Group Ready Tasks into Execution Units

From the plan output, group READY tasks into **execution units**:

1. Collect all READY tasks, ordered by phase then task number
2. **If `flag_sequential` is true or `max_parallel` is 1:** Skip parallel detection — all tasks become sequential units
3. **Parallel group detection:** Within the same phase, collect READY tasks where `PARALLEL=true` (8th field in plan output)
4. **File conflict check:** For each parallel candidate group:
   - Read each task file (`.gemini/epics/{epic}/{num}.md`) and extract `files:` and `conflicts_with:` frontmatter arrays
   - Build a map of file → task assignments
   - If two tasks list the same file in `files:`, or one task appears in another's `conflicts_with:`, move the later task to its own sequential unit
   - Example: Task A has `files: [commands/pm/epic-run.md]`, Task B also has it → B becomes sequential
5. **Size limit:** If a parallel group exceeds `max_parallel`, split into sub-groups of `max_parallel` size
6. Single-task groups or `PARALLEL=false` tasks → sequential unit

Display the grouping:
```
📦 Execution groups:
  Group 1: #{num} (sequential, {model})
  Group 2: #{a}, #{b}, #{c} (parallel, 3 tasks)
```

#### 5c. Execute Each Unit

Record start time per unit:
```bash
unit_start_time=$(date +%s)
```

**If `model_override` is set:** Use `model_override` instead of the task's `MODEL` field for all tasks in this unit.

**Path A — Sequential (single task or PARALLEL=false):**

Display: `⏳ [{current}/{total_ready}] Starting: #{task_num} - {task_name} ({effective_model})`

**If `sequential_subagent` is true (default):** Spawn the task as a subagent to isolate context:

```yaml
Task:
  description: "Epic-run: #{task_num} {task_name}"
  subagent_type: "general-purpose"
  model: "{effective_model}"
  prompt: |
    You are executing task #{task_num} for epic '{epic_name}'.

    ## Task
    Read the full task file:
    ```bash
    cat .gemini/epics/{epic_name}/{task_num}.md
    ```

    ## Context
    Read handoff from previous task:
    ```bash
    cat .gemini/context/handoffs/latest.md 2>/dev/null || echo "No previous handoff"
    ```

    Read epic context:
    ```bash
    cat .gemini/context/epics/{epic_name}.md 2>/dev/null || echo "No epic context"
    ```

    ## Instructions
    1. Read and understand all acceptance criteria from the task file
    2. Load context from handoff notes — understand what was done before
    3. Implement the required changes
    4. Run verification (tests, lint, build as appropriate)
    5. Write handoff notes to .gemini/context/handoffs/latest.md
       - Include: what was done, decisions made, files changed, warnings for next task
    6. Update task file status — set `status: closed` and `updated` in frontmatter:
       ```bash
       sed -i '' 's/^status: .*/status: closed/' .gemini/epics/{epic_name}/{task_num}.md
       sed -i '' "s/^updated: .*/updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")/" .gemini/epics/{epic_name}/{task_num}.md
       ```
    7. Commit changes: `Issue #{task_num}: {description}`
    8. Close GitHub issue:
       ```bash
       gh issue close {github_issue_num} --repo {REPO} --comment "✅ Completed via epic-run"
       ```
    9. Return a concise summary (max 200 words):
       - Status: success/failure
       - Files changed (list)
       - Key decisions made
       - Any warnings for next task

    ## Rules
    - Follow existing code patterns in the codebase
    - Commit format: `Issue #{task_num}: {description}`
    - Do NOT use the Skill tool — all logic is inlined above (AD-5)
    - Keep your summary concise — it goes back to the orchestration context
```

Truncate the subagent result to `max_result_length` characters before processing.

**Graceful degradation:** If `sequential_subagent` is false or the Task tool fails and `graceful_degradation` is true, fall back to inline execution:

```
Skill: pm:issue-start
Args: {task_num}
```

Follow the skill's instructions: load context, implement the task, write code, run tests. Then:

```
Skill: pm:issue-complete
Args: {task_num}
```

Display: `[{current}/{total_ready}] ✅ #{task_num}: {task_name} ({effective_model}, {duration})`

**Context monitoring:** After each task completes, increment `completed_count`. If `completed_count >= warn_after_tasks`:
```
⚠️ {completed_count} tasks completed in this context. Consider running /clear if performance degrades.
```

**If `flag_confirm` is true:** After each task completion, pause and ask:
```
Task #{task_num} complete. Continue to next task? (yes/skip/abort)
```
- **yes**: Continue to next task
- **skip**: Skip remaining tasks in this unit
- **abort**: Go to completion summary

**Path B — Parallel (2+ tasks, PARALLEL=true, no file conflicts):**

Display: `⏳ [{start}-{end}/{total_ready}] Parallel group: #{a}, #{b}, #{c} ({count} tasks)`

Get the GitHub repo:
```bash
REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo 2>/dev/null || echo "")
```

Spawn **all tasks in the group simultaneously** using multiple Task tool calls in a **single message**. For each task in the parallel group, create a Task call:

```yaml
Task:
  description: "Epic-run: #{task_num} {task_name}"
  subagent_type: "general-purpose"
  isolation: "worktree"
  model: "{effective_model}"  # model_override if set, otherwise from plan's MODEL field
  prompt: |
    You are executing task #{task_num} for epic '{epic_name}'.

    ## Task
    Read the full task file:
    ```bash
    cat .gemini/epics/{epic_name}/{task_num}.md
    ```

    ## Instructions
    1. Read and understand all acceptance criteria from the task file
    2. Implement the required changes in the files listed in the task
    3. Run verification: check that your changes work correctly
    4. Commit your changes:
       ```bash
       git add {relevant_files}
       git commit -m "Issue #{task_num}: {description}"
       ```
    5. Close the GitHub issue:
       ```bash
       gh issue close {github_issue_num} --repo {REPO} --comment "✅ Completed via epic-run (parallel)"
       ```
    6. Return a summary: files modified, what was implemented, any issues

    ## Rules
    - Only modify files listed in the task's `files` field
    - Follow existing code patterns in the codebase
    - Do NOT use the Skill tool — all logic is inlined above (AD-5)
    - Commit format: `Issue #{task_num}: {description}`
```

**Critical:** All Task tool calls for the group MUST be in the **same message** so Gemini CLI executes them concurrently.

Wait for all parallel agents to complete. Collect results.

Display per-task results:
```
  #{a}: ✅ {summary}
  #{b}: ✅ {summary}
  #{c}: ❌ {error}
```

Display group completion:
```
[{start}-{end}/{total_ready}] ✅ Parallel group: #{a}, #{b}, #{c} ({count} tasks, {duration})
```

**Graceful degradation:** If Task tool spawning with `isolation: "worktree"` fails and `graceful_degradation` is `true`:
1. Log: `⚠️ Parallel execution failed, falling back to sequential`
2. Execute the group's tasks one by one using Path A

#### 5d. Re-run Plan After Each Unit

After completing an execution unit, re-run the plan script to discover newly unblocked tasks:
```bash
bash .gemini/scripts/pm/epic-run-plan.sh $epic_name
```

If new READY tasks appeared, group them into execution units (repeat 5b logic) and continue.

### Step 6: Error Handling

**Sequential task failure:**

1. Stop execution immediately
2. Display error:
```
❌ Task #{task_num} failed: {error_description}

Progress so far:
  [{completed}/{total_ready}] tasks completed
  Failed on: #{task_num} - {task_name}
```
3. Ask user:
```
What would you like to do?
  1. Retry this task (retry)
  2. Skip this task and continue (skip)
  3. Abort epic-run (abort)
```

- **retry**: Re-run Path A for the same task
- **skip**: Move to next execution unit
- **abort**: Go to Step 7 with partial results

**Parallel group failure:**

1. Let all running parallel agents complete (don't abort them)
2. Report all results:
```
Parallel group results:
  #{a}: ✅ Done
  #{b}: ❌ Failed: {error}
  #{c}: ✅ Done
```
3. Ask user for action on each failed task: retry (sequentially) / skip / abort

### Step 7: Completion Summary

After all READY tasks are executed (or on abort):

```bash
epic_end_time=$(date +%s)
epic_duration=$((epic_end_time - epic_start_time))
epic_minutes=$((epic_duration / 60))
```

Re-run the plan script one final time to get updated counts:
```bash
bash .gemini/scripts/pm/epic-run-plan.sh $epic_name
```

Display summary:
```
═══════════════════════════════════════
  Epic Run Complete: $epic_name
═══════════════════════════════════════

| # | Task | Model | Duration | Result |
|---|------|-------|----------|--------|
| 75 | Build epic-run... | opus | 5m23s | ✅ Done |
| 76 | Add parallel... | opus | 3m12s | ✅ Done |
| 77 | Add flags... | sonnet | — | 🔒 Blocked |

Total time: {epic_minutes}m
Tasks completed: {completed}/{total}
Tasks remaining: {blocked_count} blocked

Next steps:
  → All done?     /pm:epic-verify $epic_name
  → More tasks?   /pm:epic-run $epic_name (re-run for newly unblocked)
  → Check status: /pm:epic-status $epic_name
```
