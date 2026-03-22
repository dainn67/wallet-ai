---
name: pm-prd-new
description: PRD New
# tier: heavy
---

# PRD New

Launch brainstorming for new product requirement document.

## Usage
```
/pm:prd-new <feature_name>
```

## Preflight (silent — do not show progress to user)

1. **Validate `$FEATURE_NAME`:**
   - MUST be non-empty. If empty → print `❌ Usage: /pm:prd-new <feature_name>` and stop.
   - MUST match `^[a-z0-9][a-z0-9-]*[a-z0-9]$` (kebab-case, no special chars, no spaces, no slashes).
   - If invalid → print `❌ Feature name must be kebab-case (e.g. "epic-verify", "smart-context"). Got: '$FEATURE_NAME'` and stop.
2. **Check existing PRD:**
   - If `.claude/prds/$FEATURE_NAME.md` exists → ask `⚠️ PRD '$FEATURE_NAME' already exists. Overwrite? (yes/no)`
   - If user says no → stop.
3. **Check draft resume:**
   - If `.claude/prds/.draft-$FEATURE_NAME.md` exists → ask `📝 Found unfinished draft for '$FEATURE_NAME'. Resume where you left off? (yes/no)`
   - If yes → read draft, skip completed discovery waves, continue from last checkpoint.
   - If no → delete draft and start fresh.
4. **Ensure directory:** `mkdir -p .claude/prds 2>/dev/null`

## Role & Mindset

You are a senior product manager with deep technical understanding. Your PRDs are known for:
- Uncovering hidden assumptions that teams miss
- Identifying failure modes before they become bugs
- Writing acceptance criteria so clear that any developer can implement without asking questions
- Balancing ambition with practical constraints

Your approach — apply all four lenses to every PRD:
- **Skeptic:** What could go wrong? What are we assuming? What's the worst-case scenario?
- **User:** What's the real pain? Is this the right solution? Would I use this?
- **Engineer:** Is this buildable? What are the technical risks? What's the simplest implementation?
- **PM:** What's the MVP? What can we cut without losing value? What's the timeline risk?

## Instructions

### 0. Load Project Context (if available)

Read these files if they exist (skip silently if missing):
- `.claude/context/product-context.md` — Existing users and use cases
- `.claude/context/tech-context.md` — Technical constraints and stack
- `.claude/context/project-brief.md` — Project goals and success criteria
- `.claude/prds/` — Scan existing PRD filenames to avoid overlap and understand feature landscape
- `.claude/rules-reference/prd-quality.md` — Quality standards (scale tables, requirement ID format, scenario format)

**Codebase scan (lightweight):**
- Read `package.json` / `Cargo.toml` / equivalent if exists — note language, framework, test setup
- Check `.claude/epics/*/epic.md` frontmatter for active epics (detect overlap)
- Scan `.claude/prds/` executive summaries for semantic overlap with this feature

**Memory Agent Context (if available):**
- Run: `bash -c 'source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null && read_config_bool "memory_agent" "enabled" && read_config_bool "memory_agent" "query_on_prd" && echo "MEMORY_ENABLED"'`
- If output contains "MEMORY_ENABLED":
  - Run: `source .claude/scripts/pm/lifecycle-helpers.sh && memory_query "project history related features decisions constraints for: $FEATURE_NAME" "markdown" "10"`
  - If non-empty response:
    - Present to yourself as context: `## Project History (from Memory)\n{response}`
    - Use this history to: ask more informed Wave 1 questions, pre-identify constraints, detect overlap with past features
    - Note which Wave 1 questions the memory already answers (skip or pre-fill in synthesis)
  - If empty response or command fails: show `⚠️ Memory Agent offline — project history unavailable. Run: ccpm-memory start` and continue without memory context
- If not enabled: skip entirely (no output, no delay)

**Product Brief (from prd-rethink, if available):**
- If `.claude/prds/.rethink-$FEATURE_NAME.md` exists:
  - Read the brief fully
  - Show: `📝 Loading Product Brief from rethink session...`
  - Pre-fill Discovery with: problem framing, target user, scope decision, key decisions
  - During Wave 1-3: skip questions already answered in brief, focus on gaps listed in "Open Questions"
  - During Synthesis: inherit scale recommendation, scope boundary, key bet from brief
  - If brief `status: ready-for-prd` → can use Express Path even without 150+ words from user

