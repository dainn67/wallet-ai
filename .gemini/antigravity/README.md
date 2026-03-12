# CCPM Antigravity Adapter

Adapter layer for running CCPM (Gemini CLI Project Manager) inside Google Antigravity IDE.

## Architecture

CCPM uses a 3-layer architecture to support multiple IDEs:

```
Layer 3: IDE-Specific Adapters
  .gemini/  (Gemini CLI CLI)  ← hooks, commands, agents
  .agent/   (Antigravity)      ← skills, workflows, rules (this adapter)

Layer 2: Shared CCPM Core
  .gemini/  (IDE-agnostic state)
  Context, config, epics, verify state — shared by all IDEs

Layer 1: Project Files
  Source code, tests, docs — no CCPM awareness needed
```

**Key principle:** `.agent/` contains only Antigravity adapter files. All CCPM state lives in `.gemini/`.

## Workflows (28)

Workflows are user-triggered via `/command` in Antigravity. Each maps to a Gemini CLI `/pm:*` command.

### Dashboard

| Workflow | Description | Tier |
|----------|-------------|------|
| `/pm-status` | Project dashboard — PRDs, epics, tasks overview | light |
| `/pm-help` | Full command reference | light |
| `/pm-next` | Find the next task to work on | light |
| `/pm-standup` | Daily summary of progress | light |
| `/pm-blocked` | List blocked tasks | light |
| `/pm-in_progress` | List tasks currently in progress | light |
| `/pm-search` | Search tasks by keyword | light |

### PRD Management

| Workflow | Description | Tier |
|----------|-------------|------|
| `/pm-prd_list` | List all PRDs | light |
| `/pm-prd_status` | Show PRD status and progress | light |
| `/pm-prd_new` | Create a new PRD from brainstorming | heavy |
| `/pm-prd_parse` | Parse PRD into epic with tasks | heavy |

### Epic Lifecycle

| Workflow | Description | Tier |
|----------|-------------|------|
| `/pm-epic_list` | List all epics | light |
| `/pm-epic_show` | Show epic details and tasks | light |
| `/pm-epic_status` | View epic progress | light |
| `/pm-epic_start` | Start epic — loads context, creates branch | heavy |
| `/pm-epic_decompose` | Break epic into individual tasks | heavy |
| `/pm-epic_oneshot` | Decompose + sync to GitHub in one step | heavy |
| `/pm-epic_verify` | Run full 2-phase verification pipeline | heavy |
| `/pm-epic_merge` | Merge epic branch to main | heavy |

### Issue Lifecycle

| Workflow | Description | Tier |
|----------|-------------|------|
| `/pm-issue_start` | Start work on an issue — loads context | medium |
| `/pm-issue_complete` | Complete issue — handoff + verify + close | medium |
| `/pm-issue_analyze` | Analyze issue for parallel work streams | heavy |

### Verification & Handoff

| Workflow | Description | Tier |
|----------|-------------|------|
| `/pm-verify_run` | Run verification checks mid-work | medium |
| `/pm-verify_status` | Check current verification state | light |
| `/pm-verify_skip` | Skip verification with documented reason | medium |
| `/pm-handoff_write` | Write handoff notes for next session | medium |
| `/pm-epic_sync` | Sync epic tasks to GitHub issues | medium |
| `/pm-context_sync` | Cross-IDE context sync (Gemini CLI ↔ Antigravity) | light |

## Skills (7)

Skills are agent-triggered — Antigravity automatically activates them based on user intent. No explicit invocation needed.

| Skill | Triggers On | Replaces (Gemini CLI) |
|-------|-------------|------------------------|
| `ccpm-context-loader` | "start work", "begin task", "resume", "continue" | PreTask hook |
| `ccpm-design-gate` | "implement", "code", "build feature", "refactor" | PreToolUse design check |
| `ccpm-verification` | "done", "complete", "finish", "ready to close" | Stop hook (Ralph loop) |
| `ccpm-test-first` | "write code for feature", "implement feature" | Stop hook test check |
| `ccpm-semantic-review` | After verification passes | Stop hook semantic review |
| `ccpm-handoff` | "end session", "switch task", "stopping" | PostTask hook |
| `ccpm-epic-verify` | "verify epic", "check epic", "epic ready" | Epic verify hooks |

## Rules (6)

Rules are always loaded — Antigravity reads all files in `.agent/rules/` at session start. They act as passive constraints.

| Rule | Purpose |
|------|---------|
| `ccpm-core.md` | Path conventions, datetime format, frontmatter ops, GitHub ops |
| `ccpm-design-before-code.md` | Design file required before coding (FEATURE/REFACTOR/ENHANCEMENT) |
| `ccpm-test-first.md` | Tests required before task completion |
| `ccpm-commit-standards.md` | Branch naming, commit format, `.gemini/` exclusion |
| `ccpm-enforcement.md` | Self-enforcement protocol with checklists and anti-bypass patterns |
| `ccpm-path-convention.md` | `.agent/` is adapter-only, all state in `.gemini/` |

## Enforcement Model

### The Gap

Gemini CLI enforces CCPM rules with **hard hooks** — `pre-tool-use.sh` can BLOCK tool calls (`exit 2`). Antigravity has NO hook system. Rules are advisory only.

### The Solution: 3-Layer Advisory Enforcement

```
Layer 1: Rules (Always-On)
  Agent reads these EVERY session. Constant passive reminders.

Layer 2: Skills (Semantic Trigger)
  Agent auto-activates when relevant intent detected.
  Skills contain detailed protocols with step-by-step instructions.

Layer 3: Self-Enforcement Protocol
  Embedded in every skill: "If you find yourself [violating X], STOP."
  Rules file ccpm-enforcement.md: explicit Before-You-Act checklists.
```

### Review Policy Recommendations

For teams using Antigravity with CCPM:

1. **Require design files in PR reviews** — reject PRs for FEATURE/REFACTOR tasks without a corresponding `task-{N}-design.md`
2. **Check test existence in CI** — add a CI step that verifies test files exist for FEATURE tasks
3. **Enforce handoff notes** — require `latest.md` to be updated in every PR
4. **Periodic compliance audits** — review the Compliance Tracking section in handoff notes to spot skipped steps
5. **Pair Antigravity with Gemini CLI** — use Gemini CLI for critical tasks where hard enforcement matters, Antigravity for exploratory and visual work

## Installation

The Antigravity adapter is installed via the CCPM universal installer:

```bash
# Install both adapters
bash install/local_install.sh --both

# Install Antigravity adapter only
bash install/local_install.sh --antigravity
```

This copies:
- `antigravity/skills/` → `.agent/skills/`
- `antigravity/workflows/` → `.agent/workflows/`
- `antigravity/rules/` → `.agent/rules/`
- `antigravity/README.md` → `.agent/README.md`

## Directory Structure

```
antigravity/                    # Source code (in CCPM repo)
├── rules/                      # 6 rule files (always-loaded constraints)
│   ├── ccpm-core.md
│   ├── ccpm-design-before-code.md
│   ├── ccpm-test-first.md
│   ├── ccpm-commit-standards.md
│   ├── ccpm-enforcement.md
│   └── ccpm-path-convention.md
├── skills/                     # Skill packages (semantic-triggered)
├── workflows/                  # Workflow files (user-triggered /commands)
├── templates/
│   └── active-ide.json         # Default template for cross-IDE sync state
└── README.md                   # This file
```
