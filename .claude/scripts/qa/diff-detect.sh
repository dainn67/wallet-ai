#!/bin/bash
# Diff-Aware Screen Detection — maps git diff to QA scenario screens
# AD-3: Shell Wrapper Convention as Adapter Interface
# Usage: source this file and call the functions
set -euo pipefail

# Source JSON helper from axe-wrapper.sh (same directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/qa/axe-wrapper.sh
source "$SCRIPT_DIR/axe-wrapper.sh"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _is_screen_file <basename_no_ext>
# Returns 0 (true) if the file is likely a screen, 1 (false) if it should be skipped.
_is_screen_file() {
  local name="$1"
  # Skip non-screen patterns: AppDelegate, SceneDelegate, *Model, *Service,
  # *Manager, *Helper, *Coordinator, *Router, *Repository, *Extension, *Protocol
  case "$name" in
    AppDelegate|SceneDelegate|*Model|*Service|*Manager|*Helper|*Coordinator|*Router|*Repository|*Extension|*Protocol)
      return 1
      ;;
  esac
  return 0
}

# _extract_screen_name <swift_basename_no_ext>
# Strips common non-screen suffixes and normalizes to screen name.
# Outputs the screen name, or empty string if it should be skipped.
_extract_screen_name() {
  local name="$1"

  # Skip non-screen files first
  if ! _is_screen_file "$name"; then
    printf ''
    return 0
  fi

  # Strip common controller/VC suffixes, ensure "View" suffix
  case "$name" in
    *ViewController)
      # QuizViewController → QuizView
      printf '%sView' "${name%ViewController}"
      ;;
    *Controller)
      # QuizController → QuizView
      printf '%sView' "${name%Controller}"
      ;;
    *VC)
      # QuizVC → QuizView
      printf '%sView' "${name%VC}"
      ;;
    *View)
      # QuizView → QuizView (already correct)
      printf '%s' "$name"
      ;;
    *)
      # Unknown suffix — conservative: include as-is (Dashboard → Dashboard)
      printf '%s' "$name"
      ;;
  esac
}

# _parse_storyboard_screens <storyboard_path>
# Parses XML to find viewController customClass attributes.
# Outputs one screen name per line.
_parse_storyboard_screens() {
  local storyboard="$1"

  # Extract customClass attributes from viewController elements
  # XML pattern: <viewController ... customClass="QuizViewController" ...>
  # Use grep + sed — portable approach (no xmllint required)
  grep -oE 'customClass="[^"]+"' "$storyboard" 2>/dev/null \
    | sed 's/customClass="//;s/"//' \
    | while IFS= read -r class_name; do
        local screen
        screen=$(_extract_screen_name "$class_name")
        [ -n "$screen" ] && printf '%s\n' "$screen"
      done || true
}

# _build_screens_json <screen1> <screen2> ...
# Builds a JSON array string from argument list.
_build_screens_json() {
  local first=true
  printf '['
  for s in "$@"; do
    if $first; then
      printf '"%s"' "$s"
      first=false
    else
      printf ',"%s"' "$s"
    fi
  done
  printf ']'
}

# ---------------------------------------------------------------------------
# Public functions
# ---------------------------------------------------------------------------