Use this context to: ask more informed questions, avoid re-inventing existing features, detect overlap, pre-fill constraints, write a PRD that fits the project's architecture and user base.

### 1. Discovery (MANDATORY — Do not skip)

Before writing the PRD, conduct a discovery conversation. Ask questions in waves — don't overwhelm with all questions at once.

**CRITICAL — Turn behavior:** Each wave is ONE turn. Ask the questions, then **STOP completely**. Do NOT generate follow-up messages like "waiting for your answer" or "take your time". Do NOT save the draft checkpoint until AFTER the user has responded. The checkpoint saves should happen at the START of the next turn (after receiving answers), not at the end of the current turn.

**Adaptive entry:** Choose the right path based on user input:
- **YOLO Mode:** If user provides >300 words, attaches a spec document, or explicitly says "skip discovery" / passes `--yolo` → skip discovery entirely. Generate full PRD draft immediately. Show: "Generated PRD with X requirements, Y scenarios. Review?" User can: Accept / Edit inline / Restart with discovery.
- **Express Path:** If user provides 150-300 words with clear requirements → skip to **Express Path** below.
- **Standard:** Otherwise, start with Wave 1.

---

**Wave 1 — Problem Space (ask first):**
- What specific problem does this solve? Can you describe a concrete scenario where someone hits this pain?
- Who experiences this problem? How often? How painful is it (annoying vs blocking)?
- What happens today without this feature? What workarounds exist?
- Why solve this NOW? What triggered this need?

→ Ask these questions then STOP. When user responds, save checkpoint to `.claude/prds/.draft-$FEATURE_NAME.md` with discovery notes, then proceed to Wave 2.

If Project History was loaded from Memory Agent, reference it when synthesizing Wave 1 answers.
Skip questions that memory already answered. Pre-fill constraints from memory.

**Wave 2 — Solution & Users (ask after understanding problem):**
- Do you have a specific solution in mind, or just the problem?
- What's the minimum viable version? What's the dream version?
- Who are the distinct user types for this feature? (e.g., solo dev vs team lead vs CI bot)
- Are there examples from other products/tools that do this well?
- What should this explicitly NOT do?

→ Ask these questions then STOP. When user responds, update draft checkpoint, then proceed to Wave 3.

**Wave 3 — Constraints & Risks (ask after solution direction is clear):**
- What technical constraints exist? (existing systems, backward compatibility, performance)
- What timeline and resource constraints exist?
- What's the biggest risk? What could make this fail?
- Are there dependencies on other features, PRDs, or external systems?

→ Ask these questions then STOP. When user responds, update draft checkpoint, then check completion gate.

---

**Express Path (for detailed upfront input):**
When user provides comprehensive requirements upfront:
1. Parse their input and map it to the discovery areas above.
2. Summarize your understanding in a structured format:
   - "**Problem:** [your understanding]"
   - "**Users:** [identified personas]"
   - "**Solution:** [proposed approach]"
   - "**Biggest risk:** [what you see]"
3. Ask: "Here's my understanding — what's missing or wrong?"
4. Fill gaps with targeted follow-up questions (1-3 questions max, not full waves).
5. Proceed to writing.

---

**Completion gate:** Only proceed to writing when ALL of these are true:
1. ✅ You can explain the problem in one sentence
2. ✅ You know the primary user persona(s)
3. ✅ You understand what "done" looks like (exit criteria)
4. ✅ You know the biggest risk or unknown
5. ✅ You know what's explicitly out of scope

If any gate fails → ask targeted follow-up. Do NOT accept vague answers. Push for specifics.

**Handling multi-wave responses:** If the user answers questions from multiple waves in a single message, acknowledge all answers and only ask remaining gaps. Do not re-ask what's already been answered.

### 1b. Synthesis (MANDATORY — after completion gate)

Present structured summary before writing:

