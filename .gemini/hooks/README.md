# Gemini Hooks Configuration

All hooks use the Gemini CLI Hooks API (PascalCase events, JSON stdin/stdout).

## Configuration

Copy `settings.json.example` to `.gemini/settings.local.json` and merge the hooks section:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "\"$GEMINI_PROJECT_DIR\"/hooks/bash-worktree-fix.sh", "timeout": 5 },
          { "type": "command", "command": "\"$GEMINI_PROJECT_DIR\"/hooks/pre-tool-use.sh", "timeout": 10 }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "\"$GEMINI_PROJECT_DIR\"/hooks/stop-verify.sh", "timeout": 120 }
        ]
      }
    ]
  }
}
```

---

## Hook: Bash Worktree Fix (`PreToolUse`)

**File**: `hooks/bash-worktree-fix.sh`

Automatically injects `cd <worktree_root> &&` prefix when working in git worktrees.

- **Input**: JSON stdin with `tool_input.command`
- **Output**: JSON `hookSpecificOutput.updatedInput.command` (when modified) or exit 0 silently (unchanged)
- **Handles**: background processes, pipes, commands already starting with `cd`, builtins

### Debug

```bash
export GEMINI_HOOK_DEBUG=true
```

---

## Hook: Pre-Tool-Use Guard (`PreToolUse`)

**File**: `hooks/pre-tool-use.sh`

Guards against premature task completion when a CCPM task is active:

1. **Blocks `gh issue close`** unless last verification result is `VERIFY_PASS`
2. **Warns on `git commit`** if handoff note is stale (>10 min old)

- **Input**: JSON stdin with `tool_name` and `tool_input.command`
- **Output**: Exit 0 (allow) or exit 2 + stderr message (block)
- **Performance**: Fast-path when no active task in `.gemini/context/verify/state.json`

---

## Hook: Stop Verify (`Stop`)

**File**: `hooks/stop-verify.sh`

Ralph Loop verification enforcer. Triggered when Gemini attempts to end a session:

1. No active task → allow exit silently
2. `verify_mode=SKIP` → allow with notice
3. Max iterations reached → create `BLOCKED.md` + allow
4. Run verification profile → PASS → allow
5. FAIL + RELAXED → warn + allow
6. FAIL + STRICT → **block exit** (Gemini re-enters fix loop)

- **Input**: JSON stdin (drained, not used — reads state file directly)
- **Output**: JSON `{"decision":"block","reason":"..."}` when blocking, or exit 0 (allow)
- **Exit codes**: 0 = allow, 2 = block

---

## Hook: Pre-Task (`manual`)

**File**: `hooks/pre-task.sh`

Called by `/pm:issue-start` — NOT registered as an automatic hook.

- Loads previous handoff context
- Rotates excess handoff notes (keeps max 10)
- Outputs Context Loading Protocol instructions

---

## Hook: Post-Task (`manual`)

**File**: `hooks/post-task.sh`

Called by `/pm:issue-complete` — NOT registered as an automatic hook.

- Validates handoff note exists, is fresh, and has required sections
- Auto-commits context changes
- Checks for missing architecture decisions (warning only)
