---
name: ccpm-pre-implementation
description: Use when implement, code, build feature, write code, start coding, refactor. NOT for: done, complete, finish, close, verify, epic verify, check quality.
---

# CCPM Pre-Implementation Gate

Enforce design and test gates before any implementation work begins.

## Steps

**SEQUENTIAL — do not skip any step.**

### Step 1 — Design Gate

Run `antigravity/skills/ccpm-pre-implementation/scripts/check-design.sh` to verify the design file exists.

- Design file must be at: `.claude/epics/{epic}/designs/task-{N}-design.md`
- If the script outputs "❌ Design file missing": **STOP. Guide the user to create the design file first.**
- Required template sections: `## Problem`, `## Approach`, `## Files to Change`, `## Rejected Alternatives`
- Do NOT proceed to Step 2 until design file exists.

### Step 2 — Test Gate

Run `antigravity/skills/ccpm-pre-implementation/scripts/check-tests.sh` to verify test stubs exist for FEATURE tasks.

- If the script outputs "❌ No test files found": **STOP. Guide the user to write test stubs first.**
- Test stubs must cover the acceptance criteria from the design file.
- Do NOT proceed to Step 3 until tests exist (for FEATURE tasks).

### Step 3 — Approve Implementation

Only after both gates pass:
- Confirm design file is present
- Confirm test stubs are present (for FEATURE tasks)
- Proceed with implementation

## Anti-bypass

If you find yourself skipping this, STOP. This is the No Vibe Coding gate. Design-first and test-first exist because code written without a plan is code that gets rewritten. Both gates must pass before any production code is written.

## Output Format

After running both checks, present:

```
Pre-implementation check:
- Design gate: ✅ / ❌ {path or error}
- Test gate:   ✅ / ❌ {count or error}

[If both pass]  → Ready to implement. Proceeding...
[If any fails]  → BLOCKED. {What is missing and how to fix it.}
```
