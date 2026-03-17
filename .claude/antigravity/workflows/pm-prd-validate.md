---
name: pm-prd-validate
description: PRD Validate
---

# PRD Validate

Validate a PRD for completeness, correctness, and coherence before parsing to epic.

## Usage
```
/pm:prd-validate <feature_name>
```

## Preflight (silent)

1. **Validate `$FEATURE_NAME`:**
   - If empty → `❌ Usage: /pm:prd-validate <feature_name>` and stop.
   - MUST match `^[a-z0-9][a-z0-9-]*[a-z0-9]$`. If invalid → `❌ Feature name must be kebab-case. Got: '$FEATURE_NAME'` and stop.
2. **Locate PRD:**
   - If `.claude/prds/$FEATURE_NAME.md` doesn't exist → `❌ PRD not found: .claude/prds/$FEATURE_NAME.md` and stop.
3. **Ensure directory:** `mkdir -p .claude/prds 2>/dev/null`

## Role & Mindset

You are a critical reviewer — NOT the author. Your job is to find gaps, ambiguities, and weaknesses. Apply the Skeptic lens aggressively.

**RULE:** You MUST find at least 1 issue (warning or critical). If initial review finds zero issues, review again more carefully. A "perfect" PRD with zero findings is more likely to indicate a shallow review than a flawless document.

## Instructions

### 1. Load Context

Read these if they exist (skip silently if missing):
- `.claude/prds/$FEATURE_NAME.md` — the PRD to validate
- `.claude/context/tech-context.md` — for constraint validation
- `.claude/context/product-context.md` — for persona validation
- `rules/prd-quality.md` — quality standards reference

### 2. Determine Scale

Read `scale` from PRD frontmatter or `_Metadata`. If missing, infer from requirement count and content depth. Use scale to select correct section requirements from `rules/prd-quality.md`.

### 3. Validate — Three Dimensions

Reference thresholds and section requirements from `rules/prd-quality.md`.

**Dimension 1: Completeness** — Are all required parts present?
- All required sections present and non-empty (per scale)
- Frontmatter complete (name, status, priority, scale, created)
- Requirement IDs sequential and unique (FR-1, FR-2..., NTH-1..., NFR-1...)
- Every FR/NTH has ≥1 scenario (GIVEN/WHEN/THEN)
- Every User Story maps to a persona (MEDIUM/LARGE)
- No orphan personas (persona defined but never referenced)

**Dimension 2: Correctness** — Is the content internally consistent?
- Executive Summary answers: what, who, why, why now
- Problem Statement is from USER perspective, not system perspective
- Success Criteria all have measurable thresholds + measurement method
- Risks have severity + likelihood + mitigation
- MUST requirements align with Success Criteria (no gap)
- Risks align with Assumptions (contradictions?)
- Scale matches actual content depth

**Dimension 3: Coherence** — Is it ready for downstream consumption?
- Requirements specific enough for prd-parse to create tasks
- Scenarios specific enough to write automated tests from
- No ambiguous terms without definition ("fast", "easy", "scalable")
- Dependencies have owner + status
- No contradictions between sections (e.g., Out of Scope item appears in Requirements)

### 4. Generate Report

Save to `.claude/prds/.validation-$FEATURE_NAME.md`:

```markdown
---
prd: $FEATURE_NAME
date: [Run: date -u +"%Y-%m-%dT%H:%M:%SZ"]
status: [passed/warning/failed]
score: X/Y checks passed
---

# Validation Report: $FEATURE_NAME

## Summary
**Status:** PASSED / WARNING / FAILED
**Score:** X/Y (completeness: A/B, correctness: C/D, coherence: E/F)
**Scale:** [detected scale]

## Critical Issues (must fix before prd-parse)
- [ ] **[Dimension]:** [Issue] — Section: [section] — Fix: [suggestion]

## Warnings (should fix)
- [ ] **[Dimension]:** [Issue] — Section: [section] — Fix: [suggestion]

## Passed Checks
- [x] [Check name]

## Recommendations
[Actionable improvements beyond pass/fail — style, clarity, depth]
```

### 5. Update PRD Metadata

If PRD has `_Metadata` section, update:
- `validation_status`: passed/warning/failed
- `last_validated`: current datetime

### 6. Output

```
📋 Validation: $FEATURE_NAME — [STATUS]
  Score: X/Y (completeness: A/B, correctness: C/D, coherence: E/F)
  Critical: N issues | Warnings: M issues
  Report: .claude/prds/.validation-$FEATURE_NAME.md

📋 Next actions:
  → Fix issues:     /pm:prd-edit $FEATURE_NAME
  → Create epic:    /pm:prd-parse $FEATURE_NAME   (if PASSED/WARNING)
  → Re-validate:    /pm:prd-validate $FEATURE_NAME (after fixes)
```
