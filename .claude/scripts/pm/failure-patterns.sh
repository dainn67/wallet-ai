#!/usr/bin/env bash
# Failure pattern detection for ace-learning (US-6).
# Scans reflection files across an epic and flags recurring failure patterns.
#
# Usage:
#   source .claude/scripts/pm/failure-patterns.sh
#   detect_failure_patterns "ace-learning"
#
# Or standalone:
#   bash .claude/scripts/pm/failure-patterns.sh detect-failure-patterns <epic_name>

_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"

_LH="$_CCPM_ROOT/scripts/pm/lifecycle-helpers.sh"
if [ -f "$_LH" ]; then
  source "$_LH" 2>/dev/null || true
fi

# Compute keyword overlap ratio between two strings (0-100 integer percent).
# Args: text_a text_b
# Output: overlap percentage (0-100) to stdout
_keyword_overlap() {
  local a="$1" b="$2"
  [ -z "$a" ] || [ -z "$b" ] && { echo 0; return; }

  # Extract words (5+ chars, lowercase)
  local words_a words_b
  words_a=$(echo "$a" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z' '\n' | awk 'length>=5' | sort -u)
  words_b=$(echo "$b" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z' '\n' | awk 'length>=5' | sort -u)

  local total_b
  total_b=$(echo "$words_b" | grep -c '.' 2>/dev/null) || total_b=0
  [ "$total_b" -eq 0 ] && { echo 0; return; }

  local matched=0
  while IFS= read -r w; do
    [ -z "$w" ] && continue
    if echo "$words_a" | grep -qx "$w"; then
      matched=$((matched + 1))
    fi
  done <<< "$words_b"

  echo $((matched * 100 / total_b))
}

# Detect recurring failure patterns across an epic's reflection files.
# Patterns: 3+ reflection "What failed" sections with >60% keyword overlap.
# Args: epic_name
# Output: formatted warning block to stdout (empty if no patterns detected)
detect_failure_patterns() {
  local epic_name="${1:?Usage: detect_failure_patterns <epic_name>}"
  local reflections_dir="$_CCPM_ROOT/epics/$epic_name/reflections"

  [ -d "$reflections_dir" ] || return 0

  # Collect "What failed" section text from each reflection file
  local -a what_failed_texts=()
  local -a what_failed_tasks=()
  local -a what_failed_files=()

  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    # Extract task number from filename: task-{N}-attempt-{M}.md
    local task_num
    task_num=$(basename "$f" | sed 's/task-\([0-9]*\)-attempt.*/\1/')
    # Extract "What failed" section content (between ## What failed and next ##)
    local what_failed
    what_failed=$(sed -n '/^## What failed/,/^## /p' "$f" | grep -v '^##' | head -5 | tr '\n' ' ')
    if [ -n "$what_failed" ] && [ "$what_failed" != " " ]; then
      what_failed_texts+=("$what_failed")
      what_failed_tasks+=("$task_num")
      what_failed_files+=("$f")
    fi
  done < <(find "$reflections_dir" -name 'task-*-attempt-*.md' | sort)

  local total=${#what_failed_texts[@]}
  [ "$total" -lt 3 ] && return 0

  # Find groups with >60% overlap (n² comparison)
  local -A group_members  # group_id → space-separated task nums
  local -A group_patterns # group_id → representative text
  local group_count=0

  local i j
  for ((i=0; i<total; i++)); do
    local already_grouped=0
    local gid
    for gid in "${!group_members[@]}"; do
      local rep="${group_patterns[$gid]}"
      local overlap
      overlap=$(_keyword_overlap "$rep" "${what_failed_texts[$i]}")
      if [ "$overlap" -ge 60 ]; then
        group_members[$gid]="${group_members[$gid]} ${what_failed_tasks[$i]}"
        already_grouped=1
        break
      fi
    done
    if [ "$already_grouped" -eq 0 ]; then
      group_count=$((group_count + 1))
      group_members[$group_count]="${what_failed_tasks[$i]}"
      group_patterns[$group_count]="${what_failed_texts[$i]}"
    fi
  done

  # Report groups with 3+ members
  local found_pattern=0
  local gid
  for gid in "${!group_members[@]}"; do
    local members="${group_members[$gid]}"
    local member_count
    member_count=$(echo "$members" | wc -w | tr -d ' ')
    if [ "$member_count" -ge 3 ]; then
      if [ "$found_pattern" -eq 0 ]; then
        echo "⚠️ Recurring failure patterns detected:"
        echo ""
        found_pattern=1
      fi
      local pattern_text="${group_patterns[$gid]}"
      echo "**Pattern:** $(echo "$pattern_text" | cut -c1-120)"
      echo "**Affected tasks:** #$(echo "$members" | tr ' ' ', #' | sed 's/^, //')"
      echo "**Suggested root cause:** Recurring issue in this area — review approach before next attempt."
      echo ""

      if command -v ace_log &>/dev/null; then
        ace_log "PATTERN" "recurring failure in tasks ${members} for epic=${epic_name}"
      fi
    fi
  done
}

# CLI interface
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  set -euo pipefail
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    detect-failure-patterns) detect_failure_patterns "$@" ;;
    *)
      echo "Usage: $0 <command> [args...]"
      echo "Commands: detect-failure-patterns"
      exit 1
      ;;
  esac
fi
