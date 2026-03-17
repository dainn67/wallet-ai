---
name: pm-handoff-write
description: Handoff Write
# tier: medium
---

# Handoff Write

Write a structured handoff note for the current task.

## Usage
```
/pm:handoff-write
```

## Instructions

### 1. Read Template

Read `.claude/context/handoffs/TEMPLATE.md` for the required structure.

### 2. Gather Context

Before writing, review:
- Recent git commits: `git log --oneline -10`
- Changed files: `git diff --name-only HEAD~5 2>/dev/null || git diff --name-only`
- Current verify state: `.claude/context/verify/state.json` (if exists)

### 3. Write Handoff Note

Create `.claude/context/handoffs/latest.md` with all required sections from the template:

- **## Completed** — What was accomplished in this task
- **## Decisions Made** — Key technical decisions and rationale
- **## Interfaces Exposed/Modified** — APIs, types, exports that changed
- **## State of Tests** — What's tested, what's not, any known failures
- **## Warnings for Next Task** — Gotchas, incomplete work, things to watch out for
- **## Files Changed** — List of all files created or modified

Fill each section with substantive content based on the actual work done. Do NOT leave sections empty or with placeholder text.

### 4. Validate

Check that:
- All required sections exist (## Completed, ## Decisions Made, ## State of Tests, ## Files Changed)
- No section is empty (at least one bullet point each)
- File is saved

### 5. Confirm

```
✅ Handoff note written: .claude/context/handoffs/latest.md
  Sections: {count} filled

Next: /pm:issue-complete <number> or /pm:context-reset
```
