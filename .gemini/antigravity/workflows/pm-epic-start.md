---
name: pm-epic-start
description: Epic Start
# tier: heavy
---

# Epic Start

Create a branch and set up epic for task execution.

## Usage
```
/pm:epic-start <epic_name>
```

## Preflight

Run these checks and **stop immediately** if any fail:

```bash
# 1. Epic must exist
test -f .gemini/epics/$EPIC_NAME/epic.md || { echo "❌ Epic not found. Run: /pm:prd-parse $EPIC_NAME"; exit 1; }

# 2. Must be synced to GitHub
grep -q '^github:' .gemini/epics/$EPIC_NAME/epic.md || { echo "❌ Epic not synced. Run: /pm:epic-sync $EPIC_NAME"; exit 1; }

# 3. No uncommitted changes
[ -z "$(git status --porcelain)" ] || { echo "❌ Uncommitted changes. Commit or stash first."; exit 1; }
```

## Instructions

> **SCOPE: This command ONLY sets up the epic branch and displays status. It NEVER implements, executes, or works on any tasks. For task execution, use /pm:issue-start or /pm:epic-run.**

### Step 0: Context Loading Protocol

Before any work, follow this protocol:

1. **Load previous context**: If `.gemini/context/handoffs/latest.md` exists, read it and summarize key points: "I understand that..."
2. **Read epic context**: If `.gemini/context/epics/$EPIC_NAME.md` exists, read for epic-level decisions and history
3. **Review epic details**: Re-read `.gemini/epics/$EPIC_NAME/epic.md` for acceptance criteria and overall scope
4. **List planned approach**: State which issues are ready and your recommended starting point
5. **Wait for confirmation**: Do not start work until the user confirms

Run the pre-task hook if available:
```bash
test -f .gemini/hooks/pre-task.sh && bash .gemini/hooks/pre-task.sh
```

**DO NOT skip this protocol. DO NOT start work immediately.**

### Step 1: Create or Enter Branch

```bash
if ! git branch -a | grep -q "epic/$EPIC_NAME"; then
  git checkout main && git pull origin main
  git checkout -b epic/$EPIC_NAME
  git push -u origin epic/$EPIC_NAME
  echo "✅ Created branch: epic/$EPIC_NAME"
else
  git checkout epic/$EPIC_NAME
  git pull origin epic/$EPIC_NAME 2>/dev/null || true
  echo "✅ Using existing branch: epic/$EPIC_NAME"
fi
```

### Step 1.5: Initialize Epic Context

```bash
# Create epic context file if missing — never overwrite existing
if [ ! -f .gemini/context/epics/$EPIC_NAME.md ]; then
  mkdir -p .gemini/context/epics
fi
```

If `.gemini/context/epics/$EPIC_NAME.md` does not exist, create it with:
```markdown
---
epic: $EPIC_NAME
branch: epic/$EPIC_NAME
started: {current_datetime from date -u}
status: in-progress
---
# Epic Context: $EPIC_NAME

## Key Decisions
(Record architecture decisions and rationale here)

## Notes
(Accumulate context across sessions)
```

If it already exists, do not modify — just confirm: "📋 Epic context exists"

### Step 2: Identify Ready Issues

Read all task files in `.gemini/epics/$EPIC_NAME/` (files matching `[0-9]*.md`).

For each task file, read the frontmatter and categorize:
- **Ready**: `status: open`, no unmet `depends_on`, `parallel: true`
- **Blocked**: Has unmet `depends_on` (dependency still open)
- **In Progress**: `status: in-progress`
- **Complete**: `status: closed`

List all ready issues to the user with completion progress ({closed}/{total}).

### Step 2.5: Check Epic Verification State

