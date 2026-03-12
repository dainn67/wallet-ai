#!/usr/bin/env bash
# Debug journal archive utility for issue-complete workflow.
# Compresses journal to 10-15 line summary, moves original to sessions/archive/,
# and deletes active journal file. Idempotent — exits 0 if no journal found.
#
# Usage (sourced):
#   source .gemini/scripts/debug-journal-archive.sh
#   journal_archive <issue_number>
#
# Usage (standalone):
#   bash .gemini/scripts/debug-journal-archive.sh archive <issue_number>
#
# Output: compressed summary to stdout; side-effect: original file moved to archive/.
# FR-5: debug-journal-archive requirement (issue-new PRD)

# Detect CCPM root (where scripts/ lives)
_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"

# Validate issue number: must be non-empty digits only
_validate_issue_number_arch() {
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

# Compress journal to at most 15 lines by extracting key signal lines.
# Strategy: round headers + hypothesis + result lines, capped at 15 total.
# Args: journal_file_path
# Output: compressed summary lines to stdout
_compress_journal() {
  local journal_file="$1"

  # Extract key signal lines: round headers, hypotheses, results
  local key_lines
  key_lines=$(grep -E '(^## Round|^\*\*Hypothesis:\*\*|^\*\*Result:\*\*)' "$journal_file" 2>/dev/null) || key_lines=""

  if [ -z "$key_lines" ]; then
    echo "No debug rounds recorded"
    return 0
  fi

  # Cap at 15 lines
  printf '%s\n' "$key_lines" | head -15
}

# Archive a debug journal for the given issue.
# Compresses to 10-15 line summary (stdout), moves original to archive/.
# Graceful no-op when journal does not exist.
# Args: issue_number
journal_archive() {
  local issue_number="${1:?Usage: journal_archive <issue_number>}"
  _validate_issue_number_arch "$issue_number" || return 1

  local sessions_dir="$_CCPM_ROOT/context/sessions"
  local journal_file="$sessions_dir/issue-${issue_number}-debug.md"
  local archive_dir="$sessions_dir/archive"

  # Graceful skip when no journal exists (idempotent)
  if [ ! -f "$journal_file" ]; then
    return 0
  fi

  # Generate compressed summary before moving file
  local summary
  summary=$(_compress_journal "$journal_file")

  # Ensure archive directory exists
  mkdir -p "$archive_dir" 2>/dev/null || true

  # Move original to archive (overwrite silently if re-archiving)
  mv "$journal_file" "$archive_dir/" 2>/dev/null || {
    echo "❌ Failed to archive $journal_file → $archive_dir/" >&2
    return 1
  }

  # Output compressed summary for caller (e.g. issue-complete close comment)
  printf '%s\n' "$summary"
}

# CLI interface
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  set -euo pipefail
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    archive) journal_archive "$@" ;;
    *)
      echo "Usage: $0 archive <issue_number>"
      exit 1
      ;;
  esac
fi
