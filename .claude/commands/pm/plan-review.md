---
model: opus
allowed-tools: Bash, Read, Write, LS, Grep, Glob
description: |
  Eng manager-mode plan review. Review an epic plan before implementation —
  architecture, scope, failure modes, test strategy, performance. Interactive,
  opinionated, with structured output that feeds into epic-start.
---

# Plan Review

Review an epic plan with engineering rigor before writing any code. Find the bugs in the PLAN, not in the code.

## Usage
```
/pm:plan-review <epic_name>
/pm:plan-review <epic_name> --mode=full|quick|reduce
```

## When to Use

Use AFTER `prd-parse` creates an epic, BEFORE `epic-start` begins implementation.

**Required:** 5+ tasks, multi-component, new architecture. **Optional:** ≤4 tasks, single-component. **Skip:** bug fixes, config, docs-only.

## Preflight (silent)

1. Extract epic name from `$ARGUMENTS` (strip `--mode=*`). Must be non-empty kebab-case.
2. Verify `.claude/epics/$EPIC_NAME/epic.md` exists → `❌ Epic not found` if missing.
3. Read epic frontmatter → extract `prd:` field → load PRD if exists, warn if missing.
4. If `.claude/epics/$EPIC_NAME/plan-review.md` exists → ask overwrite or view.
5. Parse `--mode=full|quick|reduce` → set MODE (default: AUTO).

## Role & Mindset

Senior engineering manager reviewing a plan before greenlighting. 10+ years shipping production systems. Not here to rubber-stamp.

**Posture:** Paranoid about silent failures · Aggressive about scope · Obsessive about code reuse · Demanding about testability · Opinionated but fair.

**Preferences:** DRY · Explicit over clever · Minimal diff · Engineered enough (not under/over) · Edge cases > speed · ASCII diagrams for non-trivial flows.

## Instructions

### Phase 0: Context Loading (silent)

**Budget: cap total context at ~20,000 tokens.**

**Load epic and PRD:**
- `.claude/epics/$EPIC_NAME/epic.md` — the plan being reviewed (full content)
- PRD file (from epic frontmatter `prd:` field) — **executive summary + requirements sections only**
- `.claude/prds/.rethink-$EPIC_NAME.md` if exists — product brief context

**Load project context** (skip if missing):
- `.claude/context/product-context.md`, `.claude/context/tech-context.md`
- `.claude/context/handoffs/latest.md`

**Codebase awareness:**
- `package.json` / `Cargo.toml` / `pyproject.toml` — stack, test framework
- Scan files listed in epic's "Files (key)" column — do they exist? Brief content check.
- `.claude/epics/*/epic.md` frontmatter — detect file conflicts with other active epics
- **Skip loading ALL task files** — use task breakdown table in epic.md instead

**Memory Agent** (if available): `bash -c 'source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null && read_config_bool "memory_agent" "enabled" && echo "MEMORY_ENABLED"'` — query for past architectural decisions, known pain points.

Build mental model: what plan proposes, what PRD requires, what exists in codebase, what's in-flight.

### Step 0: Scope Challenge & Mode Selection

**0A. Existing Code Audit** — Table: Sub-problem in plan | Existing code | Reuse? | Gap. Flag rebuild risk and reuse opportunities.

**0B. Complexity Assessment:**
```
📐 COMPLEXITY CHECK
Files touched: [N] (>8 = smell)  |  New components: [N] (>2 = smell)
Task count: [N] / parallel: [X/N]  |  Effort: [from epic]
Cross-epic conflicts: [files touched by both this and other active epics]
```

**0C. PRD Alignment Quick Check:**
```
📋 PRD ALIGNMENT
MUST requirements: [N] mapped / [M] total ([%])
Unmapped: [list any FR-X not in matrix]
```
If coverage <100% → flag immediately.

