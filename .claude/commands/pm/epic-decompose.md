---
model: opus
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Decompose

Break epic into concrete, actionable tasks.

## Usage
```
/pm:epic-decompose <feature_name>
```

## Preflight (silent — do not show progress to user)

1. **Validate `$ARGUMENTS`:**
   - If empty → `❌ Missing feature name. Usage: /pm:epic-decompose <feature_name>` and stop.
   - MUST match `^[a-z0-9][a-z0-9-]*[a-z0-9]$`. If invalid → `❌ Feature name must be kebab-case. Got: '$ARGUMENTS'` and stop.
2. **Locate epic:**
   - If `.claude/epics/$ARGUMENTS/epic.md` doesn't exist → `❌ Epic not found: .claude/epics/$ARGUMENTS/epic.md. Run: /pm:prd-parse $ARGUMENTS` and stop.
3. **Epic quality gate:**
   - Read epic. Check minimum requirements:
     - Has frontmatter with `name` and `status`
     - Has non-empty: Overview, Technical Approach, Task Breakdown Preview
   - If incomplete → `⚠️ Epic '$ARGUMENTS' is incomplete — missing: [list]. Run /pm:prd-parse $ARGUMENTS again.` and stop.
4. **Check existing tasks:**
   - Scan `.claude/epics/$ARGUMENTS/` for task files (`[0-9]*.md`).
   - If found → list them and ask: `⚠️ Found {count} existing tasks. Delete and recreate? (yes/no)`
   - If no → stop.
   - If yes → delete existing task files before proceeding.

## Role & Mindset

You are a senior tech lead who breaks down complex projects into tasks that engineers can pick up and run with. Your task breakdowns are known for:
- Each task is self-contained: an engineer can start without reading the whole epic
- Acceptance criteria are specific enough to be testable by a different engineer
- Dependencies are explicit — no hidden coupling between tasks
- The task order reflects the most efficient build sequence, front-loading risk

Your approach — ask these for every task:
- **Foundation first:** What needs to exist before anything else can work?
- **Independence:** Which tasks can be built and tested completely independently?
- **Risk front-loading:** What's the riskiest part? Build it early so we learn early.
- **Conflict detection:** Are there tasks that seem separate but touch the same files?
- **Completeness:** Does the sum of all tasks equal the entire epic scope?

## Instructions

### 0. Load Project Context (if available)

Read these files if they exist (skip silently if missing):
- `.claude/context/tech-context.md` — Technical stack and constraints
- `.claude/context/system-patterns.md` — Existing architecture patterns
- `.claude/context/project-structure.md` — Directory and module organization

Use this context to write tasks that reference real file paths, existing patterns, and correct conventions.

### 0b. Design Spec Detection (if available)

Check if `.claude/designs/$ARGUMENTS/specs/` directory exists and contains `.md` files:
- If yes: build a map of screen-name to spec-file-path (e.g., `dashboard` → `.claude/designs/$ARGUMENTS/specs/dashboard-spec.md`). This map will be used in Step 5 to enrich UI-related tasks.
- If no: skip silently — generate tasks without design references. All design enrichment steps below become no-ops.

### 1. Read & Analyze the Epic

Load `.claude/epics/$ARGUMENTS/epic.md` and extract:

- **Task Breakdown** — This is your enriched blueprint. Each task now has:
  - `What` field (2-3 sentences) → expand into Description + Implementation Steps
  - `PRD requirements` → derive scenario-linked Acceptance Criteria
  - `Interface receives/produces` → create Interface Contract section
  - `Key risk` → address in Technical Details edge cases
  - `Complexity` → set frontmatter complexity + recommended_model
  The enriched preview gives you raw material. Your job: expand each task's `What` into concrete Implementation Steps with file paths, function names, and logic.
- **Traceability Matrix** — Every MUST requirement must be covered by at least one task. Use this as your completeness checklist.
- **Architecture Decisions** — Reference these in task technical details so engineers understand the "why."
- **Implementation Strategy** — Phases define task ordering. Phase 1 tasks come first (sequential), Phase 2+ can parallelize.
- **Risks & Mitigations** — High-severity risks should map to early tasks (front-load risk).

**If epic has no Task Breakdown** (older format): analyze Technical Approach and Implementation Strategy to derive tasks yourself. Flag this: `ℹ️ Epic uses legacy format without enriched task preview. Deriving tasks from technical approach.`

