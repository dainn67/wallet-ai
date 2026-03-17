#!/usr/bin/env bash
# ccpm-context-sync: sync-context.sh
#
# Detects IDE switches by reading sync/active-ide.json.
# Outputs transition summary if coming from a different IDE.
# Updates active-ide.json to reflect current IDE (antigravity).
# Always exits 0 — never crashes.

set -uo pipefail

CONTEXT_DIR=".claude/context"
SYNC_DIR="$CONTEXT_DIR/sync"
ACTIVE_IDE_FILE="$SYNC_DIR/active-ide.json"
HANDOFF_FILE="$CONTEXT_DIR/handoffs/latest.md"
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CCPM CONTEXT SYNC"
echo "═══════════════════════════════════════════════════════"
echo ""

mkdir -p "$SYNC_DIR" 2>/dev/null || true

# --- Read active-ide.json ---

last_ide="null"
last_session_end="null"
last_action="null"
active_epic="null"
pending_handoff="false"

if [ -f "$ACTIVE_IDE_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    last_ide=$(jq -r '.last_ide // "null"' "$ACTIVE_IDE_FILE" 2>/dev/null || echo "null")
    last_session_end=$(jq -r '.last_session_end // "null"' "$ACTIVE_IDE_FILE" 2>/dev/null || echo "null")
    last_action=$(jq -r '.last_action // "null"' "$ACTIVE_IDE_FILE" 2>/dev/null || echo "null")
    active_epic=$(jq -r '.active_epic // "null"' "$ACTIVE_IDE_FILE" 2>/dev/null || echo "null")
    pending_handoff=$(jq -r '.pending_handoff // false' "$ACTIVE_IDE_FILE" 2>/dev/null || echo "false")
  else
    # Fallback: grep for last_ide value
    last_ide=$(grep '"last_ide"' "$ACTIVE_IDE_FILE" 2>/dev/null | sed 's/.*"last_ide":[[:space:]]*//' | sed 's/[",]//g' | tr -d ' ' || echo "null")
  fi
else
  echo "⚠️  No active-ide.json found at $ACTIVE_IDE_FILE — assuming fresh start."
fi

# --- Detect IDE switch ---

if [ "$last_ide" != "antigravity" ] && [ "$last_ide" != "null" ]; then
  echo "🔄 IDE Switch detected: $last_ide → antigravity"
  echo ""
elif [ "$last_ide" = "null" ]; then
  echo "ℹ️  No previous IDE recorded — first session or fresh install."
  echo ""
else
  echo "✅ Already in antigravity — no IDE switch detected."
  echo ""
fi

# --- Show transition summary ---

echo "## Session Summary"
echo ""
echo "  Last IDE:          $last_ide"
echo "  Last session end:  $last_session_end"
echo "  Active epic:       $active_epic"
echo "  Last action:       $last_action"
echo "  Pending handoff:   $pending_handoff"

# Calculate time since last session if possible
if [ "$last_session_end" != "null" ] && command -v python3 >/dev/null 2>&1; then
  elapsed=$(python3 -c "
from datetime import datetime, timezone
try:
    last = datetime.fromisoformat('${last_session_end}'.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    delta = now - last
    hours = int(delta.total_seconds() // 3600)
    minutes = int((delta.total_seconds() % 3600) // 60)
    if hours > 0:
        print(f'{hours}h {minutes}m ago')
    else:
        print(f'{minutes}m ago')
except Exception:
    print('unknown time ago')
" 2>/dev/null || echo "")
  if [ -n "$elapsed" ]; then
    echo "  Time elapsed:      $elapsed"
  fi
fi

echo ""

# --- Show handoff preview ---

echo "## Previous Handoff"
echo ""

if [ -f "$HANDOFF_FILE" ]; then
  echo "Found: $HANDOFF_FILE"
  echo ""
  # Show first 20 lines as preview
  head -20 "$HANDOFF_FILE" 2>/dev/null || cat "$HANDOFF_FILE" 2>/dev/null || echo "⚠️  Could not read handoff file."
  echo ""
  # Count total lines
  total_lines=$(wc -l < "$HANDOFF_FILE" 2>/dev/null | tr -d ' ' || echo "?")
  if [ "$total_lines" -gt 20 ] 2>/dev/null; then
    echo "  ... ($total_lines lines total — run load-context.sh for full handoff)"
  fi
else
  echo "⚠️  No handoff found at $HANDOFF_FILE"
fi

echo ""

# --- Update active-ide.json to reflect current IDE ---

echo "## Updating active-ide.json"
echo ""

if [ -f "$ACTIVE_IDE_FILE" ] && command -v jq >/dev/null 2>&1; then
  updated=$(jq \
    --arg ide "antigravity" \
    --arg ts "$CURRENT_DATE" \
    '.last_ide = $ide | .last_session_end = $ts' \
    "$ACTIVE_IDE_FILE" 2>/dev/null) && \
    echo "$updated" > "$ACTIVE_IDE_FILE" && \
    echo "✅ Updated $ACTIVE_IDE_FILE — last_ide set to antigravity" || \
    echo "⚠️  jq update failed"
elif [ -f "$ACTIVE_IDE_FILE" ]; then
  # Fallback sed
  sed -i.bak "s|\"last_ide\":.*,|\"last_ide\": \"antigravity\",|" "$ACTIVE_IDE_FILE" 2>/dev/null && \
    echo "✅ Updated last_ide in $ACTIVE_IDE_FILE (sed)" || \
    echo "⚠️  sed update failed"
  rm -f "${ACTIVE_IDE_FILE}.bak" 2>/dev/null || true
else
  # Create from defaults
  cat > "$ACTIVE_IDE_FILE" <<EOF
{
  "last_ide": "antigravity",
  "last_session_end": "$CURRENT_DATE",
  "last_action": null,
  "pending_handoff": false,
  "open_tasks": [],
  "active_epic": null,
  "verify_state": null
}
EOF
  echo "✅ Created $ACTIVE_IDE_FILE"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Sync complete. Review summary above before proceeding."
echo "═══════════════════════════════════════════════════════"
echo ""

exit 0