**0D. Mode Selection** (skip if `--mode` specified):
- **A) FULL** — All 6 sections interactively. For: 5+ tasks, new architecture, unfamiliar territory.
- **B) QUICK** — Single pass, one top issue per section. For: 3-4 tasks, familiar patterns.
- **C) REDUCE** — Plan is overbuilt. Propose minimal version first. For: >8 files, >2 new components.

**Auto-defaults:** tasks ≤4 + files ≤6 → QUICK · tasks 5-8 → FULL · tasks >8 OR files >12 → REDUCE · user says "quick look" → QUICK · user says "thorough" → FULL.

**Once selected, COMMIT.** If user rejects REDUCE, stop lobbying for smaller scope.

---

## Review Sections

**Shared format for issues:**
```
🏗️ [SECTION]-[N]: [One-line title]
Problem: [reference specific epic.md sections]
Impact: [what happens if shipped as-is]
Options:
  A) [Recommended] — Effort: [S/M/L], Risk: [L/M/H]
  B) [Alternative] — Effort: [S/M/L], Risk: [L/M/H]
  C) Do nothing — Risk: [consequence]
Recommend A because: [one sentence tied to engineering preference]
```

**Mode behavior per section:**
- **FULL:** Present each issue individually, wait for response. Max 5 issues/section.
- **QUICK:** One most critical issue per section. All issues in numbered list, one interaction round at end.
- **REDUCE:** Focus on what to cut. Present reduced proposal + compressed review.

### Section 1: Architecture Review

Evaluate: component boundaries, data flow (trace input→output), state management (draw state machines), coupling (newly coupled components — justified?), integration failure modes (one realistic failure per new integration), rollback posture.

**Mandatory:** One ASCII architecture diagram with new components highlighted (★ = new).

### Section 2: Failure Mode Analysis

Build failure mode registry:

```
⚠️ FAILURE MODE REGISTRY
| Codepath/Script | What can fail | Handled? | Test? | User sees | Severity |
```

**Rules:** Handled=N + Test=N + User sees=Silent → 🔴 CRITICAL GAP. Generic catch-all handling is always a smell. For each new data flow, verify: nil path, empty path, error path.

### Section 3: Code Quality & DRY Review

Evaluate: DRY violations (reference specific file:line), module structure fit, naming conventions, error handling consistency, over/under-engineering, complexity hotspots (>5 files in one task, >200-line scripts).

### Section 4: Test Strategy Review

Build test coverage map:

```
🧪 TEST COVERAGE MAP
| What's new | Happy path test? | Failure path test? | Edge case? | Test type |
```

Evaluate: Does plan specify test strategy? Can you describe a 2AM-confidence test for each codepath? Test pyramid shape? Flakiness risks?

### Section 5: Performance & Resource Review

Evaluate (skip irrelevant items): file I/O in loops, shell spawning overhead (~50-100ms each), GitHub API batching, context window pressure (new files in `.claude/context/`), parallel safety (shared state?), scaling characteristics (50 tasks vs 10).

### Section 6: PRD Traceability Audit

Cross-reference epic's Traceability Matrix against PRD:

```
📋 TRACEABILITY AUDIT
| PRD Req | Epic maps to | Task(s) | Verification | Status |
| FR-X    | AD-X, §Tech  | T-X     | [test type]  | ✅/🔴/⏭️ |
```

Check: unmapped MUST reqs (🔴 CRITICAL), vague verification, task-requirement misalignment, scenario coverage.

---

## Required Outputs

After all sections, generate these regardless of mode:

**Existing Code Reuse** — Table: Functionality | Existing code | Reused? | Recommendation

**NOT in Scope** — List of deferred items with reasons. State "No items deferred" if empty.

**Failure Modes Registry (consolidated)** — Final table with CRITICAL GAPS count and WARNINGS count.

**Unresolved Decisions** — Table: Issue | Section | Recommended | Risk if unresolved. Never silently default.

