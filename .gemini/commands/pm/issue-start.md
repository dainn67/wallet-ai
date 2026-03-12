---
model: sonnet
allowed-tools: Bash, Read, Write, LS, Task
---

# Issue Start

Begin work on a GitHub issue with parallel agents based on work stream analysis.

## Usage
```
/pm:issue-start <issue_number>
```

## Quick Check

1. **Detect GitHub repo:**
   ```bash
   REPO=$(bash .gemini/scripts/pm/github-helpers.sh get-repo-for-issue $ARGUMENTS 2>/dev/null || echo "")
   ```
   This tries: epic config → github-mapping → git remote. If empty: "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."

2. **Get issue details:**
   ```bash
   gh issue view $ARGUMENTS --repo "$REPO" --json state,title,labels,body
   ```
   If it fails: "❌ Cannot access issue #$ARGUMENTS. Check number or run: gh auth login"

   **Detect Light Path:**
   ```bash
   # Check if issue has source:issue-new label
   IS_LIGHT_PATH=false
   if echo "$labels" | grep -q "source:issue-new"; then
     IS_LIGHT_PATH=true
   fi
   ```

   **If IS_LIGHT_PATH=true — Create debug journal:**
   ```bash
   mkdir -p .gemini/context/sessions/archive 2>/dev/null
   ```
   Ask user to choose journal mode:
   ```
   Debug journal mode cho issue #$ARGUMENTS:
    1. auto — ghi mỗi round tự động
    2. semi-auto — ghi khi có state change quan trọng (recommended)
    3. manual — hỏi trước khi ghi
    Chọn (1/2/3, default: 2):
   ```
   Then create `.gemini/context/sessions/issue-$ARGUMENTS-debug.md`:
   ```markdown
   # Debug Journal: Issue #$ARGUMENTS — {title}
   Created: {ISO timestamp}
   Mode: {selected_mode}
   ```

3. **Find local task file:**
   - If `IS_LIGHT_PATH=true` → skip this check (standalone issues have no local task file); continue to step 4
   - First check if `.gemini/epics/*/$ARGUMENTS.md` exists (new naming)
   - If not found, search for file containing `github:.*issues/$ARGUMENTS` in frontmatter (old naming)
   - If not found: "❌ No local task for issue #$ARGUMENTS. This issue may have been created outside the PM system."

   **Detect branch strategy (after task file check):**
   ```bash
   # Parse branch-strategy from issue body HTML comment
   BRANCH_STRATEGY=$(echo "$body" | grep -o '<!-- branch-strategy: [a-z]* -->' | grep -o '[a-z]*' | tail -1)
   [ -z "$BRANCH_STRATEGY" ] && BRANCH_STRATEGY="direct"

   # Check current branch
   CURRENT_BRANCH=$(git branch --show-current)

   # Decision matrix
   if echo "$CURRENT_BRANCH" | grep -q "^epic/"; then
     BRANCH_STRATEGY="direct"   # Always direct on epic branch
   elif [[ "$ARGUMENTS" == *"--branch"* ]]; then
     BRANCH_STRATEGY="branch"   # User override: force branch
   elif [[ "$ARGUMENTS" == *"--no-branch"* ]]; then
     BRANCH_STRATEGY="direct"   # User override: force direct
   fi
   ```

4. **Display recommended model:**
   ```bash
   recommended_model=$(grep '^recommended_model:' "$task_file" | head -1 | sed 's/^recommended_model: *//')
   [ -z "$recommended_model" ] && recommended_model="sonnet"
   echo "📋 Recommended model: $recommended_model"
   ```

5. **Complexity Assessment (ace-learning):**
   If ace-learning complexity scoring is enabled, run and display the score:
   ```bash
   source .gemini/scripts/pm/complexity-score.sh 2>/dev/null
   if command -v ace_feature_enabled &>/dev/null && ace_feature_enabled "complexity" 2>/dev/null; then
     compute_complexity_score "$task_file" 2>/dev/null || true
   fi
   ```
   Display output as-is. Model suggestion and strategy hints are **display-only** — never auto-switch model.
   If feature disabled or script missing → skip silently.

6. **Check for analysis:**
   - If `IS_LIGHT_PATH=true` → skip this check (issue body IS the plan for standalone issues)
   - If `IS_LIGHT_PATH=false`:
   ```bash
   test -f .gemini/epics/*/$ARGUMENTS-analysis.md || echo "❌ No analysis found for issue #$ARGUMENTS

   Run: /pm:issue-analyze $ARGUMENTS first
   Or: /pm:issue-start $ARGUMENTS --analyze to do both"
   ```
   If no analysis exists and no --analyze flag, stop execution.

## Instructions

