#!/usr/bin/env bash
# Skillbook injection for ace-learning (FR-3, AD-2).
# Keyword-based matching to inject relevant skills into agent context at issue-start.
#
# Usage:
#   source .claude/scripts/pm/skillbook-inject.sh
#   inject_relevant_skills ".claude/epics/ace-learning/010.md"
#
# Or standalone:
#   bash .claude/scripts/pm/skillbook-inject.sh inject-relevant-skills <task_file>
#   bash .claude/scripts/pm/skillbook-inject.sh extract-task-keywords <task_file>

_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"

_LH="$_CCPM_ROOT/scripts/pm/lifecycle-helpers.sh"
if [ -f "$_LH" ]; then
  source "$_LH" 2>/dev/null || true
fi

_SKILLBOOK_FILE="$_CCPM_ROOT/context/skillbook.md"

# Extract keywords from a task file for matching.
# Sources: directory names from files:, file extensions, task type, AC keywords.
# Args: task_file
# Output: space-separated keywords to stdout
extract_task_keywords() {
  local task_file="${1:?Usage: extract_task_keywords <task_file>}"
  [ -f "$task_file" ] || { echo ""; return 0; }

  local keywords=""

  # Keywords from files: paths — directory names and base names (no ext)
  local file_keywords=""
  while IFS= read -r f; do
    f=$(echo "$f" | sed 's|^\s*-\s*||')
    [ -z "$f" ] && continue
    # parent directory name (last component only)
    local d="${f%/*}"
    [ "$d" != "$f" ] && file_keywords="$file_keywords ${d##*/}"
    # basename without extension
    local b="${f##*/}"
    file_keywords="$file_keywords ${b%.*}"
  done < <(sed -n '/^files:/,/^[a-z]/p' "$task_file" | grep '^\s*-\s')
  keywords="$keywords $file_keywords"

  # Task type from complexity field
  local complexity
  complexity=$(grep '^complexity:' "$task_file" | head -1 | sed 's/^complexity: *//')
  [ -n "$complexity" ] && keywords="$keywords $complexity"

  # Key words from acceptance criteria (single words, no stop words, 5+ chars)
  local ac_words
  ac_words=$(grep '^\s*- \[ \]' "$task_file" \
    | sed 's/^\s*- \[ \] *//' \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs 'a-z' ' ' \
    | tr ' ' '\n' \
    | awk 'length >= 5' \
    | grep -vE '^(should|where|which|their|there|these|those|would|could|after|before|ensure|using|with|from|that|this|will|have|when)$' \
    | sort | uniq -c | sort -rn | head -10 | awk '{print $2}' \
    | tr '\n' ' ')
  keywords="$keywords $ac_words"

  # Trim and deduplicate
  echo "$keywords" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' '
}

# Score a skillbook entry against task keywords using keyword overlap.
# Args: entry_context_field task_keywords_space_separated
# Output: overlap count (integer) to stdout
score_skill_entry() {
  local entry_context="${1:-}"
  local task_keywords="${2:-}"
  [ -z "$entry_context" ] || [ -z "$task_keywords" ] && { echo 0; return 0; }

  local count=0
  local kw
  while IFS= read -r kw; do
    [ -z "$kw" ] && continue
    if echo "$entry_context" | grep -qi "$kw"; then
      count=$((count + 1))
    fi
  done <<< "$(echo "$task_keywords" | tr ' ' '\n')"
  echo "$count"
}

