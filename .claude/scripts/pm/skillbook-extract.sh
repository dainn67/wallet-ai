#!/usr/bin/env bash
# Skillbook utility functions for ace-learning.
# Defines the skillbook entry format and provides low-level CRUD operations.
# Actual LLM-driven extraction logic is in T010 (issue #91).
#
# Usage:
#   source .claude/scripts/pm/skillbook-extract.sh
#   init_skillbook
#   count_skillbook_entries
#   next_skillbook_id
#   append_skillbook_entry <pattern_type> <context_keywords> <source_task> <body>
#
# Skillbook Entry Format (PRD FR-1, AD-1):
#   ---
#   id: SKL-NNN
#   pattern: helpful|pitfall
#   context: keyword1,keyword2,...
#   source_task: epic/name#issue_number
#   created: YYYY-MM-DDTHH:MM:SSZ
#   last_matched: YYYY-MM-DDTHH:MM:SSZ
#   match_count: 0
#   ---
#   **Pattern:** One-line description.
#   **Why:** Explanation of why this matters.
#   **When applicable:** Conditions or context where this applies.
#   **Resolution:** What to do / how to avoid the pitfall.
#
#   (entries separated by blank line + --- block)
#
# Or run as standalone:
#   bash .claude/scripts/pm/skillbook-extract.sh init-skillbook
#   bash .claude/scripts/pm/skillbook-extract.sh count-skillbook-entries
#   bash .claude/scripts/pm/skillbook-extract.sh next-skillbook-id
#   bash .claude/scripts/pm/skillbook-extract.sh append-skillbook-entry <pattern> <ctx> <src> <body>

# Detect CCPM root (where scripts/pm/ lives — same as lifecycle-helpers.sh)
_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"

# Source lifecycle helpers for read_ace_config, ace_log, _json_get
_LH="$_CCPM_ROOT/scripts/pm/lifecycle-helpers.sh"
if [ -f "$_LH" ]; then
  # shellcheck source=lifecycle-helpers.sh
  source "$_LH" 2>/dev/null || true
fi

_SKILLBOOK_FILE="$_CCPM_ROOT/context/skillbook.md"
_SKILLBOOK_HEADER="# Skillbook
> Accumulated learnings from task execution. Entries auto-extracted by ace-learning.
> Edit manually to correct or remove entries. Max 50 entries."

