#!/usr/bin/env bash
# Complexity scoring engine for ace-learning (FR-6, AD-4).
# Computes a 1-10 complexity score from task file signals.
# Suggests model tier and strategy hints for high-complexity tasks.
#
# Usage:
#   source .claude/scripts/pm/complexity-score.sh
#   compute_complexity_score ".claude/epics/ace-learning/010.md"
#   suggest_model 7       # → "opus"
#   get_strategy_hints 8  # → strategy hints
#
# Or run standalone:
#   bash .claude/scripts/pm/complexity-score.sh compute-complexity-score <task_file>
#   bash .claude/scripts/pm/complexity-score.sh suggest-model <score>
#   bash .claude/scripts/pm/complexity-score.sh get-strategy-hints <score>

_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"

_LH="$_CCPM_ROOT/scripts/pm/lifecycle-helpers.sh"
if [ -f "$_LH" ]; then
  source "$_LH" 2>/dev/null || true
fi

# Map score 1-3→haiku, 4-6→sonnet, 7-10→opus.
# Args: score (integer 1-10)
# Output: model name to stdout
suggest_model() {
  local score="${1:-5}"
  if [ "$score" -le 3 ]; then
    echo "haiku"
  elif [ "$score" -le 6 ]; then
    echo "sonnet"
  else
    echo "opus"
  fi
}

# Return strategy hints for high-complexity tasks.
# Args: score (integer 1-10)
# Output: hint lines to stdout (empty if score < 7)
get_strategy_hints() {
  local score="${1:-0}"
  if [ "$score" -ge 7 ]; then
    echo "- Break into sub-steps before coding. Write design file first."
  fi
  if [ "$score" -ge 8 ]; then
    echo "- Run existing tests BEFORE making changes. Create regression safety net."
  fi
  if [ "$score" -ge 9 ]; then
    echo "- Consider manual review with user before proceeding. This task has high failure risk."
  fi
}

# Compute 1-10 complexity score from task file signals.
# Args: task_file path
# Output: score + breakdown to stdout
# Returns: 0 always (non-blocking; outputs 5 as fallback on error)
compute_complexity_score() {
  local task_file="${1:?Usage: compute_complexity_score <task_file>}"

  # Check if feature enabled
  if command -v ace_feature_enabled &>/dev/null; then
    if ! ace_feature_enabled "complexity" 2>/dev/null; then
      return 0
    fi
  fi

  if [ ! -f "$task_file" ]; then
    echo "⚠️ Task file not found: $task_file" >&2
    return 0
  fi

  local raw=0
  local breakdown=""

  # Signal 1: Files affected (weight 2)
  local files_count
  files_count=$(grep -c '^\s*-\s' <(sed -n '/^files:/,/^[a-z]/p' "$task_file" | grep '^\s*-\s') 2>/dev/null) || files_count=0
  local sig1=0
  if [ "$files_count" -ge 10 ]; then sig1=3
  elif [ "$files_count" -ge 6 ]; then sig1=2
  elif [ "$files_count" -ge 3 ]; then sig1=1
  fi
  raw=$((raw + sig1 * 2))
  breakdown="files(${files_count}→×${sig1}×2)"

  # Signal 2: Cross-module / unique parent dirs (weight 3)
  local dirs_count
  dirs_count=$(sed -n '/^files:/,/^[a-z]/p' "$task_file" | grep '^\s*-\s' | sed 's|^\s*-\s*||' | xargs -I{} dirname {} 2>/dev/null | sort -u | wc -l | tr -d ' ') || dirs_count=1
  [ "$dirs_count" -eq 0 ] && dirs_count=1
  local sig2=0
  if [ "$dirs_count" -ge 3 ]; then sig2=2
  elif [ "$dirs_count" -ge 2 ]; then sig2=1
  fi
  raw=$((raw + sig2 * 3))
  breakdown="$breakdown modules(${dirs_count}→×${sig2}×3)"

  # Signal 3: Dependencies count (weight 2)
  local deps_line
  deps_line=$(grep '^depends_on:' "$task_file" | head -1 || echo "")
  local deps_count=0
  if echo "$deps_line" | grep -q '\[\]'; then
    deps_count=0
  else
    deps_count=$(echo "$deps_line" | grep -o '[0-9]\{3\}' | wc -l | tr -d ' ')
  fi
  local sig3=0
  if [ "$deps_count" -ge 3 ]; then sig3=2
  elif [ "$deps_count" -ge 1 ]; then sig3=1
  fi
  raw=$((raw + sig3 * 2))
  breakdown="$breakdown deps(${deps_count}→×${sig3}×2)"

  # Signal 4: Task type from complexity field or inferred (weight 1)
  local complexity_field
  complexity_field=$(grep '^complexity:' "$task_file" | head -1 | sed 's/^complexity: *//' || echo "")
  local sig4=0
  case "$complexity_field" in
    complex|REFACTOR)    sig4=2 ;;
    moderate|FEATURE|ENHANCEMENT) sig4=1 ;;
    *) sig4=0 ;;
  esac
  raw=$((raw + sig4 * 1))
  breakdown="$breakdown type(${complexity_field}→×${sig4}×1)"

  # Signal 5: Acceptance criteria count (weight 1)
  local ac_count
  ac_count=$(grep -c '^\s*- \[ \]' "$task_file" 2>/dev/null) || ac_count=0
  local sig5=0
  if [ "$ac_count" -ge 7 ]; then sig5=2
  elif [ "$ac_count" -ge 4 ]; then sig5=1
  fi
  raw=$((raw + sig5 * 1))
  breakdown="$breakdown ac(${ac_count}→×${sig5}×1)"

  # Signal 6: Breaking changes risk — scan for keywords (weight 2)
  local breaking_count
  breaking_count=$(grep -iEc 'api|schema|migration|breaking|backward.compat' "$task_file" 2>/dev/null) || breaking_count=0
  local sig6=0
  if [ "$breaking_count" -ge 3 ]; then sig6=2
  elif [ "$breaking_count" -ge 1 ]; then sig6=1
  fi
  raw=$((raw + sig6 * 2))
  breakdown="$breakdown breaking(${breaking_count}hits→×${sig6}×2)"

  # Normalize: score = max(1, min(10, raw * 10 / 24)), rounded
  local score
  score=$(python3 -c "raw=$raw; score=max(1, min(10, round(raw * 10 / 24))); print(score)" 2>/dev/null) || score=$((raw * 10 / 24))
  [ -z "$score" ] || [ "$score" -lt 1 ] && score=1
  [ "$score" -gt 10 ] && score=10

  local suggested_model
  suggested_model=$(suggest_model "$score")

  echo "Complexity: ${score}/10 | ${breakdown} | raw=${raw}/24"
  echo "Model suggestion: ${suggested_model}"

  local hints
  hints=$(get_strategy_hints "$score")
  if [ -n "$hints" ]; then
    echo "Strategy hints:"
    echo "$hints"
  fi

  if command -v ace_log &>/dev/null; then
    ace_log "SCORE" "task=$(basename "$task_file") score=${score}/10 model=${suggested_model}"
  fi

  return 0
}

# CLI interface
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  set -euo pipefail
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    compute-complexity-score) compute_complexity_score "$@" ;;
    suggest-model)            suggest_model "$@" ;;
    get-strategy-hints)       get_strategy_hints "$@" ;;
    *)
      echo "Usage: $0 <command> [args...]"
      echo "Commands: compute-complexity-score, suggest-model, get-strategy-hints"
      exit 1
      ;;
  esac
fi
