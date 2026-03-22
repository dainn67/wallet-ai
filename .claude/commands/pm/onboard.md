---
model: sonnet
name: onboard
description: Interactive onboarding — learn CCPM workflow with a guided demo
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Onboard

Interactive walkthrough of the full CCPM workflow using an isolated `_onboard-demo` feature. Covers PRD → epic → tasks lifecycle. Target: ≤15 minutes.

## Usage
```
/pm:onboard
```

## Instructions

### Step 0: Preflight — Clean Demo Namespace

Check for leftover artifacts from a previous interrupted run and clean them up:

```bash
leftover=false
[ -f .claude/prds/_onboard-demo.md ] && leftover=true
[ -d .claude/epics/_onboard-demo ] && leftover=true
[ -f .claude/context/build-state/_onboard-demo.json ] && leftover=true

if [ "$leftover" = "true" ]; then
  echo "⚠️  Found artifacts from a previous onboard run. Cleaning up first..."
  rm -f .claude/prds/_onboard-demo.md
  rm -rf .claude/epics/_onboard-demo/
  rm -f .claude/context/build-state/_onboard-demo.json
  echo "🧹 Old demo artifacts removed. Starting fresh."
fi
```

Ensure required directories exist:

```bash
mkdir -p .claude/prds .claude/epics .claude/context 2>/dev/null
```

### Step 1: Welcome

Display:

```
══════════════════════════════════════════════════════
  Welcome to CCPM — Interactive Onboarding Walkthrough
══════════════════════════════════════════════════════

CCPM (Claude Code Project Manager) helps you ship features systematically
using AI-assisted workflow: PRD → Epic → Tasks → Verify → Merge.

This walkthrough uses a disposable demo feature called "_onboard-demo"
to show you the full lifecycle. Everything is isolated — your real project
data will not be touched.

📋 What we'll cover (8 steps):
  1. PRD Creation      — define what to build
  2. PRD Validation    — check quality gates
  3. Epic Generation   — create the epic structure
  4. Plan Review       — inspect the plan
  5. Task Decomposition — break epic into tasks
  6. Workflow Summary  — remaining steps explained
  7. Cheatsheet        — generate command reference
  8. Cleanup           — remove all demo artifacts

⏱  Estimated time: 10–15 minutes

You can also run `pm:build _onboard-demo` to orchestrate the full
workflow automatically — this walkthrough shows each step individually
for educational clarity.

Press Enter to begin...
```

Wait for user input.

### Step 2: PRD Creation

Display:

```
──────────────────────────────────────────────────────
📖 Step 1/8: PRD Creation
──────────────────────────────────────────────────────

A PRD (Product Requirements Document) is the foundation of every feature.
It captures the problem, target users, and requirements before any code
is written. CCPM stores PRDs in .claude/prds/.

Running: Creating _onboard-demo PRD...
```

Create a minimal demo PRD directly (bypasses interactive discovery for speed):

