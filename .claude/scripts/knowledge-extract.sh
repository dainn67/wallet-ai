#!/usr/bin/env bash
# Knowledge extraction utility for issue-complete workflow.
# Reads debug journal (if exists) + git diff + issue body and outputs a structured
# close comment template to stdout. Light processing only — LLM fills placeholders.
#
# Usage (sourced):
#   source .claude/scripts/knowledge-extract.sh
#   knowledge_extract <issue_number>
#
# Usage (standalone):
#   bash .claude/scripts/knowledge-extract.sh extract <issue_number>
#
# Output: Markdown close comment template with Root cause / Fix / Debug Trail sections.
# FR-4: knowledge-extract requirement (issue-new PRD)

# Detect CCPM root (where scripts/ lives)
_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"

# Validate issue number: must be non-empty digits only
_validate_issue_number() {
  local issue_number="$1"
  if [[ -z "$issue_number" ]]; then
    echo "❌ issue_number is required" >&2
    return 1
  fi
  if ! [[ "$issue_number" =~ ^[0-9]+$ ]]; then
    echo "❌ Invalid issue number: '$issue_number' (must be numeric)" >&2
    return 1
  fi
}

# Extract round summaries from a debug journal file.
# Args: journal_file_path
# Output: compressed summary lines to stdout (blank if file empty/missing)
_extract_journal_summary() {
  local journal_file="$1"
  if [ ! -f "$journal_file" ]; then
    return 0
  fi
  # Grab round headers, hypotheses, and results — key signal lines
  grep -E '(^## Round|^\*\*Hypothesis:\*\*|^\*\*Result:\*\*)' "$journal_file" 2>/dev/null || true
}

# Generate a structured close comment template to stdout.
# Args: issue_number
knowledge_extract() {
  local issue_number="${1:?Usage: knowledge_extract <issue_number>}"
  _validate_issue_number "$issue_number" || return 1

  local journal_file="$_CCPM_ROOT/context/sessions/issue-${issue_number}-debug.md"
  local has_journal=false
  local journal_summary=""

  # Read journal if present
  if [ -f "$journal_file" ]; then
    has_journal=true
    journal_summary=$(_extract_journal_summary "$journal_file")
  fi

  # Get changed file list from git diff (non-fatal — may be no code changes)
  local diff_files=""
  diff_files=$(git -C "$_CCPM_ROOT" diff HEAD~1 --name-only 2>/dev/null) || diff_files=""

  # Build changed files list for template
  local files_section=""
  if [ -n "$diff_files" ]; then
    files_section=$(printf '%s\n' "$diff_files" | sed 's/^/- /')
  else
    files_section="(no code changes)"
  fi

  # Output close comment template
  cat <<TEMPLATE
## Resolution

**Root cause:** <!-- Claude fills this -->
**Fix:** <!-- Claude fills this -->
**Approaches tried:** <!-- Claude fills from journal if available -->

## Changes

${files_section}

TEMPLATE

  # Debug Trail section — only when journal exists
  if [ "$has_journal" = true ]; then
    cat <<TRAIL_SECTION
## Debug Trail

${journal_summary:-"(no debug rounds recorded)"}

TRAIL_SECTION
  fi

  cat <<LEARNINGS
## Learnings extracted

- Skillbook: <!-- Claude fills if reusable pattern found -->
- Auto Memory: <!-- Claude fills if project-level insight applicable -->
LEARNINGS
}

# CLI interface
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  set -euo pipefail
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    extract) knowledge_extract "$@" ;;
    *)
      echo "Usage: $0 extract <issue_number>"
      exit 1
      ;;
  esac
fi