> **SCOPE: This command processes EXACTLY ONE issue (#$ARGUMENTS). After setup and output, STOP. Never continue to additional issues, never call issue-complete, never look for next tasks.**

### 1. Ensure Worktree Exists

**If IS_LIGHT_PATH=true:**
```bash
if [ "$BRANCH_STRATEGY" = "branch" ]; then
  # Create fix branch for standalone issue
  git checkout -b "fix/issue-$ARGUMENTS"
  echo "Created branch: fix/issue-$ARGUMENTS"
else
  echo "Direct commit mode — no branch/worktree needed"
fi
```
Skip the epic worktree check entirely. Continue to step 2.

**If IS_LIGHT_PATH=false** — check epic worktree as usual:
```bash
# Find epic name from task file
epic_name={extracted_from_path}

# Check worktree
if ! git worktree list | grep -q "epic-$epic_name"; then
  echo "❌ No worktree for epic. Run: /pm:epic-start $epic_name"
  exit 1
fi
```

### 2. Read Analysis

Read `.gemini/epics/{epic_name}/$ARGUMENTS-analysis.md`:
- Parse parallel streams
- Identify which can start immediately
- Note dependencies between streams

### 3. Context Loading Protocol

Before writing any code, follow this protocol:

1. **Load previous context**: If `.gemini/context/handoffs/latest.md` exists, read it and summarize key points: "I understand that..."
2. **Read epic context**: Check for epic-level context files in `.gemini/context/epics/`
3. **Skillbook Injection (ace-learning)**: If ace-learning skillbook is enabled, inject relevant learned patterns:
   ```bash
   source .gemini/scripts/pm/skillbook-inject.sh 2>/dev/null || true
   if command -v ace_feature_enabled &>/dev/null && ace_feature_enabled "skillbook" 2>/dev/null; then
     inject_relevant_skills "$task_file" 2>/dev/null || true
   fi
   ```
   Display injected skills as "**Relevant lessons from previous tasks:**" section if any match.
   If feature disabled, skillbook empty, or script missing → skip silently.
4. **Review task details**: Re-read the task file acceptance criteria
5. **List planned changes**: State which files you plan to create or modify
6. **Wait for confirmation**: Do not start coding until the user confirms

Run the pre-task hook if available:
```bash
test -f .gemini/hooks/pre-task.sh && bash .gemini/hooks/pre-task.sh
```

**DO NOT skip this protocol. DO NOT start coding immediately.**

### 4. Setup Progress Tracking

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Create workspace structure:
```bash
mkdir -p .gemini/epics/{epic_name}/updates/$ARGUMENTS
```

Update task file frontmatter `updated` field with current datetime.

### 5. Launch Parallel Agents

For each stream that can start immediately:

Create `.gemini/epics/{epic_name}/updates/$ARGUMENTS/stream-{X}.md`:
```markdown
---
issue: $ARGUMENTS
stream: {stream_name}
agent: {agent_type}
started: {current_datetime}
status: in_progress
---

# Stream {X}: {stream_name}

## Scope
{stream_description}

## Files
{file_patterns}

## Progress
- Starting implementation
```

Launch agent using Task tool:
```yaml
Task:
  description: "Issue #$ARGUMENTS Stream {X}"
  subagent_type: "{agent_type}"
  prompt: |
    You are working on Issue #$ARGUMENTS in the epic worktree.

    Worktree location: ../epic-{epic_name}/
    Your stream: {stream_name}

    Your scope:
    - Files to modify: {file_patterns}
    - Work to complete: {stream_description}

    Requirements:
    1. Read full task from: .gemini/epics/{epic_name}/{task_file}
    2. Work ONLY in your assigned files
    3. Commit frequently with format: "Issue #$ARGUMENTS: {specific change}"
    4. Update progress in: .gemini/epics/{epic_name}/updates/$ARGUMENTS/stream-{X}.md
    5. Follow coordination rules in .gemini/rules/agent-coordination.md

    If you need to modify files outside your scope:
    - Check if another stream owns them
    - Wait if necessary
    - Update your progress file with coordination notes

    Complete your stream's work and mark as completed when done.
```

### 6. GitHub Assignment

```bash
# Assign to self and mark in-progress (use --repo from step 1)
gh issue edit $ARGUMENTS --repo "$REPO" --add-assignee @me --add-label "in-progress"
```

### 7. Output

**If IS_LIGHT_PATH=true:**
```
✅ Started work on standalone issue #$ARGUMENTS

Branch: {current_branch} (direct commit) | fix/issue-$ARGUMENTS (new branch)
Debug journal: .gemini/context/sessions/issue-$ARGUMENTS-debug.md (mode: {mode})

Workflow:
  1. During work:    /pm:verify-run
  2. Complete issue:  /pm:issue-complete $ARGUMENTS
```

**If IS_LIGHT_PATH=false:**
```
✅ Started parallel work on issue #$ARGUMENTS

Epic: {epic_name}
Worktree: ../epic-{epic_name}/

Launching {count} parallel agents:
  Stream A: {name} (Agent-1) ✓ Started
  Stream B: {name} (Agent-2) ✓ Started
  Stream C: {name} - Waiting (depends on A)

Progress tracking:
  .gemini/epics/{epic_name}/updates/$ARGUMENTS/

Workflow:
  1. During work:    /pm:verify-run (check your work)
  2. Complete issue:  /pm:issue-complete $ARGUMENTS (handoff + verify + close)
  3. Write handoff:  /pm:handoff-write (if stopping mid-task)

Monitor: /pm:epic-status {epic_name}
```

## STOP

This command is complete. Do NOT:
- Continue to work on other issues
- Call /pm:issue-complete
- Look for or start next tasks
- Run /pm:next

The user will decide the next action.

## Error Handling

If any step fails, report clearly:
- "❌ {What failed}: {How to fix}"
- Continue with what's possible
- Never leave partial state

## Important Notes

Keep it simple - trust that GitHub and file system work.
