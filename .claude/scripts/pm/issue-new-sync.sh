#!/usr/bin/env bash
# GitHub Issue creation sync script for pm:issue-new.
# Usage:
#   bash .claude/scripts/pm/issue-new-sync.sh create "<title>" "<body_file>" "<labels_csv>"
#
# Or source and call directly:
#   source .claude/scripts/pm/issue-new-sync.sh
#   issue_new_sync "<title>" "<body_file>" "<labels_csv>"
#
# Arguments:
#   title       - Issue title (required, non-empty)
#   body_file   - Path to file containing issue body (required, must exist)
#   labels_csv  - Comma-separated labels (optional; source:issue-new always added)
#
# Output: Issue number on stdout on success. Exits 0 on success, 1 on failure.

set -euo pipefail

_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=scripts/pm/github-helpers.sh
source "$_CCPM_ROOT/scripts/pm/github-helpers.sh"

# Create a GitHub Issue and print its number to stdout.
# Usage: issue_new_sync "<title>" "<body_file>" "<labels_csv>"
issue_new_sync() {
  local title="${1:-}"
  local body_file="${2:-}"
  local labels_csv="${3:-}"

  # Validate arguments
  if [ -z "$title" ]; then
    echo "❌ Title is required" >&2
    echo "Usage: $0 create <title> <body_file> [labels_csv]" >&2
    return 1
  fi

  if [ -z "$body_file" ]; then
    echo "❌ Body file path is required" >&2
    echo "Usage: $0 create <title> <body_file> [labels_csv]" >&2
    return 1
  fi

  if [ ! -f "$body_file" ]; then
    echo "❌ Body file not found: $body_file" >&2
    return 1
  fi

  if [ ! -r "$body_file" ]; then
    echo "❌ Body file is not readable: $body_file" >&2
    return 1
  fi

  # Remote check — blocks writes to template repo
  check_remote

  # Get repo
  local REPO
  REPO=$(get_repo)

  # Build label list: split CSV + always append source:issue-new
  local -a labels=()
  if [ -n "$labels_csv" ]; then
    IFS=',' read -ra raw_labels <<< "$labels_csv"
    for lbl in "${raw_labels[@]}"; do
      lbl="${lbl## }"  # trim leading space
      lbl="${lbl%% }"  # trim trailing space
      [ -n "$lbl" ] && labels+=("$lbl")
    done
  fi
  labels+=("source:issue-new")

  # Attempt to create labels that don't exist yet (graceful fallback)
  for lbl in "${labels[@]}"; do
    gh label create "$lbl" --repo "$REPO" 2>/dev/null || true
  done

  # Build --label flags
  local label_flags=()
  for lbl in "${labels[@]}"; do
    label_flags+=("--label" "$lbl")
  done

  # Create the GitHub Issue
  local issue_url
  if ! issue_url=$(gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --body-file "$body_file" \
    "${label_flags[@]}" 2>&1); then
    echo "❌ Failed to create GitHub issue: $issue_url" >&2
    echo "Run: gh auth login" >&2
    return 1
  fi

  # Extract and print issue number from URL
  local issue_number
  issue_number=$(echo "$issue_url" | grep -o '[0-9]*$')
  echo "$issue_number"
}

# CLI interface
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    create)
      issue_new_sync "$@"
      ;;
    *)
      echo "Usage: $0 create <title> <body_file> [labels_csv]"
      exit 1
      ;;
  esac
fi