```bash
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > .claude/prds/_onboard-demo.md << 'PRDEOF'
---
name: _onboard-demo
description: Demo feature for CCPM onboarding walkthrough
status: backlog
priority: P2
scale: small
created: CREATED_PLACEHOLDER
updated: null
---

# PRD: _onboard-demo

## Executive Summary
A minimal demo feature created by the CCPM onboarding walkthrough. It demonstrates
the PRD format and workflow without affecting any real project data.

## Problem Statement
New CCPM users need a safe, isolated environment to learn the workflow without
risking their real project. This demo PRD provides that sandbox.

## Target Users
- **New User** — Someone learning CCPM for the first time. Needs guided experience.

## User Stories

**US-1: Safe Learning Environment**
As a new CCPM user, I want to practice the workflow so that I can learn without fear.

Acceptance Criteria:
- [ ] Demo artifacts are prefixed with `_onboard-demo`
- [ ] All demo artifacts are cleaned up after the walkthrough

## Requirements

### Functional Requirements (MUST)

**FR-1: Isolated Demo Namespace**
All demo artifacts use the `_onboard-demo` prefix to avoid interference with real data.

Scenario: Demo isolation
- GIVEN a user runs pm:onboard
- WHEN demo artifacts are created
- THEN all files are prefixed with `_onboard-demo`

**FR-2: Cleanup After Walkthrough**
All demo artifacts are removed when the walkthrough completes.

Scenario: Cleanup
- GIVEN the walkthrough has completed
- WHEN cleanup runs
- THEN no `_onboard-demo` files remain in .claude/

### Non-Functional Requirements

**NFR-1: Speed**
The walkthrough completes in ≤15 minutes.

## Success Criteria
- 100% of demo artifacts cleaned up after walkthrough
- User understands the PRD → Epic → Tasks lifecycle

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| User interrupts walkthrough | Low | Medium | Artifacts are clearly named for manual cleanup |

## Constraints & Assumptions
- **Assumption:** User has CCPM installed and configured.

## Out of Scope
- Real feature development — this is a demo only

## Dependencies
- None

## _Metadata
<!-- Auto-generated -->
requirement_ids:
  must: [FR-1, FR-2]
  nice_to_have: []
  nfr: [NFR-1]
scale: small
discovery_mode: yolo
validation_status: pending
last_validated: null
PRDEOF

# Fix the timestamp placeholder
sed -i '' "s/CREATED_PLACEHOLDER/$now/" .claude/prds/_onboard-demo.md
echo "✅ Created: .claude/prds/_onboard-demo.md"
```

Display:

```
✅ What just happened: A PRD was created at .claude/prds/_onboard-demo.md
   It defines the problem, requirements (FR-1, FR-2, NFR-1), and success criteria
   for the demo feature.

Press Enter to continue...
```

Wait for user input.

### Step 3: PRD Validation

Display:

```
──────────────────────────────────────────────────────
📖 Step 2/8: PRD Validation
──────────────────────────────────────────────────────

Before creating an epic, CCPM validates the PRD for quality and completeness.
The validator checks: required sections, requirement IDs, measurable success
criteria, and scenario format (GIVEN/WHEN/THEN).

Running: pm:prd-validate _onboard-demo
```

Validate the PRD by checking key structural elements:

```bash
prd_file=".claude/prds/_onboard-demo.md"
errors=0

# Check required sections
for section in "Executive Summary" "Problem Statement" "Requirements" "Success Criteria" "Risks"; do
  if grep -q "## $section" "$prd_file" 2>/dev/null; then
    echo "  ✅ Section present: $section"
  else
    echo "  ❌ Missing section: $section"
    errors=$((errors + 1))
  fi
done

# Check requirement IDs
if grep -qE '^(FR|NFR|NTH)-[0-9]+:' "$prd_file" 2>/dev/null; then
  echo "  ✅ Requirement IDs: present (FR-*, NFR-*)"
else
  echo "  ❌ Requirement IDs: missing"
  errors=$((errors + 1))
fi

# Check scenarios
if grep -q 'GIVEN' "$prd_file" 2>/dev/null; then
  echo "  ✅ Scenarios: GIVEN/WHEN/THEN format found"
else
  echo "  ❌ Scenarios: missing GIVEN/WHEN/THEN"
  errors=$((errors + 1))
fi

if [ "$errors" -eq 0 ]; then
  echo ""
  echo "  ✅ Validation passed: 0 errors"
else
  echo ""
  echo "  ⚠️  Validation found $errors issue(s)"
fi
```

Display:

```
✅ What just happened: CCPM checked the PRD against quality gates.
   A real project would use /pm:prd-validate and iterate with /pm:prd-edit
   until all checks pass.

Press Enter to continue...
```

Wait for user input.

### Step 4: Epic Generation

Display:

```
──────────────────────────────────────────────────────
📖 Step 3/8: Epic Generation
──────────────────────────────────────────────────────

An "epic" is the project plan derived from a PRD. CCPM parses the PRD
and generates an epic directory with an epic.md file describing the
implementation scope, phases, and architecture decisions.

Running: Creating _onboard-demo epic structure...
```

