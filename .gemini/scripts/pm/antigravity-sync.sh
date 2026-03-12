#!/usr/bin/env bash
# antigravity-sync.sh — Detect gaps and sync features from Gemini CLI to Antigravity IDE
# Usage:
#   bash scripts/pm/antigravity-sync.sh detect
#   bash scripts/pm/antigravity-sync.sh transform-workflow <source_file> [output_file]
#
# Reads config from config/antigravity-sync.json for mapping rules.

set -euo pipefail

_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"

CONFIG_FILE="$_CCPM_ROOT/config/antigravity-sync.json"

# Validate prerequisites
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config not found: config/antigravity-sync.json" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "❌ jq is required but not found" >&2
  exit 1
fi

# detect_gaps — Compare source vs target directories, output missing files grouped by type
# Reads mappings from config, applies naming conventions, filters skip_patterns
# Output format:
#   {type}: {count} missing
#   - {filename}
#   Total: {N} gaps ({M} workflows, {K} rules)
detect_gaps() {
  local skip_patterns
  skip_patterns=$(jq -r '.skip_patterns[]' "$CONFIG_FILE" 2>/dev/null)

  local mapping_types
  mapping_types=$(jq -r '.mappings | keys[]' "$CONFIG_FILE")

  local total_gaps=0
  local type_summaries=""

  for map_type in $mapping_types; do
    local source_dir target_dir naming
    source_dir=$(jq -r ".mappings[\"$map_type\"].source" "$CONFIG_FILE")
    target_dir=$(jq -r ".mappings[\"$map_type\"].target" "$CONFIG_FILE")
    naming=$(jq -r ".mappings[\"$map_type\"].naming" "$CONFIG_FILE")

    local source_path="$_CCPM_ROOT/$source_dir"
    local target_path="$_CCPM_ROOT/$target_dir"

    if [ ! -d "$source_path" ]; then
      echo "⚠️ Source directory not found: $source_dir" >&2
      continue
    fi

    local missing_files=()
    local outdated_files=()
    local missing_count=0
    local outdated_count=0

    for source_file in "$source_path"/*.md; do
      [ -f "$source_file" ] || continue

      local basename_no_ext
      basename_no_ext=$(basename "$source_file" .md)

      # Check skip_patterns
      local skip=false
      for pattern in $skip_patterns; do
        if [[ "$basename_no_ext" == *"$pattern"* ]]; then
          skip=true
          break
        fi
      done
      [ "$skip" = "true" ] && continue

      # Apply naming convention: replace {name} with basename
      local expected_target
      expected_target=$(echo "$naming" | sed "s/{name}/$basename_no_ext/")
      local target_file="$target_path/$expected_target"

      if [ ! -f "$target_file" ]; then
        missing_files+=("$expected_target")
        missing_count=$((missing_count + 1))
      elif _is_outdated "$map_type" "$source_file" "$target_file"; then
        outdated_files+=("$expected_target")
        outdated_count=$((outdated_count + 1))
      fi
    done

    local type_count=$((missing_count + outdated_count))

    if [ "$missing_count" -gt 0 ]; then
      echo "$map_type: $missing_count missing"
      for f in "${missing_files[@]}"; do
        echo "  - $f"
      done
      echo ""
    fi

    if [ "$outdated_count" -gt 0 ]; then
      echo "$map_type: $outdated_count outdated"
      for f in "${outdated_files[@]}"; do
        echo "  - $f"
      done
      echo ""
    fi

    total_gaps=$((total_gaps + type_count))

    if [ -n "$type_summaries" ]; then
      type_summaries="$type_summaries, $type_count $map_type"
    else
      type_summaries="$type_count $map_type"
    fi
  done

  echo "Total: $total_gaps gaps ($type_summaries)"
}

TIERS_FILE="$_CCPM_ROOT/config/model-tiers.json"

# _get_tier_for_cmd — Look up tier name (light/medium/heavy) for a command name
# Args: cmd_name
# Output: tier name to stdout, or empty string if not found
_get_tier_for_cmd() {
  local cmd_name="$1"
  if [ ! -f "$TIERS_FILE" ]; then
    echo ""
    return
  fi
  local tier
  tier=$(jq -r --arg cmd "$cmd_name" '.commands[$cmd] // empty' "$TIERS_FILE" 2>/dev/null || echo "")
  echo "$tier"
}

# _extract_description — Extract description from command body
# Tries first # heading, falls back to first non-empty content line
# Args: source_file
# Output: description string to stdout
_extract_description() {
  local source_file="$1"
  # Strip frontmatter (everything between first and second ---)
  local body
  body=$(awk '/^---/{c++;if(c==2){found=1;next}}found{print}' "$source_file")

  # Try first # heading
  local desc
  desc=$(echo "$body" | grep '^# ' | head -1 | sed 's/^# //')
  if [ -n "$desc" ]; then
    echo "$desc"
    return
  fi

  # Fall back to first non-empty line
  desc=$(echo "$body" | grep -v '^[[:space:]]*$' | head -1 | sed 's/^[[:space:]]*//')
  echo "${desc:-$(basename "$source_file" .md)}"
}

