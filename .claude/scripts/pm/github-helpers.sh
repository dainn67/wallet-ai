#!/usr/bin/env bash
# GitHub helper functions for CCPM commands.
# Usage:
#   bash .claude/scripts/pm/github-helpers.sh <command> [args...]
#
# Commands:
#   check-remote              - Verify remote is not the CCPM template repo
#   get-repo                  - Print OWNER/REPO from git remote origin
#   get-repo-for-issue <num>  - Smart repo detection: epic config → mapping → git remote
#   strip-frontmatter         - Remove YAML frontmatter from a file
#
# Or source in another script:
#   source .claude/scripts/pm/github-helpers.sh
#   check_remote
#   REPO=$(get_repo)
#   REPO=$(get_repo_for_issue 42)
#   strip_frontmatter input.md output.md

set -euo pipefail

# Check remote is not the CCPM template repo. Exits 1 if it is.
check_remote() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ "$remote_url" == *"automazeio/ccpm"* ]]; then
    echo "❌ Remote points to CCPM template repo. Update your remote origin first."
    exit 1
  fi
  if [ -z "$remote_url" ]; then
    echo "❌ No git remote origin found."
    exit 1
  fi
}

# Print OWNER/REPO from git remote origin. Exits 1 if not detected.
get_repo() {
  local remote_url repo
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  repo=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
  if [ -z "$repo" ]; then
    echo "❌ Cannot detect GitHub repo from remote origin." >&2
    exit 1
  fi
  echo "$repo"
}

# Extract OWNER/REPO from a GitHub URL.
# Usage: _extract_repo_from_url "https://github.com/owner/repo/issues/1"
# Output: owner/repo
_extract_repo_from_url() {
  echo "$1" | sed 's|https://github.com/||' | sed 's|/issues/.*||' | sed 's|/pull/.*||'
}

# Smart repo detection: tries epic config, github-mapping, then git remote.
# Usage: get_repo_for_issue [issue_number]
# Output: OWNER/REPO (e.g., "abc-elearning/alive-unified")
get_repo_for_issue() {
  local issue_number="${1:-}"
  local repo=""

  # Strategy 1: Find epic containing this issue, read github: from epic.md
  if [ -n "$issue_number" ]; then
    for epic_dir in .claude/epics/*/; do
      [ -d "$epic_dir" ] || continue
      if [ -f "$epic_dir/${issue_number}.md" ]; then
        # Try epic's github field
        if [ -f "$epic_dir/epic.md" ]; then
          local github_url
          github_url=$(grep '^github:' "$epic_dir/epic.md" 2>/dev/null | head -1 | sed 's/^github: *//')
          if [ -n "$github_url" ]; then
            repo=$(_extract_repo_from_url "$github_url")
          fi
        fi
        # Or try task's github field
        if [ -z "$repo" ]; then
          local task_github
          task_github=$(grep '^github:' "$epic_dir/${issue_number}.md" 2>/dev/null | head -1 | sed 's/^github: *//')
          if [ -n "$task_github" ]; then
            repo=$(_extract_repo_from_url "$task_github")
          fi
        fi
        # Or try github-mapping.md
        if [ -z "$repo" ] && [ -f "$epic_dir/github-mapping.md" ]; then
          local mapping_url
          mapping_url=$(grep -oE 'https://github.com/[^/]+/[^/]+' "$epic_dir/github-mapping.md" 2>/dev/null | head -1)
          if [ -n "$mapping_url" ]; then
            repo=$(_extract_repo_from_url "$mapping_url")
          fi
        fi
        break
      fi
    done
  fi

  # Strategy 2: If no match yet, try any epic's github field
  if [ -z "$repo" ]; then
    for epic_dir in .claude/epics/*/; do
      [ -d "$epic_dir" ] || continue
      if [ -f "$epic_dir/epic.md" ]; then
        local github_url
        github_url=$(grep '^github:' "$epic_dir/epic.md" 2>/dev/null | head -1 | sed 's/^github: *//')
        if [ -n "$github_url" ]; then
          repo=$(_extract_repo_from_url "$github_url")
          break
        fi
      fi
    done
  fi

  # Strategy 3: git remote origin
  if [ -z "$repo" ]; then
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    repo=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
  fi

  if [ -z "$repo" ]; then
    echo "❌ Cannot detect GitHub repo. Add github: field to epic or init a git repo." >&2
    return 1
  fi
  echo "$repo"
}

# Strip YAML frontmatter from a markdown file.
# Usage: strip_frontmatter input.md [output.md]
# If no output file, prints to stdout.
strip_frontmatter() {
  local input="${1:?Usage: strip_frontmatter input.md [output.md]}"
  local output="${2:-}"
  if [ -n "$output" ]; then
    sed '1,/^---$/d; 1,/^---$/d' "$input" > "$output"
  else
    sed '1,/^---$/d; 1,/^---$/d' "$input"
  fi
}

# CLI interface - run commands directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    check-remote)         check_remote ;;
    get-repo)             get_repo ;;
    get-repo-for-issue)   get_repo_for_issue "$@" ;;
    strip-frontmatter)    strip_frontmatter "$@" ;;
    *)
      echo "Usage: $0 <check-remote|get-repo|get-repo-for-issue|strip-frontmatter> [args...]"
      exit 1
      ;;
  esac
fi