Check for previous verification state (skip silently if files don't exist):

1. If `.gemini/context/verify/epic-state.json` exists and contains state for this epic:
   - Show phase status (Phase A / Phase B result)
   - Show iteration count if Phase B was run
   - If status is BLOCKED: "⚠️ Epic verification is BLOCKED. Run: /pm:epic-verify-status $EPIC_NAME"

2. If `.gemini/context/verify/epic-reports/` contains reports matching this epic name:
   - Show latest report assessment (EPIC_READY / EPIC_GAPS / EPIC_NOT_READY)
   - List any accepted gaps briefly

3. If ALL issues are closed and no epic verify has been run:
   - "💡 All issues closed. Consider running: /pm:epic-verify $EPIC_NAME"

### Step 2.6: Gap Fix Planning (Superpowers Integration)

**This step only activates when gaps exist from a previous epic-verify run.**

If Step 2.5 found gaps (assessment = EPIC_GAPS or EPIC_NOT_READY), inject the gap fix planning protocol:

1. **Detect Superpowers plugin:**
```bash
SUPERPOWERS_INSTALLED=false
if test -f .gemini/scripts/detect-superpowers.sh; then
  bash .gemini/scripts/detect-superpowers.sh && SUPERPOWERS_INSTALLED=true
fi
```

2. **Plan before fix:**

Display to agent:
```
📋 GAP FIX PLANNING
This epic has {gap_count} unresolved gaps from previous verification.
Before fixing any gap, document your approach first.
```

- **If Superpowers installed** (`$SUPERPOWERS_INSTALLED = true`):
  - Invoke `superpowers:brainstorming` skill for gap fix plan
  - Format output into the gap fix plan file

- **If Superpowers NOT installed:**
  - Agent writes plan manually following the template below

3. **Create/update gap fix plan file** at `.gemini/context/epics/$EPIC_NAME-gap-fixes.md`:

```markdown
---
epic: $EPIC_NAME
created: {date}
gaps_from_report: {report_filename}
---
# Gap Fix Plan: $EPIC_NAME

## Gap #{id}: {gap_title}
- **Type:** {Integration/Delivery/Phantom/Missing/Quality/Regression}
- **Approach:** {1-3 sentences: how to fix}
- **Files affected:** {list files}
- **Risk:** {Low/Medium/High} — {reason}
- **Estimated effort:** {Small/Medium/Large}

(Repeat for each gap)
```

4. **Wait for user confirmation** of the plan before proceeding.

**This is a SOFT gate** — it recommends planning but does not block tool use. If the user says "skip planning" or "just fix it", suggest `/pm:epic-fix-gap` or `/pm:epic-run`.

### Step 3: Suggest Next Steps

Display the ready issues list and suggest appropriate commands. Do NOT implement any tasks.

If ready issues exist:
- For manual control (one task at a time): `/pm:issue-start {first_ready_issue}`
- For automated execution (all tasks): `/pm:epic-run $EPIC_NAME`

If no ready issues (all blocked or complete):
- If all complete: suggest `/pm:epic-verify $EPIC_NAME`
- If all blocked: show dependency chain and suggest resolving blockers

### Step 4: Initialize Status File

Create `.gemini/epics/$EPIC_NAME/execution-status.md` with current state snapshot:
- Branch name
- Count of ready / blocked / in-progress / complete issues
- List of ready issue numbers and titles

This is a snapshot, not live tracking.

### Output

```
✅ Epic ready: $EPIC_NAME
  Branch: epic/$EPIC_NAME
  Ready: {count} | Blocked: {count} | Complete: {closed}/{total}

Next:
  - Manual (one task at a time): /pm:issue-start {first_ready}
  - Automated (all tasks):       /pm:epic-run $EPIC_NAME
  - Check status:                /pm:epic-status $EPIC_NAME

⚡ Design Gate:
  FEATURE/REFACTOR/ENHANCEMENT tasks require a design file
  before coding. The design gate activates automatically via
  pre-task hook when you run /pm:issue-start.
  See: docs/rules-reference/superpowers-integration.md

When all issues done:
  - Verify epic:     /pm:epic-verify $EPIC_NAME
  - View status:     /pm:epic-status $EPIC_NAME
  - Merge to main:   /pm:epic-merge $EPIC_NAME
```

## STOP

This command is complete. Do NOT:
- Continue to work on any issues
- Implement or execute any tasks
- Spawn agents or start coding
- Call /pm:issue-start, /pm:epic-run, or any execution commands

The user will decide the next action.