### 2. Draft Task Plan & Confirm with User

Before creating any files, present the task plan for confirmation:

```
📋 Task plan for epic '$ARGUMENTS':

Phase 1 (sequential — foundation):
  T01: [Task name] — [1-line description] (est: Xd, model: sonnet ⚡)
  T02: [Task name] — [1-line description] (est: Xd, depends: T01, model: opus 🧠)

Phase 2 (parallel — core features):
  T03: [Task name] — [1-line description] (est: Xd, parallel: ✓, model: sonnet ⚡)
  T04: [Task name] — [1-line description] (est: Xd, parallel: ✓, model: sonnet ⚡)

Phase 3 (sequential — integration & polish):
  T05: [Task name] — [1-line description] (est: Xd, depends: T03+T04, model: sonnet ⚡)

──────────────────────────
Total: X tasks | Parallel: Y | Sequential: Z | Est: ~Xd total (~Yd critical path)
PRD coverage: X/Y MUST requirements mapped

Proceed? (yes / adjust / abort)
```

**Rules:**
- If user says "yes" → create task files.
- If user says "adjust" → ask what to change, update plan, re-confirm.
- If user says "abort" → stop without creating files.
- If task count > 10 → warn: `⚠️ ${count} tasks exceeds recommended max (10). Consider combining tasks.` Ask user whether to proceed or consolidate.

### 3. Task Design Principles

Each task MUST be:
- **Self-contained:** Has everything an engineer needs to start — description, technical details, acceptance criteria, file paths. An engineer should NOT need to read the epic to work on a task.
- **Testable independently:** Acceptance criteria can be verified without waiting for other tasks to complete.
- **Sized right:** 1-3 days of work. If larger → break it down. If smaller (< 4 hours) → combine with related task.
- **Ordered logically:** Foundation tasks first, then features (parallelizable), then integration.
- **Traceable:** Every task maps back to at least one PRD requirement via the epic's traceability matrix.
- **Interface-explicit:** Tasks with dependencies MUST specify exactly what they receive and produce. Reading the Interface Contract of T002 should tell you everything about what T001 produces, without reading T001's code.

For each task, verify:
- What files/modules does this touch? (list specific paths)
- What does "done" look like? (testable acceptance criteria)
- Does this block or get blocked by other tasks? (explicit `depends_on`)
- Can this run in parallel without file conflicts? (check `conflicts_with`)

### 3b. Complexity Scoring

For each task, evaluate complexity using these heuristics and assign `complexity` and `recommended_model` in frontmatter:

| Signal | Simple | Moderate | Complex |
|--------|--------|----------|---------|
| Files touched | 1-2 | 3-5 | 6+ |
| Estimated days | < 1d | 1-2d | 3d+ |
| Dependencies | None | 1-2 tasks | 3+ tasks or external |
| Nature of work | Config, docs, small fix | New feature, add endpoint | Refactor, architecture, cross-cutting |
| Scope | Modify existing | New + modify | New system / redesign |

**Model mapping:**
- `simple` → `sonnet` — Straightforward, well-scoped tasks
- `moderate` → `sonnet` — Standard feature work
- `complex` → `opus` — Architecture, refactoring, multi-system changes

**Conservative rule:** When a task falls between two levels, classify UP (e.g., borderline moderate/complex → `complex`/`opus`). It's better to over-resource than under-resource.

**Auto-classify as `complex`/`opus`:**
- Task touches 6+ files
- Task name contains "refactor", "architecture", "redesign", or "migration"
- Task has 3+ dependencies or cross-cutting concerns

**Default:** If complexity signals are unclear, default to `moderate`/`sonnet`.

### 4. Task Numbering Strategy

Use **gap numbering** to allow future insertions without renumbering:

```
Phase 1: 001.md, 002.md, 003.md
Phase 2: 010.md, 011.md, 012.md
Phase 3: 020.md, 021.md
Final:   090.md (verification/integration task)
```

Rules:
- Phase 1 starts at 001
- Phase 2 starts at 010
- Phase 3 starts at 020
- Verification/integration task is always the last: 090
- Gaps within phases allow inserting tasks later (e.g., 013, 014)
- Never exceed 3-digit numbering

### 5. Task File Format

For each task, create `.claude/epics/$ARGUMENTS/{number}.md` following the template in `rules/task-template.md`.

