#!/usr/bin/env bash
# upstream-sync.sh — Fetch and categorize changes from upstream automazeio/ccpm
# Usage:
#   bash scripts/pm/upstream-sync.sh --summary
#   bash scripts/pm/upstream-sync.sh --apply <category> [<file>...]
#   bash scripts/pm/upstream-sync.sh --update-log <upstream_commit> <accepted_categories> <rejected_categories>
#
# Cross-reference: see scripts/pm/antigravity-sync.sh for similar sync pattern (AD-6)

set -euo pipefail

_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"

UPSTREAM_REMOTE="upstream-ccpm"
UPSTREAM_URL="https://github.com/automazeio/ccpm.git"
SYNC_LOG="${SYNC_LOG:-.claude/context/upstream-sync-log.md}"

# _resolve_log — Return absolute path to sync log
_resolve_log() {
  if [[ "$SYNC_LOG" = /* ]]; then
    echo "$SYNC_LOG"
  else
    echo "$_CCPM_ROOT/$SYNC_LOG"
  fi
}

# setup_remote — Add upstream remote if not present, fetch main branch
setup_remote() {
  if ! git -C "$_CCPM_ROOT" remote get-url "$UPSTREAM_REMOTE" &>/dev/null; then
    git -C "$_CCPM_ROOT" remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
  fi
  git -C "$_CCPM_ROOT" fetch "$UPSTREAM_REMOTE" main 2>/dev/null || {
    echo "❌ Cannot reach automazeio/ccpm. Check network."
    exit 1
  }
}

# get_last_sync — Return the last synced upstream commit hash, or empty string on first sync
get_last_sync() {
  local log_path
  log_path=$(_resolve_log)
  if [ -f "$log_path" ]; then
    grep -m1 "^commit:" "$log_path" | awk '{print $2}' || echo ""
  else
    echo ""
  fi
}

# get_diff_base — Determine the base commit for diffing
# If last sync recorded, use that commit. Otherwise use merge-base.
get_diff_base() {
  local last_commit
  last_commit=$(get_last_sync)
  if [ -n "$last_commit" ]; then
    echo "$last_commit"
  else
    git -C "$_CCPM_ROOT" merge-base HEAD "${UPSTREAM_REMOTE}/main" 2>/dev/null || \
      git -C "$_CCPM_ROOT" rev-list --max-parents=0 "${UPSTREAM_REMOTE}/main" | head -1
  fi
}

# categorize_changes — Categorize diff output by directory
# Output format: category|status|file
categorize_changes() {
  local base="$1"
  git -C "$_CCPM_ROOT" diff --name-status "$base" "${UPSTREAM_REMOTE}/main" 2>/dev/null | \
  while IFS=$'\t' read -r status file; do
    case "$file" in
      scripts/pm/*)   echo "scripts|$status|$file" ;;
      commands/pm/*)  echo "commands|$status|$file" ;;
      rules/*)        echo "rules|$status|$file" ;;
      config/*)       echo "config|$status|$file" ;;
      CLAUDE.md)      echo "breaking|$status|$file" ;;
      hooks/*)        echo "breaking|$status|$file" ;;
      *)              echo "other|$status|$file" ;;
    esac
  done
}

# is_breaking — Heuristic: flag as breaking if it's a schema or hook change
is_breaking() {
  local file="$1"
  case "$file" in
    config/*.json|hooks/*) return 0 ;;
    *) return 1 ;;
  esac
}

# output_summary — Print categorized summary to stdout
# Prints structured text for the prompt command to consume
output_summary() {
  local base="$1"
  local changes
  changes=$(categorize_changes "$base")

  if [ -z "$changes" ]; then
    echo "UP_TO_DATE"
    return
  fi

  # Group by category
  local categories="scripts commands rules config breaking other"
  for cat in $categories; do
    local cat_lines
    cat_lines=$(echo "$changes" | grep "^${cat}|" || true)
    [ -z "$cat_lines" ] && continue

    local count
    count=$(echo "$cat_lines" | wc -l | tr -d ' ')
    echo "CATEGORY:${cat}:${count}"

    echo "$cat_lines" | while IFS='|' read -r _ status file; do
      echo "  FILE:${status}:${file}"
    done
  done

  # Print upstream HEAD commit
  local upstream_commit
  upstream_commit=$(git -C "$_CCPM_ROOT" rev-parse "${UPSTREAM_REMOTE}/main")
  echo "UPSTREAM_COMMIT:${upstream_commit}"
}

# apply_file — Checkout a single file from upstream remote
# Args: file_path
apply_file() {
  local file="$1"
  local dir
  dir=$(dirname "$_CCPM_ROOT/$file")
  mkdir -p "$dir"
  git -C "$_CCPM_ROOT" checkout "${UPSTREAM_REMOTE}/main" -- "$file"
  echo "✅ Applied: $file"
}

# apply_category — Apply all files in a given category from the diff
# Args: category base_commit
apply_category() {
  local category="$1"
  local base="$2"
  local changes
  changes=$(categorize_changes "$base")
  local cat_lines
  cat_lines=$(echo "$changes" | grep "^${category}|" || true)

  if [ -z "$cat_lines" ]; then
    echo "No changes in category: $category"
    return
  fi

  echo "$cat_lines" | while IFS='|' read -r _ status file; do
    if [ "$status" = "D" ]; then
      # Deleted upstream — skip, let user decide manually
      echo "⚠️ Skipped (upstream deletion): $file"
    else
      apply_file "$file"
    fi
  done
}

# update_sync_log — Append a sync entry to the sync log
# Args: upstream_commit accepted_categories rejected_categories
update_sync_log() {
  local upstream_commit="$1"
  local accepted="$2"
  local rejected="$3"
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local log_path
  log_path=$(_resolve_log)

  mkdir -p "$(dirname "$log_path")"

  # Build table rows
  local rows=""
  for cat in $accepted; do
    rows="${rows}| ${cat} | accepted | — |\n"
  done
  for cat in $rejected; do
    rows="${rows}| ${cat} | rejected | — |\n"
  done

  local entry
  entry=$(printf "## Sync: %s\ncommit: %s\n\n| Category | Action | Files |\n|----------|--------|-------|\n%s\n" \
    "$now" "$upstream_commit" "$rows")

  if [ -f "$log_path" ]; then
    # Prepend new entry after any header line
    local tmp
    tmp=$(mktemp)
    {
      echo "$entry"
      cat "$log_path"
    } > "$tmp"
    mv "$tmp" "$log_path"
  else
    {
      echo "# Upstream Sync Log"
      echo ""
      echo "$entry"
    } > "$log_path"
  fi

  echo "✅ Sync log updated: $SYNC_LOG"
}

# get_diff_for_file — Show diff for a single file vs upstream
get_diff_for_file() {
  local base="$1"
  local file="$2"
  git -C "$_CCPM_ROOT" diff "$base" "${UPSTREAM_REMOTE}/main" -- "$file" 2>/dev/null || true
}

# CLI entry point
case "${1:-}" in
  --summary)
    setup_remote
    base=$(get_diff_base)
    output_summary "$base"
    ;;
  --base)
    # Helper: just print the diff base commit
    setup_remote
    get_diff_base
    ;;
  --apply-category)
    [ -z "${2:-}" ] && { echo "❌ Usage: upstream-sync.sh --apply-category <category> <base_commit>" >&2; exit 1; }
    apply_category "${2}" "${3:-$(get_diff_base)}"
    ;;
  --apply-file)
    [ -z "${2:-}" ] && { echo "❌ Usage: upstream-sync.sh --apply-file <file>" >&2; exit 1; }
    apply_file "${2}"
    ;;
  --diff-file)
    [ -z "${2:-}" ] && { echo "❌ Usage: upstream-sync.sh --diff-file <base_commit> <file>" >&2; exit 1; }
    get_diff_for_file "${2}" "${3:-}"
    ;;
  --update-log)
    [ -z "${2:-}" ] && { echo "❌ Usage: upstream-sync.sh --update-log <commit> <accepted> <rejected>" >&2; exit 1; }
    update_sync_log "${2}" "${3:-}" "${4:-}"
    ;;
  *)
    echo "Usage: bash scripts/pm/upstream-sync.sh <--summary|--base|--apply-category|--apply-file|--diff-file|--update-log>" >&2
    exit 1
    ;;
esac
