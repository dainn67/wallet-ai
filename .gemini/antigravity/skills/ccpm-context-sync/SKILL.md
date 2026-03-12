---
name: ccpm-context-sync
description: Use when switching IDE, syncing context, coming from Gemini CLI, switching to Antigravity, or switching to Gemini CLI. NOT for: general task start, writing handoff notes, or running verification.
---

# CCPM Context Sync

Detect and handle an IDE switch — load transition context when moving between Gemini CLI and Antigravity.

## Steps

1. Run `antigravity/skills/ccpm-context-sync/scripts/sync-context.sh` to detect the previous IDE and transition state
2. If `last_ide` differs from "antigravity" (or is null), output a transition summary:
   - Announce: "Switching from [previous IDE] to Antigravity"
   - Show `last_action`, `active_epic`, and `pending_handoff` from the sync file
   - Show how long ago the last session ended
3. Load `.gemini/context/handoffs/latest.md` and present the transition context
4. Confirm the active state to the user before proceeding with any work

## When This Applies

- You are in Antigravity but the last session was in Gemini CLI (or another IDE)
- The user explicitly says "I was just in Gemini CLI" or "switching IDEs"
- The `active-ide.json` file shows a different `last_ide`

## Output Format

```
🔄 IDE Switch detected: gemini-cli → antigravity

Last session: [timestamp] ([X minutes/hours ago])
Active epic: [epic name or "none"]
Last action: [description or "unknown"]
Pending handoff: [yes/no]

[Handoff content summary]

Context loaded. Ready to continue.
```