Key points:
- All sections marked "Required" in the template MUST be present
- **Implementation Steps** is the most critical section — expand the epic's `What` field into concrete code-level steps with file paths, function names, and logic
- **Acceptance Criteria** MUST use scenario-linked format: `**FR-N / scenario:** [condition]`
- **Interface Contract** is required for tasks with `depends_on` non-empty — specify receives/produces
- **Tests to Write** MUST have concrete test cases per AC, separated from Verification Checklist
- **Anchor Code** is optional — only for `complexity: complex` tasks (pseudocode skeleton)
- Frontmatter MUST include `prd_requirements: [FR-1, FR-2, ...]` linking to PRD requirement IDs

#### Design Spec Enrichment (only if screen specs were detected in Step 0b)

For each task that implements a UI screen or visual component:
- Match task to screen by name (e.g., task "Implement dashboard screen" matches screen `dashboard`)
- Add to task frontmatter: `design_spec: .claude/designs/{name}/specs/{screen}-spec.md`
- Add the spec file to the task's `files:` list
- Add to Implementation Steps (as the first step): "Read design spec at `.claude/designs/{name}/specs/{screen}-spec.md` for component tree, spacing tokens, color usage, and responsive breakpoints."
- If no matching screen spec exists for a task, do NOT add `design_spec` — leave the task unchanged

### 6. Task Content Quality Standards

**Context** — Explain WHY without requiring epic knowledge:
- ❌ Bad: "Part of the auth epic."
- ✅ Good: "Users currently can't sign in with SSO. This task creates the OAuth callback handler that will receive tokens from identity providers."

**Description** — Specific about approach, reference real paths:
- ❌ Bad: "Create user model"
- ✅ Good: "Create the user model in `src/models/user.ts` with email, password_hash, and created_at fields. Use the existing BaseModel pattern from `src/models/base.ts`. Password hashing uses bcrypt (already in package.json)."

**Acceptance Criteria** — Scenario-linked to PRD requirements:
- ❌ Bad: "Config loading works correctly"
- ✅ Good:
  "- [ ] **FR-1 / Happy path:** Config file loads → model returned in <50ms
   - [ ] **FR-1 / Edge case:** Config missing → fallback to current model, log warning to stderr
   - [ ] **NFR-1 / Performance:** Config loading adds <50ms latency (measure with `time`)"

**Implementation Steps** — Concrete code-level actions:
- ❌ Bad: "Implement the auth middleware"
- ✅ Good:
  "Step 1: Create `scripts/detect-model.sh`
   - Parse frontmatter field `model:` using grep/awk
   - Fallback chain: frontmatter > per-command override > tier default > current model
   - Output: echo model name to stdout
   Step 2: Create `config/model-tiers.json`
   - Structure: { tiers: {light: "haiku", ...}, overrides: {} }
   Step 3: Write tests
   - Test: command with frontmatter `model: opus` → returns "opus"
   - Test: missing config → returns current model (graceful fallback)"

**Tests to Write** — Specific test cases, not vague "add tests":
- ❌ Bad: "Write tests for the user model"
- ✅ Good:
  "Unit Tests:
   - `test/models/user.test.ts`
     - Test: User.create({email, password}) → stores hashed password
     - Test: User.findByEmail('nope@test.com') → returns null
     - Test: duplicate email → throws EMAIL_EXISTS error"

**Technical Details** — Reference actual code, not vague principles:
- ❌ Bad: "Use best practices"
- ✅ Good: "Follow the existing repository pattern in `src/repos/`. Add `UserRepo` with `create`, `findByEmail`, `findById` methods. See `PostRepo` for reference implementation."

**Verification Checklist** — Concrete commands, not "test it":
- ❌ Bad: "Run tests"
- ✅ Good: "Run `npm test -- --grep UserRepo`. Verify: 3 tests pass. Check coverage > 90%."

### 7. Mandatory Verification Task

Every epic MUST include a final verification/integration task (always numbered `090.md`):

```markdown
---
name: Integration verification & cleanup
status: open
phase: 3
priority: P0
depends_on: [all other task numbers]
parallel: false
---

# Task: Integration verification & cleanup

## Context
Final quality gate before epic completion. Ensures all tasks integrate correctly and all PRD requirements are met.

## Acceptance Criteria
- [ ] All other tasks in this epic are status: done
- [ ] Full build succeeds with no errors
- [ ] All existing tests pass (no regressions)
- [ ] New tests for this epic all pass
- [ ] [Epic-specific integration checks from Success Criteria]

## Verification
[Specific commands to run: build, lint, test suite, integration checks]
```