# Create the skillbook file with header if it doesn't exist. Idempotent.
init_skillbook() {
  if [ -f "$_SKILLBOOK_FILE" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$_SKILLBOOK_FILE")" 2>/dev/null || true
  printf '%s\n' "$_SKILLBOOK_HEADER" > "$_SKILLBOOK_FILE"
  if command -v ace_log &>/dev/null; then
    ace_log "INIT" "skillbook created at $_SKILLBOOK_FILE"
  fi
}

# Count the number of entries in the skillbook by counting id: SKL- lines.
# Output: integer count to stdout
count_skillbook_entries() {
  if [ ! -f "$_SKILLBOOK_FILE" ]; then
    echo 0
    return 0
  fi
  local count
  count=$(grep -c '^id: SKL-' "$_SKILLBOOK_FILE" 2>/dev/null) || count=0
  echo "${count:-0}"
}

# Return the next available SKL-NNN id.
# Output: e.g. "SKL-001" to stdout
next_skillbook_id() {
  local count
  count=$(count_skillbook_entries)
  printf 'SKL-%03d' $((count + 1))
}

# Append a formatted entry to the skillbook.
# Args: pattern_type context_keywords source_task body
# pattern_type: "helpful" or "pitfall"
# context_keywords: comma-separated keywords for matching
# source_task: e.g. "epic/ace-learning#90"
# body: markdown body text (Pattern/Why/When applicable/Resolution)
append_skillbook_entry() {
  local pattern_type="${1:?Usage: append_skillbook_entry <pattern_type> <context_keywords> <source_task> <body>}"
  local context_keywords="${2:?Usage: append_skillbook_entry <pattern_type> <context_keywords> <source_task> <body>}"
  local source_task="${3:?Usage: append_skillbook_entry <pattern_type> <context_keywords> <source_task> <body>}"
  local body="${4:?Usage: append_skillbook_entry <pattern_type> <context_keywords> <source_task> <body>}"

  init_skillbook

  # Check capacity
  local max_entries current_count
  if command -v read_ace_config &>/dev/null; then
    max_entries=$(read_ace_config "skillbook" "max_entries" "50")
  else
    max_entries=50
  fi
  current_count=$(count_skillbook_entries)

  if [ "$current_count" -ge "$max_entries" ]; then
    echo "⚠️ Skillbook at capacity ($current_count/$max_entries entries). Entry skipped." >&2
    if command -v ace_log &>/dev/null; then
      ace_log "PRUNE" "skillbook at capacity ($current_count/$max_entries), entry skipped"
    fi
    return 1
  fi

  local id ts
  id=$(next_skillbook_id)
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Append blank line before entry if file has content beyond header
  if [ "$(wc -l < "$_SKILLBOOK_FILE")" -gt 3 ]; then
    echo "" >> "$_SKILLBOOK_FILE"
  fi

  cat >> "$_SKILLBOOK_FILE" <<EOF
---
id: ${id}
pattern: ${pattern_type}
context: ${context_keywords}
source_task: ${source_task}
created: ${ts}
last_matched: ${ts}
match_count: 0
---
${body}
EOF

  if command -v ace_log &>/dev/null; then
    ace_log "EXTRACT" "appended $id ($pattern_type) from $source_task"
  fi
}

# Gather context for learning extraction and output a structured prompt for the calling agent.
# The function outputs formatted context to stdout so the agent can analyze and extract learnings.
# Non-blocking: any failure logs a warning and returns 0.
#
# Args: epic_name issue_number
# Usage: extract_learnings "ace-learning" "91"
extract_learnings() {
  local epic_name="${1:-}"
  local issue_number="${2:-}"

  # Check feature enabled (non-blocking if helpers not loaded)
  if command -v ace_feature_enabled &>/dev/null; then
    if ! ace_feature_enabled "skillbook" 2>/dev/null; then
      return 0
    fi
  fi

  # Check capacity
  local max_entries current_count
  if command -v read_ace_config &>/dev/null; then
    max_entries=$(read_ace_config "skillbook" "max_entries" "50" 2>/dev/null || echo "50")
  else
    max_entries=50
  fi
  current_count=$(count_skillbook_entries 2>/dev/null || echo "0")
  if [ "$current_count" -ge "$max_entries" ]; then
    if command -v ace_log &>/dev/null; then
      ace_log "EXTRACT" "skipped: skillbook at capacity ($current_count/$max_entries)" 2>/dev/null || true
    fi
    return 0
  fi

  # Gather inputs
  local task_file=""
  local verify_report=""
  local handoff_note=""
  local git_diff=""

  # Task file
  if [ -n "$epic_name" ] && [ -n "$issue_number" ]; then
    local candidate="$_CCPM_ROOT/epics/${epic_name}/${issue_number}.md"
    if [ -f "$candidate" ]; then
      task_file=$(cat "$candidate" 2>/dev/null || true)
    fi
  fi

  # Verify report
  local verify_path="$_CCPM_ROOT/context/verify/state.json"
  if [ -f "$verify_path" ]; then
    verify_report=$(cat "$verify_path" 2>/dev/null || true)
  fi

  # Handoff note
  local handoff_path="$_CCPM_ROOT/context/handoffs/latest.md"
  if [ -f "$handoff_path" ]; then
    handoff_note=$(cat "$handoff_path" 2>/dev/null || true)
  fi

  # Git diff for recent commits on this issue
  if [ -n "$issue_number" ]; then
    git_diff=$(git -C "$_CCPM_ROOT" log --oneline --all 2>/dev/null \
      | grep -i "Issue #${issue_number}:" | head -5 \
      | awk '{print $1}' \
      | while read -r sha; do
          git -C "$_CCPM_ROOT" show --stat "$sha" 2>/dev/null | head -20
        done) || git_diff=""
  fi

  # Output extraction context for the calling agent
  cat <<EXTRACTION_CONTEXT
<!-- ace-learning:extract epic=${epic_name} issue=${issue_number} -->
## Learning Extraction Context

### Task File
${task_file:-"(not found)"}

### Git Diff Summary (commits for Issue #${issue_number})
${git_diff:-"(no commits found)"}

### Verify Report
${verify_report:-"(not found)"}

### Handoff Note
${handoff_note:-"(not found)"}

### Extraction Questions
Please analyze the above context and answer these 3 questions:
1. **Reusable pattern**: What pattern or approach worked well that could help on future tasks?
2. **Pitfall to avoid**: What error, gotcha, or anti-pattern was encountered or should be warned about?
3. **Effective approach**: What technique or decision made this task go smoothly?

For each answer worth capturing (skip trivial/obvious ones), output an entry in this format:
pattern_type: helpful|pitfall
context_keywords: comma,separated,keywords
body: |
  **Pattern:** One-line description.
  **Why:** Explanation of why this matters.
  **When applicable:** Conditions or context where this applies.
  **Resolution:** What to do / how to avoid the pitfall.

Output "nothing noteworthy" if nothing is worth capturing.
<!-- /ace-learning:extract -->
EXTRACTION_CONTEXT

  if command -v ace_log &>/dev/null; then
    ace_log "EXTRACT" "context gathered for epic/${epic_name}#${issue_number}" 2>/dev/null || true
  fi
  return 0
}

# CLI interface
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  set -euo pipefail
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    init-skillbook)          init_skillbook "$@" ;;
    count-skillbook-entries) count_skillbook_entries "$@" ;;
    next-skillbook-id)       next_skillbook_id "$@" ;;
    append-skillbook-entry)  append_skillbook_entry "$@" ;;
    extract-learnings)       extract_learnings "$@" ;;
    *)
      echo "Usage: $0 <command> [args...]"
      echo "Commands: init-skillbook, count-skillbook-entries, next-skillbook-id, append-skillbook-entry, extract-learnings"
      exit 1
      ;;
  esac
fi
