#!/usr/bin/env bash
# Lifecycle helper functions for CCPM Task Lifecycle Engine.
# Usage:
#   bash .claude/scripts/pm/lifecycle-helpers.sh <command> [args...]
#
# Commands:
#   detect-task-type <issue_number>   - Classify task type from GitHub labels
#   detect-tech-stack [project_root]  - Detect project tech stack
#   get-verify-mode <task_type>       - Get verification mode for task type
#   get-verify-profile <tech_stack>   - Get verification profile script path
#   read-verify-state                 - Read current verification state
#   write-verify-state <json>         - Write verification state
#   init-verify-state <issue> <epic>  - Initialize state for new task
#   increment-iteration               - Bump iteration count
#   detect-superpowers                - Check if Superpowers plugin is installed
#   read-config-bool <section> <key>  - Read boolean config value
#   get-model-for-command <cmd>       - Get configured model for a command
#
# Or source in another script:
#   source .claude/scripts/pm/lifecycle-helpers.sh
#   detect_task_type 8
#   detect_tech_stack .

if [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
  # Only set -e when running as standalone script, not when sourced
  set -euo pipefail
else
  set -uo pipefail
fi

# Detect CCPM root (where scripts/pm/ lives)
_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"
_STATE_FILE="$_CCPM_ROOT/context/verify/state.json"
_EPIC_STATE_FILE="$_CCPM_ROOT/context/verify/epic-state.json"
_CONFIG_FILE="$_CCPM_ROOT/config/lifecycle.json"
_EPIC_CONFIG_FILE="$_CCPM_ROOT/config/epic-verify.json"
_MODEL_CONFIG_FILE="$_CCPM_ROOT/config/model-tiers.json"

# --- JSON helpers (jq with Python3 fallback) ---

_json_get() {
  local file="$1" query="$2"
  if command -v jq &>/dev/null; then
    jq -r "$query" "$file" 2>/dev/null
  else
    python3 -c "
import json, sys
with open('$file') as f:
    d = json.load(f)
keys = '$query'.strip('.').split('.')
for k in keys:
    if k.startswith('['):
        d = d[int(k.strip('[]'))]
    else:
        d = d.get(k, '')
print(d if isinstance(d, str) else json.dumps(d))
" 2>/dev/null
  fi
}

_json_write() {
  local file="$1" json="$2"
  local tmp="${file}.tmp.$$"
  echo "$json" > "$tmp" && mv "$tmp" "$file"
}

# --- Detection Functions ---

# Classify task type from GitHub issue labels.
# Args: issue_number
# Output: BUG_FIX | FEATURE | REFACTOR | DOCS | CONFIG
detect_task_type() {
  local issue_number="${1:?Usage: detect_task_type <issue_number>}"
  local labels

  # Detect repo for --repo flag (works even without git remote)
  local _repo_flag=""
  local _gh_helpers="$_CCPM_ROOT/scripts/pm/github-helpers.sh"
  if [ -f "$_gh_helpers" ]; then
    local _repo
    _repo=$(bash "$_gh_helpers" get-repo-for-issue "$issue_number" 2>/dev/null || echo "")
    [ -n "$_repo" ] && _repo_flag="--repo $_repo"
  fi

  # Get labels from GitHub
  labels=$(gh issue view "$issue_number" $_repo_flag --json labels -q '[.labels[].name] | join(",")' 2>/dev/null || echo "")
  labels=$(echo "$labels" | tr '[:upper:]' '[:lower:]')

  # Priority-ordered classification (PRD §3.2.2)
  # 1. Bug/fix labels
  if echo "$labels" | grep -qE '(^|,)(bug|fix)(,|$)'; then
    echo "BUG_FIX"
    return 0
  fi

  # 2. Feature/enhancement labels
  if echo "$labels" | grep -qE '(^|,)(feature|enhancement)(,|$)'; then
    echo "FEATURE"
    return 0
  fi

  # 3. Refactor/tech-debt labels
  if echo "$labels" | grep -qE '(^|,)(refactor|tech-debt)(,|$)'; then
    echo "REFACTOR"
    return 0
  fi

  # 4. Docs/documentation labels
  if echo "$labels" | grep -qE '(^|,)(docs|documentation)(,|$)'; then
    echo "DOCS"
    return 0
  fi

  # 5. Config/chore/ci labels
  if echo "$labels" | grep -qE '(^|,)(config|chore|ci)(,|$)'; then
    echo "CONFIG"
    return 0
  fi

  # 6. File pattern fallback — check if only docs files changed
  local body
  body=$(gh issue view "$issue_number" $_repo_flag --json body -q .body 2>/dev/null || echo "")
  if echo "$body" | grep -qiE '(\.md|docs/|README|documentation)' && \
     ! echo "$body" | grep -qiE '\.(py|ts|js|swift|rs|go|java)'; then
    echo "DOCS"
    return 0
  fi

  # 7. Default to FEATURE
  echo "FEATURE"
  return 0
}

# Detect project tech stack from filesystem markers.
# Args: [project_root] (default: .)
# Output: python | node | swift | rust | go | generic
detect_tech_stack() {
  local root="${1:-.}"

  # Priority 1: Custom verify script
  if [ -n "$(find "$_CCPM_ROOT/context/verify/custom" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | head -1 || true)" ]; then
    echo "custom"
    return 0
  fi

  # Priority 2: Tech-specific markers (check most specific first)
  # Swift/iOS
  if [ -f "$root/Package.swift" ] || ls "$root"/*.xcodeproj 1>/dev/null 2>&1; then
    echo "swift"
    return 0
  fi

  # Rust
  if [ -f "$root/Cargo.toml" ]; then
    echo "rust"
    return 0
  fi

  # Go
  if [ -f "$root/go.mod" ]; then
    echo "go"
    return 0
  fi

  # Python
  if [ -f "$root/pyproject.toml" ] || [ -f "$root/setup.py" ] || \
     [ -f "$root/requirements.txt" ] || [ -f "$root/Pipfile" ]; then
    echo "python"
    return 0
  fi

  # Node/TypeScript
  if [ -f "$root/package.json" ]; then
    echo "node"
    return 0
  fi

  # Priority 3: Generic fallback
  echo "generic"
  return 0
}

# Map task type to verification mode.
# Args: task_type
# Output: STRICT | RELAXED | SKIP
get_verify_mode() {
  local task_type="${1:?Usage: get_verify_mode <task_type>}"

  # Read config overrides if available
  if [ -f "$_CONFIG_FILE" ]; then
    local strict_labels relaxed_labels skip_labels
    strict_labels=$(_json_get "$_CONFIG_FILE" '.verification.strict_task_labels' 2>/dev/null || echo "")
    relaxed_labels=$(_json_get "$_CONFIG_FILE" '.verification.relaxed_task_labels' 2>/dev/null || echo "")
    skip_labels=$(_json_get "$_CONFIG_FILE" '.verification.skip_task_labels' 2>/dev/null || echo "")

    local type_lower
    type_lower=$(echo "$task_type" | tr '[:upper:]' '[:lower:]')

    if echo "$skip_labels" | grep -qi "$type_lower"; then
      echo "SKIP"
      return 0
    fi
    if echo "$relaxed_labels" | grep -qi "$type_lower"; then
      echo "RELAXED"
      return 0
    fi
  fi

  # Default mapping
  case "$task_type" in
    BUG_FIX|FEATURE|REFACTOR)
      echo "STRICT"
      ;;
    DOCS|CONFIG)
      echo "RELAXED"
      ;;
    *)
      echo "STRICT"
      ;;
  esac
  return 0
}

# Get path to verification profile script.
# Args: tech_stack
# Output: path to profile script
get_verify_profile() {
  local tech_stack="${1:?Usage: get_verify_profile <tech_stack>}"
  local profiles_dir="$_CCPM_ROOT/context/verify/profiles"
  local custom_dir="$_CCPM_ROOT/context/verify/custom"

  # Priority 1: Custom script
  local custom_script=""
  custom_script=$(find "$custom_dir" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | head -1 || true)
  if [ -n "$custom_script" ] && [ -x "$custom_script" ]; then
    echo "$custom_script"
    return 0
  fi

  # Priority 2: Tech-specific profile
  if [ "$tech_stack" != "custom" ] && [ -f "$profiles_dir/${tech_stack}.sh" ]; then
    echo "$profiles_dir/${tech_stack}.sh"
    return 0
  fi

  # Priority 3: Generic fallback
  echo "$profiles_dir/generic.sh"
  return 0
}

# --- State Management Functions ---

# Read current verification state from state.json.
# Output: JSON to stdout
read_verify_state() {
  if [ ! -f "$_STATE_FILE" ]; then
    echo '{"active_task": null}'
    return 0
  fi
  cat "$_STATE_FILE"
  return 0
}

# Write verification state to state.json.
# Args: json_string
write_verify_state() {
  local json="${1:?Usage: write_verify_state <json_string>}"
  _json_write "$_STATE_FILE" "$json"
  return 0
}

# Initialize verification state for a new task.
# Args: issue_number epic_name
init_verify_state() {
  local issue="${1:?Usage: init_verify_state <issue_number> <epic_name>}"
  local epic="${2:?Usage: init_verify_state <issue_number> <epic_name>}"
  local task_type tech_stack verify_mode verify_profile max_iter
  local started_at

  started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  task_type=$(detect_task_type "$issue" 2>/dev/null || echo "FEATURE")
  tech_stack=$(detect_tech_stack "." 2>/dev/null || echo "generic")
  verify_mode=$(get_verify_mode "$task_type" 2>/dev/null || echo "STRICT")
  verify_profile=$(get_verify_profile "$tech_stack" 2>/dev/null || echo "")

  # Get max iterations from config based on task type
  max_iter=20
  if [ -f "$_CONFIG_FILE" ]; then
    case "$task_type" in
      BUG_FIX)  max_iter=$(_json_get "$_CONFIG_FILE" '.verification.max_iterations_bug_fix' 2>/dev/null || echo "15") ;;
      FEATURE)  max_iter=$(_json_get "$_CONFIG_FILE" '.verification.max_iterations_feature' 2>/dev/null || echo "25") ;;
      REFACTOR) max_iter=$(_json_get "$_CONFIG_FILE" '.verification.max_iterations_refactor' 2>/dev/null || echo "20") ;;
      *)        max_iter=$(_json_get "$_CONFIG_FILE" '.verification.max_iterations' 2>/dev/null || echo "20") ;;
    esac
  fi

  local state
  if command -v jq &>/dev/null; then
    state=$(jq -n \
      --arg issue "$issue" \
      --arg epic "$epic" \
      --arg type "$task_type" \
      --arg mode "$verify_mode" \
      --arg stack "$tech_stack" \
      --arg profile "$verify_profile" \
      --argjson max "$max_iter" \
      --arg started "$started_at" \
      '{
        active_task: {
          issue_number: ($issue | tonumber),
          epic: $epic,
          type: $type,
          verify_mode: $mode,
          tech_stack: $stack,
          verify_profile: $profile,
          max_iterations: $max,
          current_iteration: 0,
          started_at: $started,
          iterations: []
        }
      }')
  else
    state=$(python3 -c "
import json
state = {
    'active_task': {
        'issue_number': int('$issue'),
        'epic': '$epic',
        'type': '$task_type',
        'verify_mode': '$verify_mode',
        'tech_stack': '$tech_stack',
        'verify_profile': '$verify_profile',
        'max_iterations': int('$max_iter'),
        'current_iteration': 0,
        'started_at': '$started_at',
        'iterations': []
    }
}
print(json.dumps(state, indent=2))
")
  fi

  write_verify_state "$state"
  echo "✅ Verify state initialized: type=$task_type mode=$verify_mode stack=$tech_stack max=$max_iter"
  return 0
}

# Increment the current iteration count in verify state.
increment_iteration() {
  local state result failures files_changed timestamp
  state=$(read_verify_state)

  # Check if active task exists
  local has_active
  if command -v jq &>/dev/null; then
    has_active=$(echo "$state" | jq -r '.active_task // empty')
  else
    has_active=$(python3 -c "import json; d=json.loads('$(echo "$state" | tr "'" '"')')
print(d.get('active_task') or '')" 2>/dev/null)
  fi

  if [ -z "$has_active" ] || [ "$has_active" = "null" ]; then
    echo "❌ No active task to increment" >&2
    return 1
  fi

  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  result="${1:-VERIFY_FAIL}"
  failures="${2:-}"
  files_changed="${3:-}"

  if command -v jq &>/dev/null; then
    local new_state
    new_state=$(echo "$state" | jq \
      --arg ts "$timestamp" \
      --arg res "$result" \
      --arg fail "$failures" \
      --arg files "$files_changed" \
      '.active_task.current_iteration += 1 |
       .active_task.iterations += [{
         iteration: .active_task.current_iteration,
         timestamp: $ts,
         result: $res,
         failures: ($fail | split(",")),
         files_changed: ($files | split(","))
       }]')
    write_verify_state "$new_state"
  else
    python3 -c "
import json
state = json.loads('''$(echo "$state")''')
state['active_task']['current_iteration'] += 1
state['active_task']['iterations'].append({
    'iteration': state['active_task']['current_iteration'],
    'timestamp': '$timestamp',
    'result': '$result',
    'failures': [f for f in '$failures'.split(',') if f],
    'files_changed': [f for f in '$files_changed'.split(',') if f]
})
print(json.dumps(state, indent=2))
" > "$_STATE_FILE"
  fi

  local current
  current=$(echo "$(read_verify_state)" | _json_get /dev/stdin '.active_task.current_iteration' 2>/dev/null || echo "?")
  local max
  max=$(echo "$(read_verify_state)" | _json_get /dev/stdin '.active_task.max_iterations' 2>/dev/null || echo "?")
  echo "Iteration: $current/$max (result: $result)"
  return 0
}

# --- Superpowers Detection ---

# Detect if Superpowers plugin is installed.
# Caches result in env var to avoid repeated filesystem checks.
# Returns: 0 = installed, 1 = not installed
detect_superpowers() {
  if [ -n "${_SUPERPOWERS_DETECTED+x}" ]; then
    return "$_SUPERPOWERS_DETECTED"
  fi
  bash "$_CCPM_ROOT/scripts/detect-superpowers.sh" >/dev/null 2>&1
  _SUPERPOWERS_DETECTED=$?
  export _SUPERPOWERS_DETECTED
  return "$_SUPERPOWERS_DETECTED"
}

# Read a boolean value from lifecycle.json config.
# Args: section key [default]
# Returns: 0 = true, 1 = false
read_config_bool() {
  local section="${1:?Usage: read_config_bool <section> <key> [default]}"
  local key="${2:?Usage: read_config_bool <section> <key> [default]}"
  local default="${3:-true}"

  if [ ! -f "$_CONFIG_FILE" ]; then
    [ "$default" = "true" ] && return 0 || return 1
  fi

  local val
  val=$(_json_get "$_CONFIG_FILE" ".${section}.${key}" 2>/dev/null || echo "$default")

  case "$val" in
    true|True|TRUE|1)  return 0 ;;
    false|False|FALSE|0) return 1 ;;
    *) [ "$default" = "true" ] && return 0 || return 1 ;;
  esac
}

# --- Model Tier Lookup ---

# Get the configured model for a command.
# Args: command_name (e.g., "status", "prd-new")
# Output: model name (e.g., "sonnet", "opus") or empty string
get_model_for_command() {
  local cmd="${1:?Usage: get_model_for_command <command_name>}"

  if [ ! -f "$_MODEL_CONFIG_FILE" ]; then
    echo ""
    return 0
  fi

  if command -v jq &>/dev/null; then
    jq -r --arg cmd "$cmd" '
      .overrides[$cmd] //
      (.tiers[.commands[$cmd]] // "")
    ' "$_MODEL_CONFIG_FILE" 2>/dev/null || echo ""
  else
    python3 -c "
import json
with open('$_MODEL_CONFIG_FILE') as f:
    cfg = json.load(f)
cmd = '$cmd'
override = cfg.get('overrides', {}).get(cmd)
if override:
    print(override)
else:
    tier = cfg.get('commands', {}).get(cmd, '')
    print(cfg.get('tiers', {}).get(tier, '') if tier else '')
" 2>/dev/null || echo ""
  fi
  return 0
}

# --- Epic State Management Functions ---

# Read current epic verification state from epic-state.json.
# Output: JSON to stdout
read_epic_verify_state() {
  if [ ! -f "$_EPIC_STATE_FILE" ]; then
    echo '{"active_epic": null}'
    return 0
  fi
  cat "$_EPIC_STATE_FILE"
  return 0
}

# Write epic verification state to epic-state.json.
# Args: json_string
write_epic_verify_state() {
  local json="${1:?Usage: write_epic_verify_state <json_string>}"
  _json_write "$_EPIC_STATE_FILE" "$json"
  return 0
}

# Initialize epic verification state for a new epic verify.
# Args: epic_name [phase_a_report]
init_epic_verify_state() {
  local epic_name="${1:?Usage: init_epic_verify_state <epic_name> [phase_a_report]}"
  local phase_a_report="${2:-}"
  local max_iter=30 mid_clear_at=10 started_at

  started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read config from epic-verify.json
  if [ -f "$_EPIC_CONFIG_FILE" ]; then
    max_iter=$(_json_get "$_EPIC_CONFIG_FILE" '.phase_b.max_iterations' 2>/dev/null || echo "30")
    mid_clear_at=$(_json_get "$_EPIC_CONFIG_FILE" '.phase_b.mid_loop_clear_at_iteration' 2>/dev/null || echo "10")
  fi

  local state
  if command -v jq &>/dev/null; then
    state=$(jq -n \
      --arg epic "$epic_name" \
      --argjson max "$max_iter" \
      --argjson mid "$mid_clear_at" \
      --arg report "$phase_a_report" \
      --arg started "$started_at" \
      '{
        active_epic: {
          epic_name: $epic,
          phase: "B",
          verify_mode: "STRICT",
          max_iterations: $max,
          current_iteration: 0,
          mid_clear_at: $mid,
          phase_a_report: $report,
          started_at: $started,
          iterations: []
        }
      }')
  else
    state=$(python3 -c "
import json
state = {
    'active_epic': {
        'epic_name': '$epic_name',
        'phase': 'B',
        'verify_mode': 'STRICT',
        'max_iterations': int('$max_iter'),
        'current_iteration': 0,
        'mid_clear_at': int('$mid_clear_at'),
        'phase_a_report': '$phase_a_report',
        'started_at': '$started_at',
        'iterations': []
    }
}
print(json.dumps(state, indent=2))
")
  fi

  write_epic_verify_state "$state"
  echo "✅ Epic verify state initialized: epic=$epic_name max=$max_iter mid_clear=$mid_clear_at"
  return 0
}

# Increment the current iteration count in epic verify state.
# Args: [result] [failures] [files_changed]
increment_epic_iteration() {
  local state result failures files_changed timestamp
  state=$(read_epic_verify_state)

  # Check if active epic exists
  local has_active
  if command -v jq &>/dev/null; then
    has_active=$(echo "$state" | jq -r '.active_epic // empty')
  else
    has_active=$(python3 -c "import json; d=json.loads('$(echo "$state" | tr "'" '"')')
print(d.get('active_epic') or '')" 2>/dev/null)
  fi

  if [ -z "$has_active" ] || [ "$has_active" = "null" ]; then
    echo "❌ No active epic to increment" >&2
    return 1
  fi

  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  result="${1:-EPIC_VERIFY_FAIL}"
  failures="${2:-}"
  files_changed="${3:-}"

  if command -v jq &>/dev/null; then
    local new_state
    new_state=$(echo "$state" | jq \
      --arg ts "$timestamp" \
      --arg res "$result" \
      --arg fail "$failures" \
      --arg files "$files_changed" \
      '.active_epic.current_iteration += 1 |
       .active_epic.iterations += [{
         iteration: .active_epic.current_iteration,
         timestamp: $ts,
         result: $res,
         failures: ($fail | split(",")),
         files_changed: ($files | split(","))
       }]')
    write_epic_verify_state "$new_state"
  else
    python3 -c "
import json
state = json.loads('''$(echo "$state")''')
state['active_epic']['current_iteration'] += 1
state['active_epic']['iterations'].append({
    'iteration': state['active_epic']['current_iteration'],
    'timestamp': '$timestamp',
    'result': '$result',
    'failures': [f for f in '$failures'.split(',') if f],
    'files_changed': [f for f in '$files_changed'.split(',') if f]
})
print(json.dumps(state, indent=2))
" > "$_EPIC_STATE_FILE"
  fi

  local current max
  current=$(echo "$(read_epic_verify_state)" | _json_get /dev/stdin '.active_epic.current_iteration' 2>/dev/null || echo "?")
  max=$(echo "$(read_epic_verify_state)" | _json_get /dev/stdin '.active_epic.max_iterations' 2>/dev/null || echo "?")
  echo "Epic iteration: $current/$max (result: $result)"
  return 0
}

# --- ACE Learning Helpers ---

_ACE_CONFIG_FILE="$_CCPM_ROOT/config/ace-learning.json"

# Read a value from ace-learning.json config.
# Args: section key [default]
# Output: value or default
read_ace_config() {
  local section="${1:?Usage: read_ace_config <section> <key> [default]}"
  local key="${2:?Usage: read_ace_config <section> <key> [default]}"
  local default="${3:-}"

  if [ ! -f "$_ACE_CONFIG_FILE" ]; then
    echo "$default"
    return 0
  fi

  local val
  val=$(_json_get "$_ACE_CONFIG_FILE" ".${section}.${key}" 2>/dev/null || echo "")
  if [ -z "$val" ] || [ "$val" = "null" ]; then
    echo "$default"
  else
    echo "$val"
  fi
}

# Check if an ace-learning feature is enabled.
# Args: feature (e.g., "skillbook", "reflection", "complexity")
# Returns: 0 = enabled, 1 = disabled
ace_feature_enabled() {
  local feature="${1:?Usage: ace_feature_enabled <feature>}"

  if [ ! -f "$_ACE_CONFIG_FILE" ]; then
    return 1
  fi

  local val
  val=$(read_ace_config "$feature" "enabled" "false")
  case "$val" in
    true|True|TRUE|1) return 0 ;;
    *) return 1 ;;
  esac
}

# Append a timestamped entry to the ace-learning log.
# Args: action detail
# Output: appends to .claude/context/ace-learning-log.md
ace_log() {
  local action="${1:?Usage: ace_log <action> <detail>}"
  local detail="${2:-}"
  local ts log_file

  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  log_file="$_CCPM_ROOT/context/ace-learning-log.md"
  mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
  echo "[${ts}] ${action}: ${detail}" >> "$log_file"
}


# --- Memory Agent Helpers ---

_MEMORY_HEALTH="$_CCPM_ROOT/scripts/pm/memory-health.sh"

# Query the Memory Agent for relevant context.
# Args: query [format] [limit]
#   query  - search string
#   format - response format (default: markdown)
#   limit  - max results (default: 10)
# Returns: 0 = success (prints response), 1 = unavailable or error
memory_query() {
  local query="${1:?Usage: memory_query <query> [format] [limit]}"
  local format="${2:-markdown}"
  local limit="${3:-10}"

  # Check health first
  if [ ! -f "$_MEMORY_HEALTH" ]; then
    return 1
  fi
  bash "$_MEMORY_HEALTH" >/dev/null 2>&1 || return 1

  # Read host/port from config
  local host port
  if [ -f "$_CONFIG_FILE" ]; then
    host=$(_json_get "$_CONFIG_FILE" ".memory_agent.host" 2>/dev/null || echo "")
    port=$(_json_get "$_CONFIG_FILE" ".memory_agent.port" 2>/dev/null || echo "")
  fi
  host="${host:-localhost}"
  port="${port:-8888}"
  [ "$host" = "null" ] || [ -z "$host" ] && host="localhost"
  [ "$port" = "null" ] || [ -z "$port" ] && port="8888"

  # Project root for tenant isolation header
  local project_root
  project_root=$(cd "$_CCPM_ROOT/.." 2>/dev/null && pwd || pwd)

  # URL-encode query using jq
  local encoded_query
  encoded_query=$(printf "%s" "$query" | jq -sRr @uri 2>/dev/null || printf "%s" "$query")

  # Execute query
  local response
  response=$(curl -s --max-time 2 \
    -H "X-Project-Root: $project_root" \
    "http://${host}:${port}/query?q=${encoded_query}&format=${format}&limit=${limit}" \
    2>/dev/null || true)

  if [ -n "$response" ]; then
    echo "$response"
    return 0
  else
    return 1
  fi
}

# CLI interface - run commands directly
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    detect-task-type)    detect_task_type "$@" ;;
    detect-tech-stack)   detect_tech_stack "$@" ;;
    get-verify-mode)     get_verify_mode "$@" ;;
    get-verify-profile)  get_verify_profile "$@" ;;
    read-verify-state)   read_verify_state "$@" ;;
    write-verify-state)  write_verify_state "$@" ;;
    init-verify-state)   init_verify_state "$@" ;;
    increment-iteration) increment_iteration "$@" ;;
    read-epic-verify-state)   read_epic_verify_state "$@" ;;
    write-epic-verify-state)  write_epic_verify_state "$@" ;;
    init-epic-verify-state)   init_epic_verify_state "$@" ;;
    increment-epic-iteration) increment_epic_iteration "$@" ;;
    detect-superpowers)       detect_superpowers "$@" ;;
    read-config-bool)         read_config_bool "$@" ;;
    get-model-for-command)    get_model_for_command "$@" ;;
    read-ace-config)          read_ace_config "$@" ;;
    ace-feature-enabled)      ace_feature_enabled "$@" ;;
    ace-log)                  ace_log "$@" ;;
    memory-query)             memory_query "$@" ;;
    *)
      echo "Usage: $0 <command> [args...]"
      echo "Commands: detect-task-type, detect-tech-stack, get-verify-mode,"
      echo "          get-verify-profile, read-verify-state, write-verify-state,"
      echo "          init-verify-state, increment-iteration,"
      echo "          read-epic-verify-state, write-epic-verify-state,"
      echo "          init-epic-verify-state, increment-epic-iteration,"
      echo "          detect-superpowers, read-config-bool,"
      echo "          get-model-for-command,"
      echo "          read-ace-config, ace-feature-enabled, ace-log,"
      echo "          memory-query"
      exit 1
      ;;
  esac
fi
