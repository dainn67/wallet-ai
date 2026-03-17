#!/usr/bin/env bash
# Memory Agent health check with 30s temp-file cache.
# Usage: bash scripts/pm/memory-health.sh [host] [port]
# Exit 0 = available, Exit 1 = unavailable
# Output: JSON status on success, "memory-agent-unavailable" on failure

set -uo pipefail

# Detect CCPM root
_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"
_CONFIG_FILE="$_CCPM_ROOT/config/lifecycle.json"
_HELPERS="$_CCPM_ROOT/scripts/pm/lifecycle-helpers.sh"

# Source helpers for _json_get if available
_json_get_local() {
  local file="$1" query="$2"
  if command -v jq &>/dev/null; then
    jq -r "$query" "$file" 2>/dev/null
  else
    echo ""
  fi
}

# Load _json_get from helpers if available
if [ -f "$_HELPERS" ]; then
  # shellcheck source=scripts/pm/lifecycle-helpers.sh
  source "$_HELPERS" 2>/dev/null || true
fi
# Fallback if _json_get not defined after source
if ! declare -f _json_get &>/dev/null 2>&1; then
  _json_get() { _json_get_local "$@"; }
fi

# Check jq requirement
if ! command -v jq &>/dev/null; then
  echo "jq required" >&2
  exit 1
fi

# Determine host and port: config > args > defaults
HOST_ARG="${1:-}"
PORT_ARG="${2:-}"

if [ -f "$_CONFIG_FILE" ]; then
  CONFIG_HOST=$(_json_get "$_CONFIG_FILE" '.memory_agent.host' 2>/dev/null || echo "")
  CONFIG_PORT=$(_json_get "$_CONFIG_FILE" '.memory_agent.port' 2>/dev/null || echo "")
else
  CONFIG_HOST=""
  CONFIG_PORT=""
fi

HOST="${CONFIG_HOST:-${HOST_ARG:-localhost}}"
PORT="${CONFIG_PORT:-${PORT_ARG:-8888}}"

# Normalize null/empty values
[ "$HOST" = "null" ] || [ -z "$HOST" ] && HOST="localhost"
[ "$PORT" = "null" ] || [ -z "$PORT" ] && PORT="8888"

# Generate cache key from project root path (macOS md5 / Linux md5sum)
if command -v md5 &>/dev/null; then
  CACHE_KEY=$(echo "$PWD" | md5 | cut -c1-8)
elif command -v md5sum &>/dev/null; then
  CACHE_KEY=$(echo "$PWD" | md5sum | cut -c1-8)
else
  CACHE_KEY="default0"
fi

CACHE_FILE="/tmp/ccpm-memory-health-${CACHE_KEY}"

# Check cache: if file exists AND modified within last 30s
if [ -f "$CACHE_FILE" ]; then
  if find "$CACHE_FILE" -mmin -0.5 -print 2>/dev/null | grep -q .; then
    # Cache hit — read cached result
    CACHED=$(cat "$CACHE_FILE")
    EXIT_CODE=$(echo "$CACHED" | head -1)
    OUTPUT=$(echo "$CACHED" | tail -n +2)
    echo "$OUTPUT"
    exit "$EXIT_CODE"
  fi
fi

# Cache miss or expired — perform fresh health check
RESPONSE=$(curl -s --max-time 2 "http://${HOST}:${PORT}/status" 2>/dev/null || true)

if [ -n "$RESPONSE" ] && echo "$RESPONSE" | jq . &>/dev/null; then
  # Valid JSON response — agent is available
  printf '%s\n%s' "0" "$RESPONSE" > "$CACHE_FILE"
  echo "$RESPONSE"
  exit 0
else
  # Not available
  printf '%s\n%s' "1" "memory-agent-unavailable" > "$CACHE_FILE"
  echo "memory-agent-unavailable"
  exit 1
fi