Create the demo epic:

```bash
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mkdir -p .claude/epics/_onboard-demo

cat > .claude/epics/_onboard-demo/epic.md << 'EPICEOF'
---
name: _onboard-demo
status: backlog
progress: 0%
created: CREATED_PLACEHOLDER
updated: CREATED_PLACEHOLDER
prd: .claude/prds/_onboard-demo.md
---

# Epic: _onboard-demo

Demo feature for CCPM onboarding. Safe to delete.

## Scope
Implement isolated demo namespace and cleanup for the onboarding walkthrough.

## Architecture Decisions
- **AD-1:** Use `_onboard-demo` prefix for all artifacts (underscore prefix = demo/temp)

## Phases
- **Phase 1:** Core isolation (FR-1)
- **Phase 2:** Cleanup (FR-2)

## Requirements Coverage
- FR-1: Isolated Demo Namespace → Phase 1
- FR-2: Cleanup After Walkthrough → Phase 2
- NFR-1: Speed → cross-cutting
EPICEOF

sed -i '' "s/CREATED_PLACEHOLDER/$now/g" .claude/epics/_onboard-demo/epic.md
echo "✅ Created: .claude/epics/_onboard-demo/epic.md"
```

Display:

```
✅ What just happened: An epic was generated from the PRD.
   The epic defines phases, architecture decisions, and maps requirements
   to implementation scope. In a real project: /pm:prd-parse my-feature

Press Enter to continue...
```

Wait for user input.

### Step 5: Plan Review

Display:

```
──────────────────────────────────────────────────────
📖 Step 4/8: Plan Review
──────────────────────────────────────────────────────

Before decomposing into tasks, you can review and adjust the epic plan.
Plan review checks: requirement coverage, phase structure, risk areas,
and estimates. This is a human judgment gate — the AI proposes, you decide.

Showing: .claude/epics/_onboard-demo/epic.md
```

Read and display the epic content:

```bash
cat .claude/epics/_onboard-demo/epic.md
```

Display:

```
✅ What just happened: You reviewed the epic plan.
   In a real project, you'd run /pm:plan-review my-feature to get an AI-assisted
   review with gap analysis and recommendations. You can edit with /pm:epic-edit.

Press Enter to continue...
```

Wait for user input.

### Step 6: Task Decomposition

Display:

```
──────────────────────────────────────────────────────
📖 Step 5/8: Task Decomposition
──────────────────────────────────────────────────────

Task decomposition breaks the epic into discrete, implementable tasks.
Each task maps to a GitHub issue, has clear acceptance criteria, and
specifies which files to modify. Tasks can run in parallel when safe.

Running: Creating demo task files...
```

Create demo task files:

```bash
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > .claude/epics/_onboard-demo/1.md << 'TASKEOF'
---
name: Implement _onboard-demo isolation namespace
status: open
created: CREATED_PLACEHOLDER
updated: CREATED_PLACEHOLDER
complexity: simple
recommended_model: sonnet
phase: 1
priority: P2
parallel: false
conflicts_with: []
files:
  - .claude/prds/_onboard-demo.md
prd_requirements:
  - FR-1
---

# Task: Implement _onboard-demo isolation namespace

Use `_onboard-demo` prefix for all demo artifacts.

## Acceptance Criteria
- [ ] All demo files use `_onboard-demo` prefix
- [ ] No interference with real project data
TASKEOF

cat > .claude/epics/_onboard-demo/2.md << 'TASKEOF'
---
name: Implement cleanup for _onboard-demo artifacts
status: open
created: CREATED_PLACEHOLDER
updated: CREATED_PLACEHOLDER
complexity: simple
recommended_model: sonnet
phase: 2
priority: P2
depends_on: [1]
parallel: false
conflicts_with: []
files:
  - commands/pm/onboard.md
prd_requirements:
  - FR-2
---

# Task: Implement cleanup for _onboard-demo artifacts

Remove all `_onboard-demo` artifacts after walkthrough completes.

## Acceptance Criteria
- [ ] All _onboard-demo files removed after walkthrough
- [ ] Verify no leftover files remain
TASKEOF

for f in .claude/epics/_onboard-demo/1.md .claude/epics/_onboard-demo/2.md; do
  sed -i '' "s/CREATED_PLACEHOLDER/$now/g" "$f"
done

echo "✅ Created: .claude/epics/_onboard-demo/1.md (Phase 1)"
echo "✅ Created: .claude/epics/_onboard-demo/2.md (Phase 2)"
echo ""
echo "Task list:"
ls .claude/epics/_onboard-demo/*.md | xargs -I{} basename {} | grep -v epic
```