# detect_affected_screens
# Reads git diff, maps changed Swift/Storyboard files to screen names.
# Returns: {"success": true, "data": {"screens": [...], "source_files": [...]}}
#          or fallback variant if no screens detected
detect_affected_screens() {
  local diff_files source_files=()
  local all_screens=()

  # Guard: not a git repo
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    local fallback_data
    fallback_data='{"screens":[],"source_files":[],"fallback":"not_a_git_repo"}'
    _json_response true null "$fallback_data"
    return 0
  fi

  # Get changed files: staged + unstaged + untracked (porcelain covers all)
  # Use HEAD diff for tracked files plus git status for untracked new files
  diff_files=$(git diff --name-only HEAD 2>/dev/null || true)
  # Also capture staged changes not yet in HEAD diff
  local staged_files
  staged_files=$(git diff --cached --name-only 2>/dev/null || true)
  # Combine, deduplicate
  local all_changed
  all_changed=$(printf '%s\n%s' "$diff_files" "$staged_files" | sort -u | grep -v '^$' || true)

  if [ -z "$all_changed" ]; then
    local fallback_data
    fallback_data='{"screens":[],"source_files":[],"fallback":"clean_working_tree"}'
    _json_response true null "$fallback_data"
    return 0
  fi

  # Process changed files
  local has_screen_files=false
  while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    local filename ext basename_no_ext
    filename="${filepath##*/}"
    ext="${filename##*.}"

    case "$ext" in
      swift)
        basename_no_ext="${filename%.swift}"
        local screen
        screen=$(_extract_screen_name "$basename_no_ext")
        if [ -n "$screen" ]; then
          all_screens+=("$screen")
          source_files+=("$filepath")
          has_screen_files=true
        fi
        ;;
      storyboard)
        if [ -f "$filepath" ]; then
          source_files+=("$filepath")
          has_screen_files=true
          while IFS= read -r screen; do
            [ -n "$screen" ] && all_screens+=("$screen")
          done < <(_parse_storyboard_screens "$filepath")
        else
          # File listed in diff but not on disk (deleted) — still note it
          source_files+=("$filepath")
          has_screen_files=true
        fi
        ;;
    esac
  done <<< "$all_changed"

  if ! $has_screen_files || [ ${#all_screens[@]} -eq 0 ]; then
    local fallback_data
    fallback_data='{"screens":[],"source_files":[],"fallback":"no_screen_files_changed"}'
    _json_response true null "$fallback_data"
    return 0
  fi

  # Deduplicate screen names (portable: use sort + uniq via printf)
  local unique_screens=()
  while IFS= read -r s; do
    [ -n "$s" ] && unique_screens+=("$s")
  done < <(printf '%s\n' "${all_screens[@]}" | sort -u)

  local screens_json src_json
  screens_json=$(_build_screens_json "${unique_screens[@]}")

  # Build source_files JSON array
  local first=true
  src_json='['
  for f in "${source_files[@]}"; do
    if $first; then
      src_json+="\"$f\""
      first=false
    else
      src_json+=",\"$f\""
    fi
  done
  src_json+=']'

  local data
  data="{\"screens\":${screens_json},\"source_files\":${src_json}}"
  _json_response true null "$data"
}

# filter_scenarios <screens_json_output>
# Filters .claude/qa/scenarios/*.md to those matching given screens.
# screens_json_output: full JSON from detect_affected_screens
# Returns: {"success": true, "data": {"scenarios": [...], "total": N, "filtered": M}}
filter_scenarios() {
  local screens_output="$1"
  local scenario_dir=".claude/qa/scenarios"

  # Validate input
  if [ -z "$screens_output" ]; then
    _json_response false "screens_output argument is required" null
    return 0
  fi

  # Check for fallback key — means no screens detected, return all scenarios
  local has_fallback screens_array
  has_fallback=$(printf '%s' "$screens_output" | grep -o '"fallback"' || true)

  # Get total scenario count
  local all_scenarios=()
  if [ -d "$scenario_dir" ]; then
    while IFS= read -r f; do
      all_scenarios+=("$f")
    done < <(ls "$scenario_dir"/*.md 2>/dev/null || true)
  fi
  local total=${#all_scenarios[@]}

  if [ "$total" -eq 0 ]; then
    _json_response true null '{"scenarios":[],"total":0,"filtered":0}'
    return 0
  fi

  # If fallback present or screens array empty → return all scenarios
  if [ -n "$has_fallback" ]; then
    local all_json
    all_json=$(printf '"%s",' "${all_scenarios[@]}" | sed 's/,$//')
    local data="{\"scenarios\":[$all_json],\"total\":$total,\"filtered\":$total,\"fallback\":true}"
    _json_response true null "$data"
    return 0
  fi

  # Check if screens array is empty: "screens":[]
  local screens_empty
  screens_empty=$(printf '%s' "$screens_output" | grep -o '"screens":\[\]' || true)
  if [ -n "$screens_empty" ]; then
    local all_json
    all_json=$(printf '"%s",' "${all_scenarios[@]}" | sed 's/,$//')
    local data="{\"scenarios\":[$all_json],\"total\":$total,\"filtered\":$total,\"fallback\":true}"
    _json_response true null "$data"
    return 0
  fi

  # Extract screens list from JSON (simple parsing without jq dependency)
  # e.g., "screens":["QuizView","SettingsView"]
  screens_array=$(printf '%s' "$screens_output" \
    | grep -oE '"screens":\["[^]]*"\]' \
    | sed 's/"screens":\[//;s/\]//' \
    | tr ',' '\n' \
    | sed 's/"//g' \
    | grep -v '^$' || true)

  if [ -z "$screens_array" ]; then
    # No screens could be parsed — conservative fallback: return all
    local all_json
    all_json=$(printf '"%s",' "${all_scenarios[@]}" | sed 's/,$//')
    local data="{\"scenarios\":[$all_json],\"total\":$total,\"filtered\":$total,\"fallback\":true}"
    _json_response true null "$data"
    return 0
  fi

  # Filter scenarios by matching frontmatter `screens:` field
  local matched_scenarios=()
  for scenario_file in "${all_scenarios[@]}"; do
    # Extract screens field from frontmatter: screens: [QuizView, ResultView]
    local scenario_screens
    scenario_screens=$(grep -m1 '^screens:' "$scenario_file" 2>/dev/null \
      | sed 's/screens: *\[//;s/\]//' \
      | tr ',' '\n' \
      | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
      | grep -v '^$' || true)

    if [ -z "$scenario_screens" ]; then
      continue
    fi

    # Check if any detected screen matches any scenario screen
    local matched=false
    while IFS= read -r detected_screen; do
      [ -z "$detected_screen" ] && continue
      while IFS= read -r scenario_screen; do
        [ -z "$scenario_screen" ] && continue
        if [ "$detected_screen" = "$scenario_screen" ]; then
          matched=true
          break 2
        fi
      done <<< "$scenario_screens"
    done <<< "$screens_array"

    $matched && matched_scenarios+=("$scenario_file")
  done

  local filtered=${#matched_scenarios[@]}

  # Conservative fallback: if nothing matched, return all scenarios
  if [ "$filtered" -eq 0 ]; then
    local all_json
    all_json=$(printf '"%s",' "${all_scenarios[@]}" | sed 's/,$//')
    local data="{\"scenarios\":[$all_json],\"total\":$total,\"filtered\":$total,\"fallback\":true}"
    _json_response true null "$data"
    return 0
  fi

  local matched_json
  matched_json=$(printf '"%s",' "${matched_scenarios[@]}" | sed 's/,$//')
  local data="{\"scenarios\":[$matched_json],\"total\":$total,\"filtered\":$filtered}"
  _json_response true null "$data"
}

# detect_and_filter
# Convenience function: detect affected screens then filter scenarios.
# Returns combined result with both screen mapping and filtered scenario list.
detect_and_filter() {
  local screens_result
  screens_result=$(detect_affected_screens)

  local filter_result
  filter_result=$(filter_scenarios "$screens_result")

  # Combine into single response
  local screens_data filter_data
  screens_data=$(printf '%s' "$screens_result" | grep -oE '"data":\{[^}]+\}' | sed 's/"data"://' || echo '{}')
  filter_data=$(printf '%s' "$filter_result" | grep -oE '"data":\{.*\}' | sed 's/"data"://' || echo '{}')

  # Check if both succeeded
  local s1 s2
  s1=$(printf '%s' "$screens_result" | grep -oE '"success":(true|false)' | head -1 | grep -oE 'true|false')
  s2=$(printf '%s' "$filter_result" | grep -oE '"success":(true|false)' | head -1 | grep -oE 'true|false')

  if [ "$s1" != "true" ]; then
    printf '%s\n' "$screens_result"
    return 0
  fi
  if [ "$s2" != "true" ]; then
    printf '%s\n' "$filter_result"
    return 0
  fi

  # Build combined data — merge both data objects
  local combined_data
  # Extract inner content of each data object (strip outer {})
  local sd fd
  sd=$(printf '%s' "$screens_data" | sed 's/^{//;s/}$//')
  fd=$(printf '%s' "$filter_data" | sed 's/^{//;s/}$//')
  combined_data="{${sd},${fd}}"

  _json_response true null "$combined_data"
}
