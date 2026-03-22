#!/bin/bash

# detect_project_state: check 11 project states, output suggestion, return 0 if found
detect_project_state() {
  # Load tier annotations from config if available
  _tier() {
    local cmd="$1"
    if [ -f ".claude/config/model-tiers.json" ]; then
      local tier
      tier=$(python3 -c "
import json, sys
try:
  d = json.load(open('.claude/config/model-tiers.json'))
  cmd = sys.argv[1]
  tier_name = d['commands'].get(cmd, 'medium')
  model = d['tiers'].get(tier_name, tier_name)
  print(f'[{tier_name}/{model}]')
except Exception:
  print('[medium/sonnet]')
" "$cmd" 2>/dev/null)
      echo "${tier:-[medium/sonnet]}"
    else
      case "$cmd" in
        prd-rethink|prd-new|prd-parse|plan-review|epic-start|epic-verify|epic-merge|build) echo "[heavy/opus]" ;;
        *) echo "[medium/sonnet]" ;;
      esac
    fi
  }

  # Most recently updated feature (epic or PRD) helper
  _latest_epic() {
    ls -t .claude/epics/*/epic.md 2>/dev/null | head -1 | sed 's|.claude/epics/||;s|/epic.md||'
  }
  _latest_prd() {
    ls -t .claude/prds/*.md 2>/dev/null | grep -v README | head -1
  }

  # State 11: Active build in progress
  local build_state
  build_state=$(ls -t .claude/context/build-state/*.json 2>/dev/null | head -1)
  if [ -n "$build_state" ]; then
    local feature step
    feature=$(basename "$build_state" .json)
    step=$(python3 -c "
import json, sys
try:
  d = json.load(open(sys.argv[1]))
  steps = d.get('steps', [])
  idx = d.get('current_step', 0)
  print(steps[idx]['name'] if idx < len(steps) else 'unknown')
except Exception:
  print('unknown')
" "$build_state" 2>/dev/null)
    echo "pm:build --resume $feature  $(_tier build)  # Resume at: $step"
    return 0
  fi

  # State 10: Epic verified (verify status = passed) → suggest epic-merge
  local latest_epic
  latest_epic=$(_latest_epic)
  if [ -n "$latest_epic" ]; then
    local epic_dir=".claude/epics/$latest_epic"
    local epic_status
    epic_status=$(grep "^status:" "$epic_dir/epic.md" 2>/dev/null | head -1 | sed 's/^status: *//')

    # Check verify state
    local verify_state=".claude/context/verify/epic-state.json"
    if [ -f "$verify_state" ]; then
      local verify_result
      verify_result=$(python3 -c "
import json
try:
  d = json.load(open('$verify_state'))
  print(d.get('result', ''))
except Exception:
  print('')
" 2>/dev/null)
      if [ "$verify_result" = "passed" ]; then
        echo "pm:epic-merge $latest_epic  $(_tier epic-merge)  # Verify passed, ready to merge"
        return 0
      fi
    fi

    # State 9: All tasks closed → suggest epic-verify
    local open_tasks in_progress_tasks
    open_tasks=$(grep -l "^status: *open" "$epic_dir"/[0-9]*.md 2>/dev/null | wc -l | tr -d ' ')
    in_progress_tasks=$(grep -l "^status: *in-progress" "$epic_dir"/[0-9]*.md 2>/dev/null | wc -l | tr -d ' ')
    local total_tasks
    total_tasks=$(ls "$epic_dir"/[0-9]*.md 2>/dev/null | wc -l | tr -d ' ')

    if [ "$total_tasks" -gt 0 ] && [ "$open_tasks" -eq 0 ] && [ "$in_progress_tasks" -eq 0 ]; then
      echo "pm:epic-verify $latest_epic  $(_tier epic-verify)  # All tasks done, verify before merge"
      return 0
    fi

    # State 7: Tasks exist, epic not started yet → suggest epic-start
    if [ "$total_tasks" -gt 0 ] && [ "$epic_status" = "backlog" ]; then
      echo "pm:epic-start $latest_epic  $(_tier epic-start)  # Tasks ready, start the epic"
      return 0
    fi

    # State 8: Epic in-progress with open/in-progress tasks → fall through to existing task logic
    if [ "$in_progress_tasks" -gt 0 ] || [ "$open_tasks" -gt 0 ]; then
      return 1
    fi

    # State 6: Epic reviewed (plan-review done), no tasks → suggest epic-decompose
    local plan_review_done=false
    if grep -q "plan.review\|plan_review\|reviewed" "$epic_dir/epic.md" 2>/dev/null; then
      plan_review_done=true
    fi
    if [ "$plan_review_done" = true ] && [ "$total_tasks" -eq 0 ]; then
      echo "pm:epic-decompose $latest_epic  $(_tier epic-decompose)  # Epic reviewed, decompose into tasks"
      return 0
    fi

    # State 5: Epic exists, no plan-review → suggest plan-review
    if [ "$total_tasks" -eq 0 ]; then
      echo "pm:plan-review $latest_epic  $(_tier plan-review)  # Epic created, review the plan"
      return 0
    fi
  fi

  # State 4: Validated PRD (status=in-progress or complete), no epic → suggest prd-parse
  local latest_prd
  latest_prd=$(_latest_prd)
  if [ -n "$latest_prd" ]; then
    local prd_status
    prd_status=$(grep "^status:" "$latest_prd" 2>/dev/null | head -1 | sed 's/^status: *//')
    local prd_name
    prd_name=$(basename "$latest_prd" .md)

    if [ "$prd_status" = "in-progress" ] || [ "$prd_status" = "complete" ]; then
      if [ -z "$latest_epic" ]; then
        echo "pm:prd-parse $prd_name  $(_tier prd-parse)  # PRD validated, parse into epic"
        return 0
      fi
    fi

    # State 3: PRD exists with warnings/backlog → suggest prd-edit
    if [ "$prd_status" = "backlog" ]; then
      echo "pm:prd-edit $prd_name  $(_tier prd-edit)  # PRD needs review/editing before validation"
      return 0
    fi

    # State 2: PRD exists, not validated → suggest validate
    echo "pm:validate $prd_name  $(_tier validate)  # PRD exists, validate it"
    return 0
  fi

  # State 1: No PRDs → suggest prd-rethink or prd-new
  echo "pm:prd-rethink  $(_tier prd-rethink)  # No PRDs found — start with rethink or prd-new"
  return 0
}

# Parse flags
show_all=false
smart_mode=false

for arg in "$@"; do
  case "$arg" in
    --all) show_all=true ;;
    --smart) smart_mode=true ;;
  esac