```
**Blueprint for '$FEATURE_NAME':**
- **Problem (1 sentence):** [...]
- **Primary users:** [persona 1], [persona 2]
- **Solution approach:** [1-2 sentences]
- **Scale:** Small / Medium / Large (see .claude/rules-reference/prd-quality.md)
- **Key risk:** [...]
- **Out of scope:** [...]
- **Requirement estimate:** ~X FR, ~Y NFR
```

Ask: "Proceed with this blueprint? Or adjust?"
Only begin writing after user confirms.

**Scale detection heuristics:**
- **SMALL:** Bug fix, config change, single-file, ≤3 requirements → compact PRD (~1 page)
- **MEDIUM:** Standard feature, 3-8 requirements, 2-4 components → full template (default)
- **LARGE:** Multi-component, migration, redesign, 8+ requirements → full + Migration Strategy + Rollback Plan

### 2. PRD Content Guidelines

**Scale adaptation:** Use the scale from Synthesis to adjust depth per `.claude/rules-reference/prd-quality.md` Section Requirements table:
- **SMALL:** Skip Target Users (inline note), skip User Stories (AC in Requirements), 1-2 sentence Executive Summary, 1 risk entry. Target ~1 page.
- **MEDIUM:** Full template as below. Target 2-4 pages.
- **LARGE:** Full template + add Migration Strategy + Rollback Plan sections. Target 4-8 pages.

Write each section with depth, not filler. Here's what "good" looks like for each section:

#### Executive Summary (3-5 sentences)
State: what we're building, who it's for, what problem it solves, and why now.
- ❌ Bad: "This feature adds authentication."
- ✅ Good: "We're adding OAuth2-based authentication to enable enterprise users to sign in with their existing identity providers. Currently, 40% of trial-to-paid conversions stall at the account creation step because enterprises require SSO."

#### Problem Statement
Describe the problem from the USER's perspective, not the system's.
Include: Who is affected, frequency, severity, cost of inaction.
Include: What solutions/workarounds exist today and why they're insufficient.

#### Target Users
Define 2-4 distinct personas who will interact with this feature. For each:
- **Name/Role** — Who they are (e.g., "Solo Developer", "Team Lead", "CI Pipeline")
- **Context** — When/how they encounter this feature
- **Primary need** — What they want from it
- **Pain level** — How much the current gap hurts them (low/medium/high)

This section directly feeds User Stories — every story must map to a persona.

#### User Stories
Write stories that capture BEHAVIOR, not features. Each story MUST reference a persona from Target Users and include testable acceptance criteria.

Format:
```
**US-N: [Title]**
As a [persona], I want to [action] so that [outcome].

Acceptance Criteria:
- [ ] [Testable condition with specific threshold]
- [ ] [Testable condition with specific threshold]
```

Quality bar:
- ❌ Bad: "As a user, I want to log in."
- ✅ Good: "As an enterprise admin, I want to configure SSO for my org so that my team doesn't need separate passwords. AC: Admin can select from Google, Okta, Azure AD; configuration takes <5 minutes; team members can sign in within 30 seconds of setup."

#### Requirements

Use requirement IDs and scenarios per `.claude/rules-reference/prd-quality.md`.

**Functional Requirements (MUST):**
Ordered by priority. Each requirement has an ID, description, and >=1 scenario.

```
**FR-1: [Title]**
[Description — what happens if we skip it? If it breaks core value → MUST.]

Scenario: [Happy path]
- GIVEN [precondition]
- WHEN [action]
- THEN [expected result]

Scenario: [Edge case]
- GIVEN [precondition]
- WHEN [action]
- THEN [expected result]

**FR-2: [Title]**
...
```

**Functional Requirements (NICE-TO-HAVE):**
Same format with `NTH-` prefix. Mark with reasoning why deferred.

**Non-Functional Requirements:**
`NFR-` prefix. Performance, security, compatibility, accessibility. Each with measurable threshold (scenarios optional, thresholds required).

#### Success Criteria
Every criterion MUST be measurable. If you can't measure it, rewrite it.
- ❌ Bad: "Users are satisfied."
- ✅ Good: "80% of new users complete onboarding within 3 minutes."

Include: how and when each criterion will be measured.

#### Risks & Mitigations
Identify 3-5 key risks. For each:

