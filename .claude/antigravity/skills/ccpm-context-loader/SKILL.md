---
name: ccpm-context-loader
description: Use when starting a task, beginning work, resuming a session, or continuing working on something. NOT for: ending sessions, switching IDE, completing or finishing tasks.
---

# CCPM Context Loader

Load context from `.claude/context/` before starting any implementation work.

## Steps

1. Run `antigravity/skills/ccpm-context-loader/scripts/load-context.sh` to read handoff and epic context
2. Present summary to user: "I understand that..."
   - State what was completed in the last session
   - State what is currently in progress
   - State any warnings or blockers from the previous handoff
3. Review epic context from `.claude/context/epics/{name}.md` if the file exists
4. Review `.claude/context/verify/state.json` for current verification state (pass/fail, iterations)
5. Wait for user confirmation before starting any implementation

## Anti-bypass

If you find yourself skipping context loading and jumping straight to writing code, STOP. Go back to step 1 and load the context. The handoff notes exist for a reason — they prevent repeated mistakes and preserve decisions across sessions.

## Output Format

After loading context, present:

```
I understand that:
- [Key point from handoff]
- [Key point from handoff]
- [Current verify state if relevant]

Epic context: [epic name, progress if available]

Ready to proceed with: [task description]

Shall I begin? (yes/no)
```