Display:

```
✅ What just happened: 2 task files were created from the epic.
   Each task has acceptance criteria, phase, model recommendation, and file targets.
   In a real project: /pm:epic-decompose my-feature
   Then sync to GitHub: /pm:epic-sync my-feature

Press Enter to continue...
```

Wait for user input.

### Step 7: Workflow Summary

Display:

```
──────────────────────────────────────────────────────
📖 Step 6/8: Remaining Workflow (Summary)
──────────────────────────────────────────────────────

The remaining steps after task decomposition are:

  epic-start   → Create a git branch (epic/my-feature) and worktree
                 Command: /pm:epic-start my-feature

  epic-run     → Execute all tasks using AI agents (parallel where safe)
                 Each agent reads its task file, implements changes, commits
                 Command: /pm:epic-run my-feature

  epic-verify  → Run automated verification: tests, lint, acceptance criteria
                 Command: /pm:epic-verify my-feature

  epic-merge   → Merge the epic branch back to main, archive artifacts
                 Command: /pm:epic-merge my-feature

  pm:build     → The full orchestrator that runs ALL steps automatically:
                 Command: /pm:build my-feature

💡 Tip: For day-to-day status, use:
  /pm:status          — project overview
  /pm:next            — what to do next
  /pm:epic-status     — detailed epic progress

Press Enter to continue...
```

Wait for user input.

### Step 8: Cheatsheet Generation

Display:

```
──────────────────────────────────────────────────────
📖 Step 7/8: Cheatsheet Generation
──────────────────────────────────────────────────────

Generating a command reference from all commands/pm/*.md files...
```

Generate the cheatsheet by scanning all command files for name and description:

```bash
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mkdir -p .claude/context

# Collect command data
workflow_cmds=""
utility_cmds=""

# Ordered workflow commands
workflow_order="build prd-new prd-rethink prd-validate prd-edit prd-parse plan-review epic-decompose epic-sync epic-start epic-run epic-verify epic-merge"

for cmd_name in $workflow_order; do
  cmd_file="commands/pm/${cmd_name}.md"
  if [ -f "$cmd_file" ]; then
    desc=$(grep '^description:' "$cmd_file" | head -1 | sed 's/^description: *//')
    model=$(grep '^model:' "$cmd_file" | head -1 | sed 's/^model: *//')
    [ -z "$desc" ] && desc="(no description)"
    [ -z "$model" ] && model="sonnet"
    workflow_cmds="${workflow_cmds}| pm:${cmd_name} | ${desc} | ${model} |\n"
  fi
done

# Utility commands (everything else)
for cmd_file in commands/pm/*.md; do
  cmd_name=$(basename "$cmd_file" .md)
  # Skip workflow commands already listed
  echo "$workflow_order" | grep -qw "$cmd_name" && continue
  desc=$(grep '^description:' "$cmd_file" | head -1 | sed 's/^description: *//')
  model=$(grep '^model:' "$cmd_file" | head -1 | sed 's/^model: *//')
  [ -z "$desc" ] && desc="(no description)"
  [ -z "$model" ] && model="sonnet"
  utility_cmds="${utility_cmds}| pm:${cmd_name} | ${desc} | ${model} |\n"
done

cat > .claude/context/cheatsheet.md << CHEATEOF
# CCPM Command Cheatsheet
Generated: $now

## Workflow Commands (in order)
| Command | Description | Model |
|---------|-------------|-------|
$(printf "$workflow_cmds")

## Utility Commands
| Command | Description | Model |
|---------|-------------|-------|
$(printf "$utility_cmds")

## Quick Reference
- Start new feature: \`/pm:build my-feature\`
- Full auto workflow: \`/pm:build my-feature\`
- Check what to do next: \`/pm:next\`
- View status: \`/pm:status\`
- Get help: \`/pm:help\`

## Workflow Order
\`\`\`
prd-new → prd-validate → prd-parse → plan-review → epic-decompose
→ epic-sync → epic-start → epic-run → epic-verify → epic-merge
\`\`\`

## Tier Guide
- **sonnet**: status, list, show, search, start, complete, edit, sync, verify
- **opus**: rethink, new, parse, plan-review, decompose, merge, analyze
CHEATEOF

echo "✅ Generated: .claude/context/cheatsheet.md"
cmd_count=$(grep -c '^| pm:' .claude/context/cheatsheet.md 2>/dev/null || echo "?")
echo "   Listed $cmd_count commands"
```

