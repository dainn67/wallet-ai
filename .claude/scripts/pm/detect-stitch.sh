#!/usr/bin/env bash
# Detect if Stitch MCP server is configured.
# Exit 0 = available, Exit 1 = not available
# Stdout: "stitch-mcp:available" or "stitch-mcp:not-available"

set -euo pipefail

# Settings files to check, in priority order
SETTINGS_FILES=(
  ".mcp.json"
  ".claude/settings.local.json"
  ".claude/settings.json"
  "settings.local.json"
  "settings.json"
)

# Parse mcpServers keys and check for "stitch" (case-insensitive)
_check_settings() {
  local file="$1"
  [ -f "$file" ] || return 1

  local keys=""
  if command -v jq &>/dev/null; then
    keys=$(jq -r '.mcpServers // {} | keys[]' "$file" 2>/dev/null || echo "")
  elif command -v python3 &>/dev/null; then
    keys=$(python3 -c "
import json, sys
try:
    with open('$file') as f:
        data = json.load(f)
    for k in data.get('mcpServers', {}):
        print(k)
except Exception:
    pass
" 2>/dev/null || echo "")
  else
    # No JSON parser available — cannot determine
    return 1
  fi

  if [ -n "$keys" ]; then
    if echo "$keys" | grep -qi "stitch"; then
      return 0
    fi
  fi
  return 1
}

for settings_file in "${SETTINGS_FILES[@]}"; do
  if _check_settings "$settings_file"; then
    echo "stitch-mcp:available"
    exit 0
  fi
done

echo "stitch-mcp:not-available"
exit 1
