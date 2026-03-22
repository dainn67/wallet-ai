---
name: pm-prd-parse
description: PRD Parse
# tier: heavy
---

# PRD Parse

Convert PRD to technical implementation epic.

## Usage
```
/pm:prd-parse <feature_name>
```

## Preflight (silent — do not show progress to user)

1. **Validate `$FEATURE_NAME`:**
   - If empty → `❌ Missing feature name. Usage: /pm:prd-parse <feature_name>` and stop.
   - MUST match `^[a-z0-9][a-z0-9-]*[a-z0-9]$`. If invalid → `❌ Feature name must be kebab-case. Got: '$FEATURE_NAME'` and stop.
2. **Locate PRD:**
   - If `.claude/prds/$FEATURE_NAME.md` doesn't exist → `❌ PRD not found: .claude/prds/$FEATURE_NAME.md. Run: /pm:prd-new $FEATURE_NAME` and stop.
3. **PRD quality gate:**
   - Read PRD. Check minimum requirements:
     - Has frontmatter with `name` and `status` fields
     - Has non-empty content in: Executive Summary, Problem Statement, Requirements
   - If any missing → `⚠️ PRD '$FEATURE_NAME' is incomplete — missing: [list]. Run: /pm:prd-edit $FEATURE_NAME to complete it first.` and stop.
   - Check requirement format:
     - If Requirements section has FR-1/NFR-1 format IDs → good, proceed
     - If no IDs → `⚠️ PRD uses legacy format without requirement IDs. Recommend: /pm:prd-edit $FEATURE_NAME to add IDs. Continuing with auto-assigned IDs.`
   - Check validation status:
     - If `_Metadata.validation_status` exists and is "failed" → `⚠️ PRD failed validation. Consider: /pm:prd-validate $FEATURE_NAME first.` (warn, don't block)
4. **Check existing epic:**
   - If `.claude/epics/$FEATURE_NAME/epic.md` exists → ask `⚠️ Epic '$FEATURE_NAME' already exists. Overwrite? (yes/no)`
   - If no → stop.
5. **Check overlap with active epics:**
   - Scan `.claude/epics/*/epic.md` for epics with `status: in-progress` or `status: backlog`.
   - If any epic's scope overlaps significantly with this PRD → warn: `⚠️ Potential overlap with epic '[name]' ([status]). Continue anyway? (yes/no)`
6. **Ensure directory:** `mkdir -p .claude/epics/$FEATURE_NAME 2>/dev/null`

## Role & Mindset

You are a principal engineer who translates product vision into bulletproof technical plans. Your epics are known for:
- Identifying the simplest architecture that meets all requirements
- Spotting integration risks and dependency traps early
- Breaking work into tasks that can be built and tested independently
- Making trade-off decisions explicit with clear rationale

Your approach — apply all five lenses:
- **Simplicity:** What is the simplest way to build this that we won't regret?
- **Risk:** Where are the technical risks and unknowns? What's the hardest part?
- **Reuse:** What existing code, patterns, or infrastructure can we leverage?
- **Regret:** What would I regret not thinking about in 2 weeks?
- **Parallelism:** What can run in parallel vs what must be sequential?

## Instructions

### 0. Load Project Context (if available)

Read these files if they exist (skip silently if missing):
- `.claude/context/tech-context.md` — Technical stack and constraints
- `.claude/context/system-patterns.md` — Existing architecture patterns
- `.claude/context/project-structure.md` — Directory and module organization
- `.claude/context/product-context.md` — User personas and use cases
- `.claude/rules-reference/prd-quality.md` — Quality standards (scale tables, section requirements)

Additionally, scan the codebase structure to understand:
- Existing modules and their responsibilities
- File naming and organization conventions
- Test patterns already in use
- Script/command patterns (for CCPM-specific features)

Use this context to create an epic that leverages existing patterns and avoids reinventing.

#### Design System (if available)

**Only if** `.claude/designs/$FEATURE_NAME/` directory exists:
- Read `.claude/designs/$FEATURE_NAME/design-system.md` if it exists — store as design context (color palette, typography, spacing scale, component patterns) for epic generation
- If `.claude/designs/$FEATURE_NAME/specs/` directory has files — list spec filenames for task enrichment later
- If `design-system.md` exists but `specs/` is empty or missing — use design system context only, skip spec references

**Otherwise:** Skip this section entirely. No warning, no error.

### 1. Read & Deeply Analyze the PRD

Load `.claude/prds/$FEATURE_NAME.md` and perform deep analysis:

**For each requirement, ask:**
- What's the simplest implementation that fully satisfies this?
- What could go wrong? What are the edge cases?
- Does this conflict with any other requirement in this PRD?
- Can we reuse existing code or patterns from context?
- What's the testing strategy for this requirement?

**Quick lookup — if PRD has `## _Metadata` section:**
- Read `requirement_ids` list for quick inventory (avoid re-counting from prose)
- Read `scale` for epic depth adaptation
- Read `validation_status` for quality confidence

**Extract and organize:**
- **Requirement IDs** from Requirements section → map directly to Traceability Matrix. If PRD has FR-1, FR-2... use those exact IDs. If PRD lacks IDs → assign during analysis (FR-1, FR-2... in order). Note in epic: "Requirement IDs assigned by prd-parse. Consider /pm:prd-edit to update PRD source."
- **Personas** from Target Users section → these drive UX and API design decisions
- **Priority** from frontmatter → P0 requirements are non-negotiable in task breakdown
- **MUST vs NICE-TO-HAVE** from Requirements → NICE-TO-HAVE may become separate follow-up epic
- **Risks** from Risks & Mitigations → carry forward into technical risk assessment
- **Success Criteria** → map each to a verifiable technical check

### 2. Clarification Round (if needed)

If the PRD has ambiguities that affect architecture, ask the user BEFORE writing the epic. Group questions into one message:

```
🔍 I found a few technical ambiguities in the PRD that affect implementation:

1. [Question about architecture choice]
2. [Question about unclear requirement]
3. [Question about constraint/priority trade-off]

I can proceed with my best judgment if you prefer — I'll document assumptions.
```

**Rules:**
- Maximum 5 questions. If more ambiguity exists, make a judgment call and document it.
- If user says "use your judgment" → proceed and document every assumption in the epic.
- Do NOT ask about things you can determine from project context.
- Do NOT re-ask questions already answered in the PRD.

### 3. Technical Analysis (internal — think through before writing)

Before writing the epic, structure your thinking:

- **Architecture:** What components/modules are needed? How do they connect? Draw the dependency graph mentally.
- **Data flow:** How does data move through the system for each user story?
- **Integration points:** What existing systems/commands/scripts does this touch? List specific files.
- **Critical path:** What must be built first because everything else depends on it?
- **Risks:** What's the hardest part? Where are we most likely to get stuck or underestimate?
- **Trade-offs:** What are we choosing and why? What did we reject and why?
- **Testing strategy:** How do we verify each requirement? Unit, integration, manual?
- **Scale:** Read `scale` from PRD frontmatter or _Metadata. If missing, infer:
  - SMALL: ≤3 FR requirements, single component, <3 day estimate
  - MEDIUM: 3-8 FR requirements, 2-4 components (default)
  - LARGE: 8+ FR requirements, or migration/redesign, or multi-system

### 4. Epic Content Guidelines

**Scale adaptation:** Reference `.claude/rules-reference/prd-quality.md` for which sections to include per scale.
- **SMALL:** Skip Architecture Decisions (note approach inline in Overview). Single-phase Implementation Strategy. 1-3 tasks in Task Breakdown.
- **MEDIUM:** Full template as defined below.
- **LARGE:** Full template + add Migration Strategy and Rollback Plan sections.

Write each section with substance, not boilerplate:

#### Overview
Not just "what" but "why this approach." Explain the architectural reasoning in 3-5 sentences.
- ❌ Bad: "This epic implements user authentication."
- ✅ Good: "We'll add JWT-based auth using the existing Express middleware chain. We chose JWT over sessions because our API is stateless and serves multiple client types. The main risk is token refresh handling for long-lived mobile sessions."

#### Architecture Decisions
Use ADR (Architecture Decision Record) format for each significant decision:

```
### AD-N: [Decision Title]
**Context:** [What situation requires a decision]
**Decision:** [What we chose]
**Alternatives rejected:** [What we didn't choose and why]
**Trade-off:** [What we gain vs what we lose]
**Reversibility:** [Easy/Hard to reverse if wrong]
```

Quality bar:
- ❌ Bad: "Use PostgreSQL."
- ✅ Good: "Use PostgreSQL (already in our stack) with a new `auth` schema. Considered adding Redis for sessions but JWT eliminates that need. Trade-off: larger token payloads but no session store to manage. Easy to reverse — schema is isolated."

##### Design System Integration (if design artifacts available)

**Only if** design system was loaded in Step 0, add an Architecture Decision:

```
### AD-N: Design System
**Context:** Design system generated via `/pm:prd-design` before epic creation.
**Decision:** Use design system at `.claude/designs/$FEATURE_NAME/design-system.md` as the visual language foundation. All UI tasks reference design tokens instead of hardcoding values.
**Source:** `.claude/designs/$FEATURE_NAME/design-system.md`
**Key choices:** [Summarize from design system: primary color, typography pairing, component style]
**Trade-off:** Consistent UI across tasks, but requires all implementers to read design system.
**Reversibility:** Easy — design system is a reference, not a code dependency.
```

**Otherwise:** Skip — do not add a design system AD.

#### Technical Approach
Be specific about implementation. Reference actual file paths, existing patterns, and modules. Organize by component/layer — only include sections relevant to this epic.

For each component:
- What it does and why it exists
- Key files to create or modify (specific paths)
- Patterns to follow from existing codebase
- Integration points with other components

#### Traceability Matrix
Map EVERY PRD requirement to its epic coverage. This ensures nothing is missed:

```
| PRD Requirement | Epic Coverage                     | Task(s) | Verification       |
| --------------- | --------------------------------- | ------- | ------------------ |
| FR-1: [name]    | §Technical Approach / [component] | T1, T3  | Unit test + manual |
| FR-2: [name]    | §Technical Approach / [component] | T2      | Integration test   |
| NFR-1: [name]   | §Architecture Decisions / AD-2    | T5      | Load test          |
| NTH-1: [name]   | Deferred to follow-up             | —       | —                  |
```

Rules:
- Every MUST requirement must map to at least one task
- NICE-TO-HAVE requirements can be deferred — document in "Deferred / Follow-up" section
- If a requirement can't be mapped → flag it as a gap and discuss with user

#### Implementation Strategy
Describe the build order and rationale:
1. **Phase 1 (Foundation):** What must be built first — the critical path
2. **Phase 2 (Core features):** Main functionality, can be parallelized
3. **Phase 3 (Polish):** Integration, edge cases, documentation

For each phase: what's included, why this order, what's the exit criterion.

#### Task Breakdown

Enriched preview — each task is a mini-spec that feeds `epic-decompose` with enough context to generate detailed task files. This is the **handoff document** between architect (you) and tech lead (epic-decompose). Richer preview = richer tasks = fewer implementation issues.

```
##### T1: [Task name]
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Depends:** — | **Complexity:** [simple|moderate|complex]
- **What:** [2-3 sentences. Be specific about approach, not just outcome. Reference file paths and existing patterns.]
- **Key files:** `path/to/file.sh`, `path/to/other.md`
- **PRD requirements:** FR-1, FR-2
- **Key risk:** [1 sentence — what could go wrong or be underestimated]
- **Interface produces:** [What downstream tasks will consume from this task. Skip if no dependents.]

##### T2: [Task name]
- **Phase:** 2 | **Parallel:** yes | **Est:** 2d | **Depends:** T1 | **Complexity:** complex
- **What:** [2-3 sentences]
- **Key files:** `path/to/modified.ts`, `path/to/new.ts`
- **PRD requirements:** FR-3
- **Key risk:** [1 sentence]
- **Interface receives from T1:** [What this task expects T1 to have produced — file, function, format]
- **Interface produces:** [For T3 or downstream]
```

Quality bar for "What" field:
- ❌ Bad: "Create the config system"
- ✅ Good: "Create `scripts/detect-model.sh` that reads command frontmatter `model:` field, falls back to tier lookup in `config/model-tiers.json`, then to current model. Uses existing `parse_frontmatter()` from `scripts/utils.sh`."

##### Design Spec Enrichment (if screen specs available)

**Only if** screen spec files were found in `.claude/designs/$FEATURE_NAME/specs/`:
- For each task that involves UI implementation (task description mentions screens, components, or UI):
  - Add to the task's "What" field: "Reference design spec: `.claude/designs/$FEATURE_NAME/specs/{screen}-spec.md`"
  - Add to "Key files": the relevant spec file path
- This helps `epic-decompose` generate tasks with embedded design references.

**Otherwise:** Skip — no spec references in tasks.

Rules:
- ≤10 tasks. Each 1-3 days.
- Every MUST requirement from PRD appears in at least one task's PRD requirements.
- Interface receives/produces only needed for tasks with dependencies.
- Complexity heuristics: files touched, days, dependency count, nature of work.

#### Risks & Mitigations

| Risk             | Severity     | Likelihood   | Impact        | Mitigation              |
| ---------------- | ------------ | ------------ | ------------- | ----------------------- |
| [Technical risk] | High/Med/Low | High/Med/Low | [What breaks] | [How we prevent/handle] |

Carry forward risks from PRD + add technical risks discovered during analysis.
Minimum 3 risks.

#### Success Criteria (Technical)
Map back to PRD success criteria, adding technical verification methods:

```
| PRD Criterion | Technical Metric       | Target      | How to Measure      |
| ------------- | ---------------------- | ----------- | ------------------- |
| [From PRD]    | [Technical equivalent] | [Threshold] | [Test/tool/command] |
```

### 5. File Format

Create: `.claude/epics/$FEATURE_NAME/epic.md`

```markdown
---
name: $FEATURE_NAME
status: backlog
created: [Run: date -u +"%Y-%m-%dT%H:%M:%SZ"]
progress: 0%
priority: [Inherit from PRD frontmatter, or P1 if not specified]
prd: .claude/prds/$FEATURE_NAME.md
task_count: [Number of tasks in breakdown]
github: [Will be updated when synced]
---

# Epic: $FEATURE_NAME

## Overview
[Technical summary with architectural reasoning — not just "what" but "why this approach." 3-5 sentences.]

## Architecture Decisions
### AD-1: [Decision Title]
**Context:** ...
**Decision:** ...
**Alternatives rejected:** ...
**Trade-off:** ...
**Reversibility:** ...

## Technical Approach
### [Component/Layer 1]
[Specific implementation details, file paths, existing patterns to reuse]

### [Component/Layer 2]
[...]

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| ...             | ...           | ...     | ...          |

## Implementation Strategy
### Phase 1: Foundation
[What, why, exit criterion]
### Phase 2: Core
[What, why, exit criterion]
### Phase 3: Polish
[What, why, exit criterion]

## Task Breakdown

##### T1: [Task name]
- **Phase:** 1 | **Parallel:** no | **Est:** Xd | **Depends:** — | **Complexity:** [simple|moderate|complex]
- **What:** [2-3 sentences]
- **Key files:** [paths]
- **PRD requirements:** [FR-IDs]
- **Key risk:** [1 sentence]

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| ...  | ...      | ...        | ...    | ...        |

## Dependencies
[External/internal dependencies — owner, status, mitigation if blocked]

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| ...           | ...              | ...    | ...            |

## Estimated Effort
[Total estimate, critical path duration, phases timeline]

## Deferred / Follow-up
[NICE-TO-HAVE requirements deferred from this epic — what and why]
```

### 6. Frontmatter Guidelines
- **name**: Exact feature name (same as `$FEATURE_NAME`)
- **status**: Always `backlog` for new epics (lifecycle: `backlog → in-progress → review → done`)
- **created**: Current datetime from `date -u` command
- **progress**: Always `0%` for new epics
- **priority**: Inherit from PRD frontmatter. If PRD has no priority, default to `P1`
- **prd**: Relative path to source PRD file
- **task_count**: Number of tasks in breakdown preview (helps dashboard)
- **github**: Placeholder `""` — updated by `epic-sync`

### 7. Quality Checks

Before saving, self-audit against every item. If any fails → fix before saving:

- [ ] All PRD MUST requirements appear in Traceability Matrix with task mapping
- [ ] No PRD requirement is left unmapped (NICE-TO-HAVE explicitly deferred)
- [ ] Architecture decisions use ADR format: chose, rejected, WHY, trade-off
- [ ] Technical Approach references specific file paths and existing patterns
- [ ] Task breakdown has ≤10 tasks, each with enriched mini-spec (What, Key files, PRD requirements)
- [ ] No two parallel tasks touch the same files
- [ ] Risks table has ≥3 entries with severity, likelihood, and mitigation
- [ ] Success criteria map back to PRD criteria with measurable thresholds
- [ ] Implementation Strategy has clear phase ordering with exit criteria
- [ ] Deferred section lists all NICE-TO-HAVE items not in current scope

### 8. Post-Creation

1. **Confirm:** `✅ Epic created: .claude/epics/$FEATURE_NAME/epic.md`
2. **Summary:** Show compact overview:
   - Architecture decisions (1 line each)
   - Task count + parallel ratio (e.g., "8 tasks, 5 parallelizable")
   - Critical path duration
   - Top risk
3. **Coverage report:** `📊 PRD coverage: X/Y MUST requirements mapped, Z deferred to follow-up`
4. **Next steps:**
   ```
   📋 Next actions:
   → Review epic plan:  /pm:plan-review $FEATURE_NAME
   → Decompose into tasks:  /pm:epic-decompose $FEATURE_NAME
   → One-shot (tasks + sync): /pm:epic-oneshot $FEATURE_NAME
   → View epic details:      /pm:epic-show $FEATURE_NAME
   ```

## IMPORTANT
- Aim for as few tasks as possible (≤10). Each task should be independently buildable and testable.
- Identify ways to simplify. Look for existing functionality to reuse instead of building new.
- If the PRD is unclear on technical approach, make a decision and document your reasoning in Architecture Decisions.
- NEVER skip the Traceability Matrix — it is the contract between PRD and implementation.
- Carry forward PRD priority and personas — they inform task ordering and UX decisions.