| Risk                  | Severity     | Likelihood   | Mitigation                    |
| --------------------- | ------------ | ------------ | ----------------------------- |
| [What could go wrong] | High/Med/Low | High/Med/Low | [How we prevent or handle it] |

Consider: technical risks, adoption risks, scope risks, dependency risks.

#### Constraints & Assumptions
- **Constraints:** Hard limits we must work within (technical, timeline, resource).
- **Assumptions:** Things we believe to be true. For each: "If wrong, then [consequence]."

#### Out of Scope
Explicit list of what we're NOT building and WHY. This prevents scope creep.
Format: `- [Thing] — [Why it's out of scope for this iteration]`

#### Dependencies
External and internal dependencies that could block or delay.
Format: `- [Dependency] — [Owner] — [Status: resolved/pending/blocked]`

### 3. File Format

Save the completed PRD to: `.claude/prds/$FEATURE_NAME.md`

```markdown
---
name: $FEATURE_NAME
description: [Brief one-line description]
status: backlog
priority: [P0/P1/P2 — determined during discovery]
scale: [small/medium/large — from synthesis]
created: [Run: date -u +"%Y-%m-%dT%H:%M:%SZ"]
updated: null
---

# PRD: $FEATURE_NAME

## Executive Summary
...

## Problem Statement
...

## Target Users
...

## User Stories
...

## Requirements
### Functional Requirements (MUST)
...
### Functional Requirements (NICE-TO-HAVE)
...
### Non-Functional Requirements
...

## Success Criteria
...

## Risks & Mitigations
...

## Constraints & Assumptions
...

## Out of Scope
...

## Dependencies
...

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, ...]
  nice_to_have: [NTH-1, ...]
  nfr: [NFR-1, ...]
scale: [small/medium/large]
discovery_mode: [full/express/yolo]
validation_status: pending
last_validated: null
```

### 4. Frontmatter Guidelines
- **name**: Exact feature name (same as `$FEATURE_NAME`)
- **description**: Concise one-line summary derived from Executive Summary
- **status**: Always `backlog` for new PRDs (first status in lifecycle: `backlog → ready → in-progress → done`)
- **priority**: Set based on discovery — `P0` (critical), `P1` (important), `P2` (nice-to-have)
- **scale**: From synthesis step — `small`, `medium`, or `large`
- **created**: Current datetime from `date -u` command
- **updated**: `null` for new PRDs — `prd-edit` sets this on modification

### 5. Quality Checks

Before saving, self-audit against every item. If any fails → fix before saving:

- [ ] All required sections present and non-empty per scale (see `.claude/rules-reference/prd-quality.md`)
- [ ] Executive Summary answers: what, who, why, why now
- [ ] Target Users has 2+ distinct personas with pain levels (MEDIUM/LARGE only)
- [ ] Every User Story maps to a persona and has testable acceptance criteria (MEDIUM/LARGE only)
- [ ] Requirements use ID format (FR-1, NTH-1, NFR-1) with GIVEN/WHEN/THEN scenarios
- [ ] Success criteria are measurable with specific numbers/thresholds and measurement method
- [ ] Risks table has entries per scale (1 SMALL, 3+ MEDIUM, 5+ LARGE) with severity, likelihood, mitigation
- [ ] Assumptions each state what breaks if wrong
- [ ] Out of scope is explicit about what AND why
- [ ] No duplication between sections
- [ ] `_Metadata` block has correct requirement_ids list matching actual IDs in document

### 6. Post-Creation

1. **Clean up:** Delete draft file if exists: `rm -f .claude/prds/.draft-$FEATURE_NAME.md`
2. **Confirm:** `✅ PRD created: .claude/prds/$FEATURE_NAME.md`
3. **Summary:** Show a 3-5 line recap: problem, primary users, key risks, priority.
4. **Next steps:**
   ```
   📋 Next actions:
   → Validate PRD:   /pm:prd-validate $FEATURE_NAME
   → Review & edit:  /pm:prd-edit $FEATURE_NAME
   → Create epic:    /pm:prd-parse $FEATURE_NAME
   → View all PRDs:  /pm:prd-list
   ```
