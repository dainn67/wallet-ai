#!/usr/bin/env bash
# save-debug-journal.sh — Snapshot active debug journals to archive before compact
#
# Copies all active journals matching issue-*-debug.md to sessions/archive/
# with a timestamp suffix. Idempotent: each run creates a new timestamped copy.
#
# Usage:
#   bash scripts/save-debug-journal.sh [ccpm_root]
#
# Exit codes:
#   0 = always (non-blocking — failures are silenced)

set -uo pipefail

_CCPM_ROOT="${_CCPM_ROOT:-${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
SESSIONS_DIR="$_CCPM_ROOT/.claude/context/sessions"
ARCHIVE_DIR="$SESSIONS_DIR/archive"

# Find active journals
journals=$(find "$SESSIONS_DIR" -maxdepth 1 -name "issue-*-debug.md" -type f 2>/dev/null)

# No-op if none found
if [ -z "$journals" ]; then
  exit 0
fi

mkdir -p "$ARCHIVE_DIR" 2>/dev/null || true

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
count=0

while IFS= read -r file; do
  base=$(basename "$file")
  cp "$file" "$ARCHIVE_DIR/${base%.md}-${TIMESTAMP}.md" 2>/dev/null && count=$((count + 1))
done <<< "$journals"

if [ "$count" -gt 0 ]; then
  echo "📸 Snapshot: ${count} debug journal(s)"
fi

exit 0
