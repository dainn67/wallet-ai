# PRD & Task Quality Standards

Shared quality standards referenced by prd-new, prd-validate, prd-edit, prd-parse, epic-decompose.

## Requirement ID Format

- Functional MUST: `FR-1`, `FR-2`, ...
- Nice-to-have: `NTH-1`, `NTH-2`, ...
- Non-functional: `NFR-1`, `NFR-2`, ...

IDs are sequential within category. Never reuse deleted IDs.

## Scenario Format

Every FR and NTH MUST have >=1 scenario:

```
Scenario: [Name]
- GIVEN [precondition]
- WHEN [action]
- THEN [expected result]
```

NFRs use measurable thresholds instead of scenarios.

## Scale Definitions

- **SMALL:** Bug fix, config change, single-file enhancement. PRD ~1 page. Epic skips Architecture Decisions (inline note). 1-3 tasks.
- **MEDIUM:** Standard feature. Full PRD + Epic template. 3-8 tasks. (Default)
- **LARGE:** Multi-component, migration, redesign. Full templates + Migration Strategy + Rollback Plan. 5-10 tasks.

## PRD Section Requirements by Scale

| Section | SMALL | MEDIUM | LARGE |
|---------|-------|--------|-------|
| Executive Summary | 1-2 sentences | 3-5 sentences | 3-5 sentences |
| Problem Statement | Required | Required | Required |
| Target Users | Skip (inline note) | 2-4 personas | 2-4 personas |
| User Stories | Skip (AC in Requirements) | Required | Required |
| Requirements (IDs + scenarios) | Required | Required | Required |
| Success Criteria | 1-2 items | Required | Required |
| Risks & Mitigations | 1 entry | 3+ entries | 5+ entries |
| Constraints & Assumptions | Optional | Required | Required |
| Out of Scope | Required | Required | Required |
| Dependencies | If any | Required | Required |
| Migration Strategy | Skip | Skip | Required |
| Rollback Plan | Skip | Skip | Required |

## Epic Section Requirements by Scale

| Section | SMALL | MEDIUM | LARGE |
|---------|-------|--------|-------|
| Overview | Required | Required | Required |
| Architecture Decisions | Skip (inline in Overview) | Required (ADR format) | Required (ADR format) |
| Technical Approach | Required | Required | Required |
| Traceability Matrix | Required | Required | Required |
| Implementation Strategy | Single phase | 3 phases | 3 phases |
| Task Breakdown | 1-3 tasks | 3-8 tasks | 5-10 tasks |
| Risks & Mitigations | 1 entry | 3+ entries | 5+ entries |
| Migration Strategy | Skip | Skip | Required |
| Rollback Plan | Skip | Skip | Required |

## Validation Thresholds

- **PASSED:** 0 critical issues
- **WARNING:** 0 critical, 1+ warnings
- **FAILED:** 1+ critical issues

## Validation Dimensions

1. **Completeness** — All required sections present + non-empty per scale
2. **Correctness** — Content internally consistent, no contradictions
3. **Coherence** — Ready for downstream: specific enough for tasks, tests, implementation

## Task Content Quality

### Acceptance Criteria — Scenario-linked
```
- [ ] **FR-1 / Happy path:** [specific testable condition]
- [ ] **FR-1 / Edge case:** [specific testable condition]
- [ ] **NFR-1 / Performance:** [measurable threshold]
```

### Implementation Steps — Required, >=2 steps
```
### Step 1: [Action + target]
- Create/Modify `path/to/file`
- Add function `name(params)` that: [logic]
- Error handling: [what to catch]
```
- BAD: "Implement the auth middleware"
- GOOD: "Step 1: Create `scripts/detect-model.sh` — Parse frontmatter `model:` field using grep..."

### Interface Contract — Required when depends_on non-empty
```
### Receives from T001:
- File: `path` — Function: `name()` → return type

### Produces for T020:
- File: `path` — Export: `VAR_NAME`
```

### Test Specification — Separated from Verification
```
## Tests to Write
### Unit Tests
- `test/path/file` — Test: [scenario] → expect [result]

## Verification Checklist
- [ ] All tests pass: `[command]`
- [ ] No regressions: `[command]`
```