### 8. Dependency Graph

After creating tasks, generate a text-based dependency graph and include it in the epic update:

```
Dependency Graph:
  T001 ──→ T002 ──→ T020
                ──→ T021
  T010 (parallel) ─→ T090
  T011 (parallel) ─→ T090
  T012 (parallel) ─→ T090
  T020 ──────────→ T090

Critical path: T001 → T002 → T020 → T090 (~Xd)
```

### 9. Update Epic with Task Summary

After creating all tasks, append to `.claude/epics/$ARGUMENTS/epic.md`:

```markdown
## Tasks Created
| #   | Task                     | Phase | Parallel | Est. | Depends On | Status |
| --- | ------------------------ | ----- | -------- | ---- | ---------- | ------ |
| 001 | [Title]                  | 1     | no       | 1d   | —          | open   |
| 002 | [Title]                  | 1     | no       | 1d   | 001        | open   |
| 010 | [Title]                  | 2     | yes      | 2d   | 002        | open   |
| ... | ...                      | ...   | ...      | ...  | ...        | ...    |
| 090 | Integration verification | 3     | no       | 1d   | all        | open   |

### Summary
- **Total tasks:** {count}
- **Parallel tasks:** {parallel_count} (Phase 2)
- **Sequential tasks:** {sequential_count} (Phase 1 + 3)
- **Estimated total effort:** {sum of estimates}
- **Critical path:** {path description} (~{duration})

### Dependency Graph
{text-based graph from step 8}

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: [name]    | T001, T010 | ✅ Covered |
| FR-2: [name]    | T002       | ✅ Covered |
| NFR-1: [name]   | T090       | ✅ Covered |
```

### 10. Quality Checks

Before finalizing, self-audit against every item. If any fails → fix before saving:

- [ ] Every task has specific, testable acceptance criteria (not vague goals)
- [ ] Every task has a Verification section with concrete commands/checks
- [ ] Task sizes are 1-3 days each (flag any outliers)
- [ ] Dependencies form a valid DAG (no circular references)
- [ ] Parallel tasks don't modify the same files (cross-check `files` frontmatter)
- [ ] All PRD MUST requirements are covered (check against Traceability Matrix)
- [ ] No "orphan" tasks that don't map to any PRD requirement
- [ ] Verification task (090) exists and depends on all other tasks
- [ ] Task numbering follows gap strategy (Phase 1: 00x, Phase 2: 01x, Phase 3: 02x)
- [ ] Every task has `complexity` and `recommended_model` fields (missing fields default to `moderate`/`sonnet`)
- [ ] Epic file updated with Tasks Created summary, dependency graph, and PRD coverage

**Content Sufficiency (per task — check BEFORE saving):**
- [ ] Self-sufficiency: engineer can implement from task file alone, WITHOUT reading the epic
- [ ] Implementation Steps have ≥2 steps with specific file paths and logic descriptions
- [ ] Every file in `files:` frontmatter appears in Implementation Steps with what-to-do description
- [ ] Tests to Write has ≥1 concrete test case per acceptance criterion
- [ ] Complex tasks (`complexity: complex`) have Anchor Code section
- [ ] Tasks with dependencies (`depends_on` non-empty) have Interface Contract section
- [ ] Acceptance Criteria reference PRD requirement IDs (`**FR-1 / scenario:**` format)

If any content sufficiency check fails → improve task content before saving.

### 11. Post-Decomposition

1. **Confirm:** `✅ Created {count} tasks for epic: $ARGUMENTS`
2. **Show summary:**
   ```
   📊 Decomposition complete:
   Tasks: {count} ({parallel_count} parallel, {sequential_count} sequential)
   Critical path: {path} (~{duration})
   PRD coverage: {covered}/{total} MUST requirements
   ```
3. **Next steps:**
   ```
   📋 Next actions:
   → Sync to GitHub Issues:  /pm:epic-sync $ARGUMENTS
   → One-shot (sync now):    /pm:epic-oneshot $ARGUMENTS
   → View epic status:       /pm:epic-show $ARGUMENTS
   → Start first task:       /pm:issue-start {first_task_number}
   ```
