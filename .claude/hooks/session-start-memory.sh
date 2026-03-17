#!/usr/bin/env bash
# SessionStart hook: auto-start memory agent daemon if enabled and not running.
# Fast path: PID check (~1ms). Only launches daemon if not running + setup done.

set -uo pipefail

AGENT_DIR="$HOME/.config/ccpm/memory-agent"
PID_FILE="$AGENT_DIR/.pid"
VENV_DIR="$AGENT_DIR/.venv"
LOG_FILE="$AGENT_DIR/.log"

# 1. Already running? → exit fast
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
  exit 0
fi

# 2. Check if memory_agent is enabled in config
CONFIG=""
for cfg in "${CLAUDE_PROJECT_DIR:-.}/.claude/config/lifecycle.json" \
           "${CLAUDE_PROJECT_DIR:-.}/config/lifecycle.json"; do
  [[ -f "$cfg" ]] && CONFIG="$cfg" && break
done
[[ -z "$CONFIG" ]] && exit 0

# Parse enabled flag (jq fast path, python3 fallback)
if command -v jq &>/dev/null; then
  jq -e '.memory_agent.enabled' "$CONFIG" &>/dev/null || exit 0
else
  python3 -c "import json,sys;sys.exit(0 if json.load(open(sys.argv[1])).get('memory_agent',{}).get('enabled') else 1)" "$CONFIG" 2>/dev/null || exit 0
fi

# 3. Setup done? (venv + agent.py exist)
[[ -f "$VENV_DIR/bin/python" && -f "$AGENT_DIR/agent.py" ]] || exit 0

# 4. Clean stale PID file
[[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"

# 5. Start daemon in background (no port wait — keeps hook fast)
CCPM_GLOBAL_DAEMON=1 nohup "$VENV_DIR/bin/python" "$AGENT_DIR/agent.py" --global \
  >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

exit 0