# Inject relevant skillbook entries into agent context.
# Args: task_file
# Output: formatted markdown section to stdout (empty if nothing matches)
inject_relevant_skills() {
  local task_file="${1:?Usage: inject_relevant_skills <task_file>}"

  # Check feature enabled
  if command -v ace_feature_enabled &>/dev/null; then
    ace_feature_enabled "skillbook" 2>/dev/null || return 0
  fi

  [ -f "$_SKILLBOOK_FILE" ] || return 0

  # Check skillbook has entries
  local entry_count
  entry_count=$(grep -c '^id: SKL-' "$_SKILLBOOK_FILE" 2>/dev/null) || entry_count=0
  [ "$entry_count" -eq 0 ] && return 0

  # Extract task keywords
  local task_keywords
  task_keywords=$(extract_task_keywords "$task_file")
  [ -z "$(echo "$task_keywords" | tr -d ' ')" ] && return 0

  # Read config for injection limits
  local max_inject=5 max_tokens=500
  if command -v read_ace_config &>/dev/null; then
    max_inject=$(read_ace_config "skillbook" "inject_top" "5")
    max_tokens=$(read_ace_config "skillbook" "inject_max_tokens" "500")
  fi

  # Parse entries and score them
  # Each entry starts with ---\nid: SKL-
  local scored_entries=""
  local in_entry=0 entry_id="" entry_context="" entry_body="" entry_pattern=""
  local line

  while IFS= read -r line; do
    if echo "$line" | grep -q '^id: SKL-'; then
      entry_id=$(echo "$line" | sed 's/^id: //')
      in_entry=1
      entry_context=""
      entry_body=""
      entry_pattern=""
    elif [ "$in_entry" -eq 1 ]; then
      if echo "$line" | grep -q '^context:'; then
        entry_context=$(echo "$line" | sed 's/^context: //')
      elif echo "$line" | grep -q '^pattern:'; then
        entry_pattern=$(echo "$line" | sed 's/^pattern: //')
      elif echo "$line" | grep -qE '^\*\*Pattern\*\*|^\*\*Why\*\*|^\*\*When|^\*\*Resolution'; then
        entry_body="$entry_body$line\n"
      elif [ -z "$line" ] && echo "$entry_body" | grep -q '.'; then
        # End of entry body — score and store
        local score
        score=$(score_skill_entry "$entry_context" "$task_keywords")
        if [ "$score" -gt 0 ]; then
          scored_entries="$scored_entries${score}|||${entry_id}|||${entry_pattern}|||${entry_body}\n"
        fi
        in_entry=0
      fi
    fi
  done < "$_SKILLBOOK_FILE"

  [ -z "$scored_entries" ] && return 0

  # Sort by score (descending) and take top N
  local selected
  selected=$(printf "%b" "$scored_entries" | sort -t'|' -k1 -rn | head -n "$max_inject")
  [ -z "$selected" ] && return 0

  # Format output — enforce token cap (~4 chars per token)
  local char_limit=$((max_tokens * 4))
  local output="## Relevant lessons from previous tasks:\n\n"
  local char_count=${#output}
  local injected=0 matched_ids=""

  while IFS= read -r scored_line; do
    [ -z "$scored_line" ] && continue
    local sid sid_part sbody
    sid=$(echo "$scored_line" | cut -d'|' -f1)
    sid_part=$(echo "$scored_line" | cut -d'|' -f4)
    sbody=$(echo "$scored_line" | cut -d'|' -f7-)
    local entry_text="**${sid_part}:** $(printf "%b" "$sbody")\n\n"
    local entry_len=${#entry_text}
    if [ $((char_count + entry_len)) -le "$char_limit" ]; then
      output="$output$entry_text"
      char_count=$((char_count + entry_len))
      injected=$((injected + 1))
      matched_ids="$matched_ids $sid_part"
    fi
  done <<< "$selected"

  if [ "$injected" -gt 0 ]; then
    printf "%b" "$output"
    if command -v ace_log &>/dev/null; then
      ace_log "INJECT" "injected ${injected} skills for $(basename "$task_file")"
    fi
  fi
}

# CLI interface
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  set -euo pipefail
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    extract-task-keywords) extract_task_keywords "$@" ;;
    score-skill-entry)     score_skill_entry "$@" ;;
    inject-relevant-skills) inject_relevant_skills "$@" ;;
    *)
      echo "Usage: $0 <command> [args...]"
      echo "Commands: extract-task-keywords, score-skill-entry, inject-relevant-skills"
      exit 1
      ;;
  esac
fi