# _get_variable_for_cmd — Determine variable replacement for $ARGUMENTS based on command name
# Args: cmd_name
# Output: variable string (e.g. "$EPIC_NAME") to stdout
_get_variable_for_cmd() {
  local cmd_name="$1"
  # Match patterns from config variable_map
  if [[ "$cmd_name" == epic-* ]]; then
    echo '$EPIC_NAME'
  elif [[ "$cmd_name" == issue-* ]]; then
    echo '$ISSUE_NUMBER'
  elif [[ "$cmd_name" == prd-* ]]; then
    echo '$FEATURE_NAME'
  else
    # Default: keep $ARGUMENTS
    echo '$ARGUMENTS'
  fi
}

# transform_workflow — Transform a Gemini CLI command file to Antigravity workflow format
# Args: source_file [output_file]
#   source_file: path to commands/pm/*.md
#   output_file: (optional) explicit output path; if omitted, writes to antigravity/workflows/pm-{name}.md
# Transform:
#   - Remove model: and allowed-tools: frontmatter fields
#   - Add name: pm-{cmd} and description: fields
#   - Insert # tier: {tier} comment from model-tiers.json
#   - Replace $ARGUMENTS with context-specific variable per variable_map
transform_workflow() {
  local source_file="$1"
  local output_file="${2:-}"

  if [ ! -f "$source_file" ]; then
    echo "❌ Source file not found: $source_file" >&2
    return 1
  fi

  local cmd_name
  cmd_name=$(basename "$source_file" .md)

  # Determine output path
  if [ -z "$output_file" ]; then
    output_file="$_CCPM_ROOT/antigravity/workflows/pm-${cmd_name}.md"
    mkdir -p "$(dirname "$output_file")"
  fi

  # Get tier for this command
  local tier
  tier=$(_get_tier_for_cmd "$cmd_name")

  # Get description
  local description
  description=$(_extract_description "$source_file")

  # Get variable replacement
  local var_replace
  var_replace=$(_get_variable_for_cmd "$cmd_name")

  # Build new frontmatter
  {
    echo "---"
    echo "name: pm-${cmd_name}"
    echo "description: ${description}"
    if [ -n "$tier" ]; then
      echo "# tier: ${tier}"
    fi
    echo "---"
  } > "$output_file"

  # Extract body (after second ---) and apply variable replacement
  awk '/^---/{c++;if(c==2){found=1;next}}found{print}' "$source_file" \
    | sed "s/\\\$ARGUMENTS/${var_replace//\$/\\$}/g" \
    >> "$output_file"

  echo "✅ Transformed: pm-${cmd_name}.md → $(basename "$output_file")"
}

# _is_outdated — Check if target file is outdated compared to source
# For rules: direct diff. For workflows: diff against transformed output.
# Args: map_type source_file target_file
# Returns: 0 if outdated, 1 if up-to-date
_is_outdated() {
  local map_type="$1" source_file="$2" target_file="$3"
  local transform
  transform=$(jq -r ".mappings[\"$map_type\"].transform // \"workflow\"" "$CONFIG_FILE" 2>/dev/null)

  if [ "$transform" = "rule" ]; then
    ! diff -q "$source_file" "$target_file" > /dev/null 2>&1
  else
    local tmp_file
    tmp_file=$(mktemp "${TMPDIR:-/tmp}/ag-sync-XXXXXX.md")
    transform_workflow "$source_file" "$tmp_file" > /dev/null 2>&1
    local rc=1
    diff -q "$tmp_file" "$target_file" > /dev/null 2>&1 || rc=0
    rm -f "$tmp_file"
    return $rc
  fi
}