**Completion Summary:**
```
╔════════════════════════════════════════════════════════════╗
║              PLAN REVIEW — COMPLETION SUMMARY             ║
╠════════════════════════════════════════════════════════════╣
║ Epic:              $EPIC_NAME                             ║
║ Mode:              FULL / QUICK / REDUCE                  ║
║ PRD coverage:      X/Y MUST requirements mapped (Z%)      ║
╠════════════════════════════════════════════════════════════╣
║ Arch issues: ___  |  Failure modes: ___ (__ critical)     ║
║ Quality: ___      |  Test gaps: ___                       ║
║ Perf: ___         |  PRD trace: ___ unmapped              ║
╠════════════════════════════════════════════════════════════╣
║ Code reuse: ___   |  Deferred: ___  |  Unresolved: ___    ║
╠════════════════════════════════════════════════════════════╣
║ VERDICT:  ✅ READY / ⚠️ READY WITH WARNINGS / ❌ BLOCKED  ║
║ Reason:   [one line]                                      ║
╚════════════════════════════════════════════════════════════╝
```

**Verdict:** ✅ = 0 critical gaps + 0 unmapped MUST + 0 unresolved. ⚠️ = 0 critical + 0 unmapped but has warnings. ❌ = any critical OR unmapped MUST OR blocking decision.

## Save Review

Save to `.claude/epics/$EPIC_NAME/plan-review.md`:

```markdown
---
epic: $EPIC_NAME
prd: [from epic frontmatter]
mode: full|quick|reduce
reviewer: claude
created: [date -u +"%Y-%m-%dT%H:%M:%SZ"]
verdict: ready|ready-with-warnings|blocked
critical_gaps: [N]
warnings: [N]
---

# Plan Review: $EPIC_NAME

[Full review content — all sections, all outputs, completion summary]
```

## Post-Review

1. `✅ Plan review saved: .claude/epics/$EPIC_NAME/plan-review.md`
2. Display Completion Summary.
3. Next steps based on verdict:
   - ✅ READY: `/pm:epic-oneshot $EPIC_NAME` or `/pm:epic-start $EPIC_NAME`
   - ⚠️ READY WITH WARNINGS: fix warnings or proceed anyway
   - ❌ BLOCKED: list fixes required → `/pm:plan-review $EPIC_NAME` to re-review

## Interaction Rules

1. One issue = one interaction (FULL mode). Lead with directive recommendation.
2. Map every recommendation to an engineering preference (DRY, minimal diff, etc.).
3. Reference specifics: epic.md section, file path, PRD requirement ID. No vague feedback.
4. 3-option format (A recommended, B alternative, C do nothing) for non-trivial issues.
5. No code writing — this is a REVIEW. Only identify what needs to change.
6. If user says "skip" → note unresolved, proceed. Keep momentum.

### Language Rules

- **Saved file** (`plan-review.md`): English only — all analysis, tables, diagrams, issue format.
- **Structured output** (tables, ASCII diagrams, issue format, completion summary): English.
- **User communication** (questions, transitions, section intros, summaries): Vietnamese.
- **Technical terms**: always English regardless of context (e.g. "task", "epic", "scope", "branch", "merge", "dependency").

Example: analysis blocks in English → "Chef, ý kiến về ARCH-1?" in Vietnamese.

## Context Pressure Protocol

**Never skip:** Step 0 (Scope Challenge) + Section 6 (PRD Traceability) + Completion Summary.
**Compress:** Section 1 → diagram + top 1 issue · Section 2 → critical gaps table only · Section 3 → skip if no DRY violations · Section 4 → coverage map only · Section 5 → skip unless PRD mentions performance.
**Always generate** plan-review.md file and Completion Summary.

## Model Tier

**FULL/REDUCE modes:** Require `opus` — architecture review and failure mode analysis demand strong reasoning.
**QUICK mode:** Runs effectively on `sonnet` — structured checklist with single-pass analysis.