done

# Smart mode: triggered by --smart flag or when no positional args given
has_positional=false
for arg in "$@"; do
  case "$arg" in
    --all|--smart) ;;
    *) has_positional=true; break ;;
  esac
done

if [ "$smart_mode" = true ] || [ "$has_positional" = false ]; then
  if detect_project_state; then
    exit 0
  fi
  # State 8 fall-through: show open tasks
fi

echo "📋 Next Available Tasks"
echo "======================="
echo ""

found=0
filtered=0

for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  epic_name=$(basename "$epic_dir")

  # Skip non-epic directories
  [ -f "$epic_dir/epic.md" ] || continue

  # Build map of closed task phases for dependency resolution
  # Collect the highest closed phase in this epic
  max_closed_phase=-1
  for tf in "$epic_dir"/[0-9]*.md; do
    [ -f "$tf" ] || continue
    tf_status=$(grep "^status:" "$tf" | head -1 | sed 's/^status: *//')
    if [ "$tf_status" = "closed" ] || [ "$tf_status" = "completed" ]; then
      tf_phase=$(grep "^phase:" "$tf" | head -1 | sed 's/^phase: *//')
      [ -n "$tf_phase" ] && [ "$tf_phase" -gt "$max_closed_phase" ] 2>/dev/null && max_closed_phase=$tf_phase
    fi
  done

  for task_file in "$epic_dir"/[0-9]*.md; do
    [ -f "$task_file" ] || continue

    # Check if task is open
    task_status=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
    if [ "$task_status" != "open" ] && [ -n "$task_status" ]; then
      continue
    fi

    # Check dependencies via phase ordering:
    # A task is available if it has no phase, or all tasks in lower phases are closed
    task_phase=$(grep "^phase:" "$task_file" | head -1 | sed 's/^phase: *//')

    deps_met=true
    if [ -n "$task_phase" ] && [ "$task_phase" -gt 1 ] 2>/dev/null; then
      # Check that all tasks in previous phases are closed
      for tf in "$epic_dir"/[0-9]*.md; do
        [ -f "$tf" ] || continue
        [ "$tf" = "$task_file" ] && continue
        tf_phase=$(grep "^phase:" "$tf" | head -1 | sed 's/^phase: *//')
        [ -z "$tf_phase" ] && continue
        if [ "$tf_phase" -lt "$task_phase" ] 2>/dev/null; then
          tf_status=$(grep "^status:" "$tf" | head -1 | sed 's/^status: *//')
          if [ "$tf_status" != "closed" ] && [ "$tf_status" != "completed" ]; then
            deps_met=false
            break
          fi
        fi
      done
    fi

    if [ "$deps_met" = true ]; then
      task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//')
      task_num=$(basename "$task_file" .md)
      task_parallel=$(grep "^parallel:" "$task_file" | head -1 | sed 's/^parallel: *//')

      # Filter analyze issues unless --all
      if [ "$show_all" = false ]; then
        is_analyze=false
        # Check filename for -analysis suffix
        case "$(basename "$task_file" .md)" in
          *-analysis) is_analyze=true ;;
        esac
        # Check name prefix
        if [ "$is_analyze" = false ]; then
          case "$task_name" in
            \[Analysis\]*|\[Analyze\]*) is_analyze=true ;;
          esac
        fi
        # Check body marker (must be on its own line, not inside backticks)
        if [ "$is_analyze" = false ] && grep -q '^<!-- type: analyze -->' "$task_file" 2>/dev/null; then
          is_analyze=true
        fi
        if [ "$is_analyze" = true ]; then
          ((filtered++))
          continue
        fi
      fi

      echo "✅ Ready: #$task_num - $task_name"
      echo "   Epic: $epic_name"
      [ "$task_parallel" = "true" ] && echo "   🔄 Can run in parallel"
      echo ""
      ((found++))
    fi
  done
done

if [ $found -eq 0 ]; then
  echo "No available tasks found."
  echo ""
  echo "💡 Suggestions:"
  echo "  • Check blocked tasks: /pm:blocked"
  echo "  • View all tasks: /pm:epic-list"
fi

[ $filtered -gt 0 ] && echo "ℹ️ $filtered analyze issues filtered. Use --all to include."
echo ""
echo "📊 Summary: $found tasks ready to start"

exit 0