Display:

```
✅ What just happened: A command reference was generated at .claude/context/cheatsheet.md
   It lists all pm: commands with descriptions and model tiers.
   View it anytime: cat .claude/context/cheatsheet.md

Press Enter to continue to cleanup...
```

Wait for user input.

### Step 9: Cleanup

Display:

```
──────────────────────────────────────────────────────
📖 Step 8/8: Cleanup
──────────────────────────────────────────────────────

Removing all _onboard-demo artifacts...
```

Remove all demo artifacts:

```bash
removed=0

if [ -f .claude/prds/_onboard-demo.md ]; then
  rm -f .claude/prds/_onboard-demo.md
  echo "  🗑  Removed: .claude/prds/_onboard-demo.md"
  removed=$((removed + 1))
fi

if [ -d .claude/epics/_onboard-demo ]; then
  rm -rf .claude/epics/_onboard-demo/
  echo "  🗑  Removed: .claude/epics/_onboard-demo/"
  removed=$((removed + 1))
fi

if [ -f .claude/context/build-state/_onboard-demo.json ]; then
  rm -f .claude/context/build-state/_onboard-demo.json
  echo "  🗑  Removed: .claude/context/build-state/_onboard-demo.json"
  removed=$((removed + 1))
fi

# Verify no _onboard-demo files remain
remaining=$(find .claude -name '*_onboard-demo*' 2>/dev/null | wc -l | tr -d ' ')
if [ "$remaining" -eq 0 ]; then
  echo ""
  echo "🧹 Demo artifacts cleaned up ($removed items). Your project is unchanged."
else
  echo ""
  echo "⚠️  $remaining _onboard-demo file(s) still remain:"
  find .claude -name '*_onboard-demo*' 2>/dev/null
  echo "   Remove manually if needed."
fi
```

### Step 10: Completion

Display:

```
══════════════════════════════════════════════════════
  🎉 Onboarding Complete!
══════════════════════════════════════════════════════

You've completed the CCPM workflow walkthrough:

  ✅ Step 1/8: PRD Creation         — defined what to build
  ✅ Step 2/8: PRD Validation       — checked quality gates
  ✅ Step 3/8: Epic Generation      — created project plan
  ✅ Step 4/8: Plan Review          — inspected the plan
  ✅ Step 5/8: Task Decomposition   — broke epic into tasks
  ✅ Step 6/8: Workflow Summary     — learned remaining steps
  ✅ Step 7/8: Cheatsheet           — generated command reference
  ✅ Step 8/8: Cleanup              — removed all demo artifacts

📄 Your cheatsheet: .claude/context/cheatsheet.md

🚀 Ready to ship your first real feature?
  → /pm:build my-feature-name
  → /pm:help (see all commands)
  → /pm:status (check project state)

💡 Note: If you interrupted a previous onboard run, any remaining
   _onboard-demo artifacts can be cleaned up with:
   rm -rf .claude/prds/_onboard-demo.md .claude/epics/_onboard-demo/
```
