#!/usr/bin/env bash
# Bootstrap script to ingest existing CCPM context files into Memory Agent.
# Usage: bash scripts/pm/memory-bootstrap.sh [ccpm_root]
# Re-runnable: Memory Agent handles deduplication server-side via file_path + file_mtime.

set -uo pipefail

CCPM_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"
PROJECT_ROOT="$(cd "$CCPM_ROOT/.." && pwd)"

# Source helpers
source "$CCPM_ROOT/scripts/pm/lifecycle-helpers.sh" 2>/dev/null || {
  echo "❌ lifecycle-helpers.sh not found at $CCPM_ROOT/scripts/pm/"
  exit 1
}

# Check health first
if ! bash "$CCPM_ROOT/scripts/pm/memory-health.sh" > /dev/null 2>&1; then
  echo "❌ Memory Agent not running. Start: \`ccpm-memory start\`"
  exit 1
fi

# Read host/port from config
HOST=$(_json_get "$CCPM_ROOT/config/lifecycle.json" '.memory_agent.host' 2>/dev/null || echo "")
PORT=$(_json_get "$CCPM_ROOT/config/lifecycle.json" '.memory_agent.port' 2>/dev/null || echo "")
[ -z "$HOST" ] || [ "$HOST" = "null" ] && HOST="localhost"
[ -z "$PORT" ] || [ "$PORT" = "null" ] && PORT="8888"

# Collect files to ingest
FILES=()
for f in "$CCPM_ROOT"/context/*.md; do [ -f "$f" ] && FILES+=("$f"); done
for f in "$CCPM_ROOT"/prds/*.md; do [ -f "$f" ] && FILES+=("$f"); done
for f in "$CCPM_ROOT"/epics/*/epic.md; do [ -f "$f" ] && FILES+=("$f"); done

TOTAL=${#FILES[@]}
if [ "$TOTAL" -eq 0 ]; then
  echo "No files found to ingest"
  exit 0
fi

# Get file mtime: macOS stat -f %m, Linux stat -c %Y
get_mtime() {
  if stat -f %m "$1" 2>/dev/null; then return; fi
  stat -c %Y "$1" 2>/dev/null || echo "0"
}

# Ingest each file
SUCCESS=0
FAILED=0
for i in "${!FILES[@]}"; do
  f="${FILES[$i]}"
  n=$((i + 1))
  [ "$TOTAL" -gt 5 ] && printf "Ingesting... %d/%d\r" "$n" "$TOTAL"

  CONTENT=$(cat "$f" 2>/dev/null || echo "")
  [ -z "$CONTENT" ] && continue

  REL_PATH="${f#"$CCPM_ROOT"/}"
  MTIME=$(get_mtime "$f")

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 \
    -X POST "http://${HOST}:${PORT}/ingest" \
    -H "Content-Type: application/json" \
    -H "X-Project-Root: $PROJECT_ROOT" \
    -d "$(jq -n --arg text "$CONTENT" --arg source "bootstrap-${REL_PATH}" \
            --arg fp "$REL_PATH" --arg mt "$MTIME" \
            '{text: $text, source: $source, file_path: $fp, file_mtime: $mt}')" \
    2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "202" ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

[ "$TOTAL" -gt 5 ] && echo ""  # Newline after progress indicator

echo "✅ Bootstrap complete: Ingested ${SUCCESS}/${TOTAL} files into Memory Agent"
[ "$FAILED" -gt 0 ] && echo "⚠️  Failed: ${FAILED} files (Memory Agent may have been busy)"
