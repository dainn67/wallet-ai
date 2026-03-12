#!/bin/bash
# epic-run-plan.sh — Generate ordered execution plan for an epic
# Usage: bash .gemini/scripts/pm/epic-run-plan.sh <epic_name>
# Output: pipe-delimited lines, one per task, sorted by phase then task number
# Format: STATUS|TASK_NUM|NAME|MODEL|PHASE|DEPENDS_ON|GITHUB|PARALLEL

epic_name="$1"

if [ -z "$epic_name" ]; then
  echo "❌ Usage: epic-run-plan.sh <epic_name>" >&2
  exit 1
fi

epic_dir=".gemini/epics/$epic_name"

if [ ! -d "$epic_dir" ] || [ ! -f "$epic_dir/epic.md" ]; then
  echo "❌ Epic not found: $epic_dir" >&2
  exit 1
fi

# Collect all task statuses into a temp file for dependency checking
# Format: TASK_NUM STATUS
status_file=$(mktemp)
trap "rm -f '$status_file'" EXIT

for tf in "$epic_dir"/[0-9]*.md; do
  [ -f "$tf" ] || continue
  case "$(basename "$tf" .md)" in
    *-analysis) continue ;;
  esac
  tf_num=$(basename "$tf" .md)
  tf_st=$(grep "^status:" "$tf" | head -1 | sed 's/^status: *//')
  echo "$tf_num $tf_st" >> "$status_file"
done

# Helper: check if a task number is closed/completed
is_task_closed() {
  local num="$1"
  local st
  st=$(grep "^$num " "$status_file" | head -1 | awk '{print $2}')
  [ "$st" = "closed" ] || [ "$st" = "completed" ]
}

# Build plan lines into temp file for sorting
plan_file=$(mktemp)
trap "rm -f '$status_file' '$plan_file'" EXIT

total=0
ready=0
blocked=0
closed=0

for task_file in "$epic_dir"/[0-9]*.md; do
  [ -f "$task_file" ] || continue

  case "$(basename "$task_file" .md)" in
    *-analysis) continue ;;
  esac

  task_num=$(basename "$task_file" .md)
  task_st=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
  task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//')
  task_model=$(grep "^recommended_model:" "$task_file" | head -1 | sed 's/^recommended_model: *//')
  task_phase=$(grep "^phase:" "$task_file" | head -1 | sed 's/^phase: *//')
  task_deps=$(grep "^depends_on:" "$task_file" | head -1 | sed 's/^depends_on: *//')
  task_github=$(grep "^github:" "$task_file" | head -1 | sed 's/^github: *//')
  task_parallel=$(grep "^parallel:" "$task_file" | head -1 | sed 's/^parallel: *//')

  # Defaults
  [ -z "$task_model" ] && task_model="sonnet"
  [ -z "$task_phase" ] && task_phase="1"
  [ -z "$task_deps" ] && task_deps="[]"
  [ -z "$task_parallel" ] && task_parallel="false"

  total=$((total + 1))

  # Skip closed/completed
  if [ "$task_st" = "closed" ] || [ "$task_st" = "completed" ]; then
    closed=$((closed + 1))
    continue
  fi

  # Check explicit depends_on
  deps_met=true
  deps_clean=$(echo "$task_deps" | tr -d '[]' | tr ',' ' ')
  for dep in $deps_clean; do
    dep=$(echo "$dep" | tr -d ' "')
    [ -z "$dep" ] && continue
    # If dep task file doesn't exist, skip it (handles renumbered tasks)
    if ! grep -q "^$dep " "$status_file"; then
      continue
    fi
    if ! is_task_closed "$dep"; then
      deps_met=false
      break
    fi
  done

  # Check phase-based dependencies (all tasks in earlier phases must be closed)
  if [ "$deps_met" = true ] && [ "$task_phase" -gt 1 ] 2>/dev/null; then
    for tf in "$epic_dir"/[0-9]*.md; do
      [ -f "$tf" ] || continue
      case "$(basename "$tf" .md)" in
        *-analysis) continue ;;
      esac
      [ "$tf" = "$task_file" ] && continue
      tf_phase=$(grep "^phase:" "$tf" | head -1 | sed 's/^phase: *//')
      [ -z "$tf_phase" ] && continue
      if [ "$tf_phase" -lt "$task_phase" ] 2>/dev/null; then
        tf_num=$(basename "$tf" .md)
        if ! is_task_closed "$tf_num"; then
          deps_met=false
          break
        fi
      fi
    done
  fi

  if [ "$deps_met" = true ]; then
    line_status="READY"
    ready=$((ready + 1))
  else
    line_status="BLOCKED"
    blocked=$((blocked + 1))
  fi

  # Write with phase+num prefix for sorting
  printf '%03d_%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$task_phase" "$task_num" \
    "$line_status" "$task_num" "$task_name" "$task_model" "$task_phase" "$task_deps" "$task_github" "$task_parallel" \
    >> "$plan_file"
done

echo "# Epic Run Plan: $epic_name"
echo "# Total: $total | Ready: $ready | Blocked: $blocked | Closed: $closed"
echo "#"

# Sort and strip sort prefix
sort "$plan_file" | while IFS= read -r line; do
  echo "${line#*|}"
done

exit 0
