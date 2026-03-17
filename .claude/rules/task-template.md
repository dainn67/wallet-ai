# Task Template

Reference template for `epic-decompose` and `epic-oneshot`. Each task file follows this structure.

## Frontmatter

```yaml
---
name: [Descriptive task title]
status: open
created: [datetime]
updated: [datetime]
complexity: [simple|moderate|complex]
recommended_model: [sonnet|opus]
phase: [1/2/3]
priority: [P0/P1/P2]
github: ""
depends_on: []
parallel: true
conflicts_with: []
files:
  - [path/to/file]
prd_requirements:
  - [FR-1, NFR-2 etc — from PRD]
---
```

## Required Sections

### 1. Context
WHY this task exists. 1-2 sentences. Engineer understands purpose without reading epic.

### 2. Description
WHAT needs to be done. High-level approach. Reference architecture decisions from epic.

### 3. Acceptance Criteria
Scenario-linked to PRD requirements. Format:
```markdown
- [ ] **FR-1 / Happy path:** [specific testable condition with threshold]
- [ ] **FR-1 / Edge case:** [specific testable condition]
- [ ] **NFR-1 / Performance:** [measurable threshold + measurement method]
```

### 4. Implementation Steps
HOW to implement at code level. Minimum 2 steps. Each step has:
- Action verb + target file path
- Specific function/logic to implement
- Error handling where applicable

```markdown
### Step 1: [Action + target]
- Create/Modify `path/to/file`
- Add function `name(params)` that:
  - [Logic step 1]
  - [Logic step 2]
  - Returns: [type/shape]
- Error handling: [what to catch, how to respond]

### Step 2: [Action + target]
- ...
```

### 5. Interface Contract
**Only when `depends_on` is non-empty.** Specifies exact input/output between dependent tasks.

```markdown
### Receives from T001:
- File: `path/to/dependency-output`
  - Function/export: `name(params)` → return type
  - Error contract: what happens on failure
  - Guaranteed invariants: what caller can assume

### Produces for T020:
- File: `path/to/output`
  - Function/export: `name` → type
  - Guaranteed: [what dependents can rely on]
```

### 6. Technical Details
- **Approach:** Reference architecture decisions from epic
- **Files to create/modify:** each with what-to-do description
- **Patterns to follow:** Reference existing code: "See `path/to/example`"
- **Edge cases:** Specific cases to handle

### 7. Tests to Write
Separated from verification. Concrete test cases per AC.

```markdown
### Unit Tests
- `test/path/to/test-file`
  - Test: [scenario from AC] → expect [result]
  - Test: [edge case] → expect [error/fallback]

### Integration Tests (if applicable)
- Test: [cross-component scenario] → expect [result]
```

### 8. Verification Checklist
Commands to run to confirm task is done.

```markdown
- [ ] All unit tests pass: `[specific command]`
- [ ] No regression: `[specific command]`
- [ ] Manual check: [specific scenario]
```

### 9. Dependencies
- **Blocked by:** [Task numbers or "None"]
- **Blocks:** [Task numbers or "None"]
- **External:** [APIs, services, libraries, or "None"]

## Optional Sections

### Anchor Code
**Only for `complexity: complex`.** Pseudocode skeleton showing structure. Agent implements full version.

Use when task involves:
- New architectural patterns not in existing codebase
- Complex control flow or state management
- Integration of 3+ components

## Content Sufficiency Checklist

Before saving each task, verify:
- [ ] Self-sufficiency: engineer can implement from task file alone, without reading epic
- [ ] Implementation Steps have >=2 steps with specific file paths and logic
- [ ] Every file in `files:` frontmatter appears in Implementation Steps
- [ ] Tests to Write has >=1 concrete test case per acceptance criterion
- [ ] Complex tasks have Anchor Code section
- [ ] Tasks with dependencies have Interface Contract section
- [ ] Acceptance Criteria reference PRD requirement IDs (FR-N format)
