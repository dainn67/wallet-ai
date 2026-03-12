---
name: ccpm-handoff
description: Use when ending a session, switching tasks, pausing work, stopping for now, or wrapping up. NOT for: starting work, beginning a new task, resuming a session, or switching IDE specifically.
---

# CCPM Handoff

Write handoff notes to `.gemini/context/handoffs/latest.md` before ending the session.

## Steps

1. Run `antigravity/skills/ccpm-handoff/scripts/write-handoff.sh` to get the template and set up the handoff file
2. Use the template format from `context/handoffs/TEMPLATE.md` to write the handoff content
3. Fill in all sections based on the current conversation context:
   - **Completed**: what was done this session (with file paths)
   - **Decisions Made**: choices made and why, what was rejected
   - **Design vs Implementation**: how actual implementation compared to design
   - **Interfaces Exposed/Modified**: public APIs, function signatures, data schemas
   - **State of Tests**: totals, passing/failing, new tests added
   - **Warnings for Next Task**: gotchas, ordering requirements, fragile areas
   - **Files Changed**: list of all modified/created/deleted files
4. The script also updates `sync/active-ide.json` with `last_ide: "antigravity"`

## Anti-bypass

If you find yourself skipping the handoff and just saying "done" or "session complete", STOP. Write the handoff now. The next session (whether in this IDE or another) depends on these notes to avoid repeating mistakes and rebuilding context from scratch.

## Output Format

Confirm when complete:

```
Handoff written to .gemini/context/handoffs/latest.md

Summary:
- Completed: [count] items
- Files changed: [count]
- Warnings: [count]

Active IDE updated: antigravity
```
