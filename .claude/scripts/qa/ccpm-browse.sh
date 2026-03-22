#!/bin/bash
# ccpm-browse — Browser automation CLI for CCPM QA agents
# AD-1: Shell + Node.js wrapper. Shell handles arg parsing and install; Node.js handles Playwright.
# Usage: ccpm-browse.sh [-s=SESSION] COMMAND [ARGS...]
# Requires: node, npm (auto-installs Playwright on first run)
set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROWSE_DIR="$SCRIPT_DIR/browse"
VALID_COMMANDS="goto, back, reload, snapshot, screenshot, text, click, fill, select, hover, press, console, network, links, forms"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _json_response <success: true|false> <error: string|null> <data: json|null>
_json_response() {
  local success="$1"
  local error="$2"
  local data="$3"

  if [ "$error" = "null" ]; then
    printf '{"success":%s,"error":null,"data":%s}\n' "$success" "$data"
  else
    local escaped_error
    escaped_error=$(printf '%s' "$error" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
    printf '{"success":%s,"error":"%s","data":%s}\n' "$success" "$escaped_error" "$data"
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

SESSION=""
COMMAND=""
ARGS=()

for arg in "$@"; do
  case "$arg" in
    -s=*)
      SESSION="${arg#-s=}"
      ;;
    --help|-h)
      cat >&2 <<'USAGE'
Usage: ccpm-browse.sh [-s=SESSION] COMMAND [ARGS...]

Options:
  -s=SESSION    Browser session name (default: default)

Commands:
  goto URL            Navigate to URL
  back                Go back in history
  reload              Reload current page
  snapshot            Get DOM snapshot
  screenshot PATH     Save screenshot to PATH
  text SELECTOR       Get text content of element
  click SELECTOR      Click element
  fill SELECTOR VALUE Fill input field
  select SELECTOR VAL Select dropdown option
  hover SELECTOR      Hover over element
  press KEY           Press keyboard key
  console             Get console log
  network             Get network log
  links               Get all page links
  forms               Get all form elements

Sessions are stored at: .claude/qa/sessions/{name}/
USAGE
      exit 0
      ;;
    *)
      if [ -z "$COMMAND" ]; then
        COMMAND="$arg"
      else
        ARGS+=("$arg")
      fi
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

# Check node is available
if ! command -v node &>/dev/null; then
  _json_response false "Node.js required for web QA. Install: https://nodejs.org" null
  exit 1
fi

# Show usage if no command given
if [ -z "$COMMAND" ]; then
  _json_response false "No command provided. Run with --help for usage." null
  exit 1
fi

# Validate command against allowlist
case "$COMMAND" in
  goto|back|reload|snapshot|screenshot|text|click|fill|select|hover|press|console|network|links|forms)
    ;;
  *)
    _json_response false "Unknown command: $COMMAND. Valid: $VALID_COMMANDS" null
    exit 1
    ;;
esac

# Default session name
if [ -z "$SESSION" ]; then
  SESSION="default"
fi

# ---------------------------------------------------------------------------
# Auto-install Playwright on first run (with lock file to handle concurrency)
# ---------------------------------------------------------------------------

if [ ! -d "$BROWSE_DIR/node_modules" ]; then
  LOCK_FILE="$BROWSE_DIR/.install.lock"

  # Acquire lock (atomic mkdir)
  if mkdir "$LOCK_FILE" 2>/dev/null; then
    trap 'rm -rf "$LOCK_FILE"' EXIT

    printf '[ccpm-browse] First run: installing Playwright...\n' >&2

    if ! npm install --prefix "$BROWSE_DIR" --quiet 2>&1 | sed 's/^/[npm] /' >&2; then
      rm -rf "$LOCK_FILE"
      _json_response false "npm install failed in $BROWSE_DIR. Check network/permissions." null
      exit 1
    fi

    printf '[ccpm-browse] Playwright installed.\n' >&2
  else
    # Another process holds the lock — wait up to 60s
    printf '[ccpm-browse] Waiting for concurrent install to finish...\n' >&2
    local_wait=0
    while [ -d "$LOCK_FILE" ] && [ $local_wait -lt 60 ]; do
      sleep 1
      local_wait=$((local_wait + 1))
    done
    if [ -d "$LOCK_FILE" ]; then
      _json_response false "Install lock timeout. Remove $LOCK_FILE and retry." null
      exit 1
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Ensure session directory exists
# ---------------------------------------------------------------------------

# Resolve project root (walk up from SCRIPT_DIR to find .claude/)
PROJECT_ROOT="$SCRIPT_DIR"
while [ "$PROJECT_ROOT" != "/" ] && [ ! -d "$PROJECT_ROOT/.claude" ]; do
  PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

SESSION_DIR="$PROJECT_ROOT/.claude/qa/sessions/$SESSION"
mkdir -p "$SESSION_DIR"

# ---------------------------------------------------------------------------
# Delegate to Node.js module
# ---------------------------------------------------------------------------

NODE_SCRIPT="$BROWSE_DIR/index.js"

if [ ! -f "$NODE_SCRIPT" ]; then
  _json_response false "Node.js module not found: $NODE_SCRIPT" null
  exit 1
fi

raw_output=""
exit_code=0
raw_output=$(node "$NODE_SCRIPT" "$SESSION" "$COMMAND" "${ARGS[@]+"${ARGS[@]}"}" 2>&1) || exit_code=$?

if [ $exit_code -ne 0 ]; then
  # If Node already output valid JSON error, pass it through
  if printf '%s' "$raw_output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    printf '%s\n' "$raw_output"
  else
    # Wrap crash output in JSON error
    escaped=$(printf '%s' "$raw_output" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
    printf '{"success":false,"error":"%s","data":null}\n' "$escaped"
  fi
  exit 1
fi

# Pass through Node.js JSON output
printf '%s\n' "$raw_output"
