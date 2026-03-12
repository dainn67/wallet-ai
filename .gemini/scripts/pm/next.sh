#!/bin/bash

# --all flag bypasses analyze filtering
show_all=false
[ "$1" = "--all" ] && show_all=true

echo "📋 Next Available Tasks"
echo "======================="
echo ""

found=0
filtered=0

for epic_dir in .gemini/epics/*/; do
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