# transform_rule — Copy a rules/*.md file to antigravity/rules/ccpm-{name}.md
# Preserves content byte-for-byte. Skips if target already identical.
# Args: source_file [output_file]
#   source_file: path to rules/*.md
#   output_file: (optional) explicit output path; if omitted, writes to antigravity/rules/ccpm-{name}.md
transform_rule() {
  local source_file="$1"
  local output_file="${2:-}"

  if [ ! -f "$source_file" ]; then
    echo "❌ Source file not found: $source_file" >&2
    return 1
  fi

  local rule_name
  rule_name=$(basename "$source_file" .md)

  # Determine output path
  if [ -z "$output_file" ]; then
    output_file="$_CCPM_ROOT/antigravity/rules/ccpm-${rule_name}.md"
    mkdir -p "$(dirname "$output_file")"
  fi

  # Skip if target already exists and is identical
  if [ -f "$output_file" ] && diff -q "$source_file" "$output_file" > /dev/null 2>&1; then
    echo "⏭️ Skipped (identical): ccpm-${rule_name}.md"
    return 0
  fi

  cp "$source_file" "$output_file"
  echo "✅ Transformed: ccpm-${rule_name}.md"
}

# _list_gaps — Internal: output gap list as pipe-delimited lines for machine processing
# Output format: {map_type}|{source_file}|{target_file}|{gap_type}
_list_gaps() {
  local skip_patterns
  skip_patterns=$(jq -r '.skip_patterns[]' "$CONFIG_FILE" 2>/dev/null)
  local mapping_types
  mapping_types=$(jq -r '.mappings | keys[]' "$CONFIG_FILE")

  for map_type in $mapping_types; do
    local source_dir target_dir naming
    source_dir=$(jq -r ".mappings[\"$map_type\"].source" "$CONFIG_FILE")
    target_dir=$(jq -r ".mappings[\"$map_type\"].target" "$CONFIG_FILE")
    naming=$(jq -r ".mappings[\"$map_type\"].naming" "$CONFIG_FILE")

    local source_path="$_CCPM_ROOT/$source_dir"
    local target_path="$_CCPM_ROOT/$target_dir"
    [ -d "$source_path" ] || continue

    for source_file in "$source_path"/*.md; do
      [ -f "$source_file" ] || continue
      local basename_no_ext
      basename_no_ext=$(basename "$source_file" .md)

      local skip=false
      for pattern in $skip_patterns; do
        [[ "$basename_no_ext" == *"$pattern"* ]] && skip=true && break
      done
      [ "$skip" = "true" ] && continue

      local expected_target
      expected_target=$(echo "$naming" | sed "s/{name}/$basename_no_ext/")
      local target_file="$target_path/$expected_target"

      if [ ! -f "$target_file" ]; then
        echo "${map_type}|${source_file}|${target_file}|missing"
      elif _is_outdated "$map_type" "$source_file" "$target_file"; then
        echo "${map_type}|${source_file}|${target_file}|outdated"
      fi
    done
  done
}

# sync_type — Filter gap list by type (workflows|rules|all)
# Used internally by sync_all and sync subcommand
# Args: type_filter
# Output: filtered pipe-delimited gap lines
sync_type() {
  local type_filter="${1:-all}"
  if [ "$type_filter" = "all" ]; then
    _list_gaps
  else
    _list_gaps | grep "^${type_filter}|" || true
  fi
}

# sync_all — Main sync orchestrator
# Args: [--type workflows|rules|all] [--yes]
# Detect gaps → confirm → transform → report
sync_all() {
  local type_filter="all"
  local auto_yes=false

  # Parse args
  while [ $# -gt 0 ]; do
    case "$1" in
      --type) type_filter="${2:-all}"; shift 2 ;;
      --yes|-y) auto_yes=true; shift ;;
      *) shift ;;
    esac
  done

  # Get gap list
  local gap_lines
  gap_lines=$(sync_type "$type_filter")

  local total_gaps=0
  if [ -n "$gap_lines" ]; then
    total_gaps=$(echo "$gap_lines" | grep -c '|' 2>/dev/null || true)
    [ -z "$total_gaps" ] && total_gaps=0
  fi

  if [ "$total_gaps" -eq 0 ]; then
    echo "✅ Already in sync — 0 gaps found."
  fi

  if [ "$total_gaps" -gt 0 ]; then
  # Display planned changes
  echo "📋 Files to sync (${total_gaps} gaps):"
  echo "$gap_lines" | while IFS='|' read -r map_type src_file tgt_file gap_type; do
    echo "  [${map_type}] $(basename "$tgt_file") (${gap_type})"
  done
  echo ""

  # Confirm prompt (skip if --yes or non-interactive)
  if [ "$auto_yes" = "false" ] && [ -t 0 ]; then
    printf "Proceed with sync? [y/N] "
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      echo "❌ Aborted — no files written."
      return 0
    fi
  fi

  # Track results
  local created=0 skipped=0 failed=0
  local backup_dir=""

  echo ""
  echo "$gap_lines" | while IFS='|' read -r map_type src_file tgt_file gap_type; do
    local tgt_name
    tgt_name=$(basename "$tgt_file")
    mkdir -p "$(dirname "$tgt_file")"

    # Backup if target exists with different content
    if [ -f "$tgt_file" ] && ! diff -q "$src_file" "$tgt_file" > /dev/null 2>&1; then
      if [ -z "$backup_dir" ]; then
        backup_dir="$_CCPM_ROOT/.antigravity-backup/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
      fi
      cp "$tgt_file" "$backup_dir/$(basename "$tgt_file")"
    fi

    # Transform based on type from config
    local transform
    transform=$(jq -r ".mappings[\"$map_type\"].transform // \"workflow\"" "$CONFIG_FILE" 2>/dev/null)
    if [ "$transform" = "workflow" ]; then
      if transform_workflow "$src_file" "$tgt_file" 2>/dev/null; then
        echo "  ✅ Synced (${gap_type}): $tgt_name"
        # Note: can't increment in subshell
      else
        echo "  ❌ Failed: $tgt_name"
      fi
    elif [ "$transform" = "rule" ]; then
      if transform_rule "$src_file" "$tgt_file" 2>/dev/null; then
        echo "  ✅ Synced (${gap_type}): $tgt_name"
      else
        echo "  ❌ Failed: $tgt_name"
      fi
    fi
  done

  # Summary (recount from output)
  echo ""
  local report
  report=$(echo "$gap_lines" | while IFS='|' read -r map_type src_file tgt_file gap_type; do
    mkdir -p "$(dirname "$tgt_file")" 2>/dev/null
    local transform
    transform=$(jq -r ".mappings[\"$map_type\"].transform // \"workflow\"" "$CONFIG_FILE" 2>/dev/null)
    if [ "$transform" = "workflow" ]; then
      transform_workflow "$src_file" "$tgt_file" > /dev/null 2>&1 && echo "ok" || echo "fail"
    elif [ "$transform" = "rule" ]; then
      transform_rule "$src_file" "$tgt_file" > /dev/null 2>&1 && echo "ok" || echo "fail"
    fi
  done)

  created=$(echo "$report" | grep -c "^ok$" || true)
  failed=$(echo "$report" | grep -c "^fail$" || true)

  echo "Sync complete: ${created} created, ${skipped} skipped, ${failed} failed"
  if [ -n "$backup_dir" ]; then
    echo "Backups: $backup_dir"
  fi
  fi # end if total_gaps > 0

  # --- Root antigravity/ sync (dogfooding case) ---
  local project_root
  project_root=$(cd "$_CCPM_ROOT/.." && pwd)
  if [ -d "$project_root/antigravity" ]; then
    echo ""
    echo "Syncing to root antigravity/..."
    local root_synced=0

    # Copy workflows and rules from .gemini/antigravity/ to root antigravity/
    for sync_dir in workflows rules; do
      local src="$_CCPM_ROOT/antigravity/$sync_dir"
      local dst="$project_root/antigravity/$sync_dir"
      [ -d "$src" ] || continue
      mkdir -p "$dst"
      cp -Rf "$src/." "$dst/"

      # Remove stale files: target files with no corresponding source
      for target_file in "$dst"/*.md; do
        [ -f "$target_file" ] || continue
        local target_basename
        target_basename=$(basename "$target_file")
        if [ ! -f "$src/$target_basename" ]; then
          rm "$target_file"
          echo "  🗑️ Removed stale: $sync_dir/$target_basename"
        fi
      done
    done

    root_synced=$(find "$_CCPM_ROOT/antigravity/workflows" "$_CCPM_ROOT/antigravity/rules" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "✅ Root antigravity/ also updated (${root_synced} files)"
  fi
}

# CLI entry point
case "${1:-}" in
  detect)
    detect_gaps
    ;;
  transform-workflow)
    [ -z "${2:-}" ] && { echo "❌ Usage: antigravity-sync.sh transform-workflow <source_file> [output_file]" >&2; exit 1; }
    transform_workflow "${2}" "${3:-}"
    ;;
  transform-rule)
    [ -z "${2:-}" ] && { echo "❌ Usage: antigravity-sync.sh transform-rule <source_file> [output_file]" >&2; exit 1; }
    transform_rule "${2}" "${3:-}"
    ;;
  sync)
    shift
    sync_all "$@"
    ;;
  *)
    echo "Usage: bash scripts/pm/antigravity-sync.sh <detect|transform-workflow|transform-rule|sync>" >&2
    exit 1
    ;;
esac
