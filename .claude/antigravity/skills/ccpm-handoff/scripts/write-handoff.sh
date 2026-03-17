#!/usr/bin/env bash
# ccpm-handoff: write-handoff.sh
#
# Prepares the handoff file and updates active-ide.json.
# Outputs the handoff template with current date for Claude to fill in.
# Always exits 0 — never crashes.

set -uo pipefail

CONTEXT_DIR=".claude/context"
HANDOFFS_DIR="$CONTEXT_DIR/handoffs"
HANDOFF_FILE="$HANDOFFS_DIR/latest.md"
TEMPLATE_FILE="$HANDOFFS_DIR/TEMPLATE.md"
SYNC_DIR="$CONTEXT_DIR/sync"
ACTIVE_IDE_FILE="$SYNC_DIR/active-ide.json"

CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CCPM HANDOFF WRITER"
echo "═══════════════════════════════════════════════════════"
echo ""

# --- Ensure directories exist ---

mkdir -p "$HANDOFFS_DIR" 2>/dev/null || true
mkdir -p "$SYNC_DIR" 2>/dev/null || true

# --- Archive previous handoff if exists ---

if [ -f "$HANDOFF_FILE" ]; then
  ARCHIVE_DIR="$HANDOFFS_DIR/.archive"
  mkdir -p "$ARCHIVE_DIR" 2>/dev/null || true
  archive_name="handoff-$CURRENT_DATE.md"
  cp "$HANDOFF_FILE" "$ARCHIVE_DIR/$archive_name" 2>/dev/null && \
    echo "📦 Previous handoff archived to $ARCHIVE_DIR/$archive_name" || \
    echo "⚠️  Could not archive previous handoff (continuing anyway)"
fi

# --- Output template for Claude to fill in ---

echo "## Handoff Template"
echo ""
echo "Write the following content to: $HANDOFF_FILE"
echo "Timestamp: $CURRENT_DATE"
echo ""
echo "---BEGIN TEMPLATE---"
echo ""

if [ -f "$TEMPLATE_FILE" ]; then
  cat "$TEMPLATE_FILE" 2>/dev/null || echo "⚠️  Could not read template file."
else
  # Fallback template if TEMPLATE.md is missing
  cat <<'FALLBACK'
# Handoff: Task #{current} → Task #{next}

## Completed
- [Bullet list of what was done, with file paths]

## Decisions Made
- [Decision]: [Choice] because [Reason]. Rejected: [Alternatives].

## Design vs Implementation
- [Decision X]: Implemented as designed / Changed because [reason]

## Interfaces Exposed/Modified
```
[Code blocks showing public APIs, function signatures, data schemas]
```

## State of Tests
- Total: X | Passing: Y | Failing: Z
- Coverage: X% (if available)
- New tests added: [list]

## Warnings for Next Task
- [Specific gotchas, ordering requirements, known fragile areas]

## Files Changed
- [path] (new/modified/deleted) — [one-line description]
FALLBACK
  echo ""
  echo "⚠️  Template file not found at $TEMPLATE_FILE — using built-in fallback."
fi

echo ""
echo "---END TEMPLATE---"
echo ""
echo "Fill in the template above based on the current session context, then write"
echo "the completed content to: $HANDOFF_FILE"
echo ""

# --- Update active-ide.json ---

echo "## Updating active-ide.json"
echo ""

if [ -f "$ACTIVE_IDE_FILE" ] && command -v jq >/dev/null 2>&1; then
  # Use jq to update fields
  updated=$(jq \
    --arg ide "antigravity" \
    --arg ts "$CURRENT_DATE" \
    '.last_ide = $ide | .last_session_end = $ts | .pending_handoff = true' \
    "$ACTIVE_IDE_FILE" 2>/dev/null) && \
    echo "$updated" > "$ACTIVE_IDE_FILE" && \
    echo "✅ Updated $ACTIVE_IDE_FILE (jq)" || \
    echo "⚠️  jq update failed for $ACTIVE_IDE_FILE"
elif [ -f "$ACTIVE_IDE_FILE" ]; then
  # Fallback: sed replacement for last_ide field
  sed -i.bak \
    "s|\"last_ide\":.*|\"last_ide\": \"antigravity\",|" \
    "$ACTIVE_IDE_FILE" 2>/dev/null && \
    echo "✅ Updated last_ide in $ACTIVE_IDE_FILE (sed)" || \
    echo "⚠️  sed update failed for $ACTIVE_IDE_FILE"
  rm -f "${ACTIVE_IDE_FILE}.bak" 2>/dev/null || true
else
  # Create new file from schema defaults
  cat > "$ACTIVE_IDE_FILE" <<EOF
{
  "last_ide": "antigravity",
  "last_session_end": "$CURRENT_DATE",
  "last_action": null,
  "pending_handoff": true,
  "open_tasks": [],
  "active_epic": null,
  "verify_state": null
}
EOF
  echo "✅ Created $ACTIVE_IDE_FILE"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Fill in the template above and write it to:"
echo "  $HANDOFF_FILE"
echo "═══════════════════════════════════════════════════════"
echo ""

exit 0
