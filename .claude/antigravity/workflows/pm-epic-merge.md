---
name: pm-epic-merge
description: Epic Merge
# tier: heavy
---

# Epic Merge

Merge completed epic from worktree back to main branch.

## Usage
```
/pm:epic-merge <epic_name>
```

## Quick Check

1. **Verify worktree exists:**
   ```bash
   git worktree list | grep "epic-$EPIC_NAME" || echo "❌ No worktree for epic: $EPIC_NAME"
   ```

2. **Check for active agents:**
   Read `.claude/epics/$EPIC_NAME/execution-status.md`
   If active agents exist: "⚠️ Active agents detected. Stop them first with: /pm:epic-stop $EPIC_NAME"

## Instructions

### 1. Pre-Merge Validation

Navigate to worktree and check status:
```bash
cd ../epic-$EPIC_NAME

# Check for uncommitted changes
if [[ $(git status --porcelain) ]]; then
  echo "⚠️ Uncommitted changes in worktree:"
  git status --short
  echo "Commit or stash changes before merging"
  exit 1
fi

# Check branch status
git fetch origin
git status -sb
```

### 2. Run Tests (Optional but Recommended)

```bash
# Look for test commands based on project type
if [ -f package.json ]; then
  npm test || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f pom.xml ]; then
  mvn test || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  ./gradlew test || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f composer.json ]; then
  ./vendor/bin/phpunit || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f *.sln ] || [ -f *.csproj ]; then
  dotnet test || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f Cargo.toml ]; then
  cargo test || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f go.mod ]; then
  go test ./... || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f Gemfile ]; then
  bundle exec rspec || bundle exec rake test || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f pubspec.yaml ]; then
  flutter test || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f Package.swift ]; then
  swift test || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f CMakeLists.txt ]; then
  cd build && ctest || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
elif [ -f Makefile ]; then
  make test || echo "⚠️ Tests failed. Continue anyway? (yes/no)"
fi
```

### 3. Verify All Tasks Complete

Check all task files in `.claude/epics/$EPIC_NAME/` (files matching `[0-9]*.md`):
- Read frontmatter of each task file
- Verify all have `status: closed`
- If any task is NOT closed: "❌ Cannot merge epic. Open tasks remain: {list of task names + statuses}" and stop

### 4. Update Epic Documentation

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update `.claude/epics/$EPIC_NAME/epic.md` frontmatter:
- Set `status: completed`
- Set `progress: 100%`
- Set `completed: {current_datetime}`
- Update `updated: {current_datetime}`

### 5. Attempt Merge

```bash
# Return to main repository
cd {main-repo-path}

# Ensure main is up to date
git checkout main
git pull origin main

# Attempt merge
echo "Merging epic/$EPIC_NAME to main..."
git merge epic/$EPIC_NAME --no-ff -m "Merge epic: $EPIC_NAME

Completed features:
# Generate feature list
feature_list=""
if [ -d ".claude/epics/$EPIC_NAME" ]; then
  cd .claude/epics/$EPIC_NAME
  for task_file in [0-9]*.md; do
    [ -f "$task_file" ] || continue
    task_name=$(grep '^name:' "$task_file" | cut -d: -f2 | sed 's/^ *//')
    feature_list="$feature_list\n- $task_name"
  done
  cd - > /dev/null
fi

echo "$feature_list"

# Extract epic issue number
epic_github_line=$(grep 'github:' .claude/epics/$EPIC_NAME/epic.md 2>/dev/null || true)
if [ -n "$epic_github_line" ]; then
  epic_issue=$(echo "$epic_github_line" | grep -oE '[0-9]+' || true)
  if [ -n "$epic_issue" ]; then
    echo "\nCloses epic #$epic_issue"
  fi
fi"
```

### 6. Handle Merge Conflicts

If merge fails with conflicts:
```bash
# Check conflict status
git status

echo "
❌ Merge conflicts detected!

Conflicts in:
$(git diff --name-only --diff-filter=U)

Options:
1. Resolve manually:
   - Edit conflicted files
   - git add {files}
   - git commit
   
2. Abort merge:
   git merge --abort
   
3. Get help:
   /pm:epic-resolve $EPIC_NAME

Worktree preserved at: ../epic-$EPIC_NAME
"
exit 1
```

### 7. Post-Merge Cleanup

If merge succeeds:
```bash
# Push to remote
git push origin main

# Clean up worktree
git worktree remove ../epic-$EPIC_NAME
echo "✅ Worktree removed: ../epic-$EPIC_NAME"

# Delete branch
git branch -d epic/$EPIC_NAME
git push origin --delete epic/$EPIC_NAME 2>/dev/null || true

# Archive epic locally
mkdir -p .claude/epics/.archived/
mv .claude/epics/$EPIC_NAME .claude/epics/.archived/
echo "✅ Epic archived: .claude/epics/.archived/$EPIC_NAME"
```

### 7.5. Memory Agent Consolidation Trigger (if enabled)

After successful merge and cleanup:

1. Check config:
   ```bash
   source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
   read_config_bool "memory_agent" "enabled" && read_config_bool "memory_agent" "auto_ingest"
   ```
2. If both enabled:
   ```bash
   source .claude/scripts/pm/lifecycle-helpers.sh 2>/dev/null
   HOST=$(_json_get .claude/config/lifecycle.json '.memory_agent.host' 2>/dev/null || echo "localhost")
   PORT=$(_json_get .claude/config/lifecycle.json '.memory_agent.port' 2>/dev/null || echo "8888")
   [ "$HOST" = "null" ] || [ -z "$HOST" ] && HOST="localhost"
   [ "$PORT" = "null" ] || [ -z "$PORT" ] && PORT="8888"
   PROJECT_ROOT=$(pwd)
   curl -s --max-time 2 -X POST "http://${HOST}:${PORT}/consolidate" \
     -H "X-Project-Root: $PROJECT_ROOT" \
     >/dev/null 2>&1 || true
   ```
3. If fails: continue silently — merge is already complete.

### 8. Update GitHub Issues

Close related issues:
```bash
# Detect repo from epic's github: field
REPO=""
epic_github=$(grep '^github:' .claude/epics/.archived/$EPIC_NAME/epic.md 2>/dev/null | head -1 | sed 's/^github: *//')
if [ -n "$epic_github" ]; then
  REPO=$(echo "$epic_github" | sed 's|https://github.com/||' | sed 's|/issues/.*||')
fi
if [ -z "$REPO" ]; then
  REPO=$(bash .claude/scripts/pm/github-helpers.sh get-repo-for-issue 2>/dev/null || echo "")
fi

# Get issue numbers from epic
# Extract epic issue number
epic_github_line=$(grep 'github:' .claude/epics/.archived/$EPIC_NAME/epic.md 2>/dev/null || true)
if [ -n "$epic_github_line" ]; then
  epic_issue=$(echo "$epic_github_line" | grep -oE '[0-9]+$' || true)
else
  epic_issue=""
fi

# Close epic issue
gh issue close $epic_issue --repo "$REPO" -c "Epic completed and merged to main"

# Close task issues
for task_file in .claude/epics/.archived/$EPIC_NAME/[0-9]*.md; do
  [ -f "$task_file" ] || continue
  # Extract task issue number
  task_github_line=$(grep 'github:' "$task_file" 2>/dev/null || true)
  if [ -n "$task_github_line" ]; then
    issue_num=$(echo "$task_github_line" | grep -oE '[0-9]+$' || true)
  else
    issue_num=""
  fi
  if [ ! -z "$issue_num" ]; then
    gh issue close $issue_num --repo "$REPO" -c "Completed in epic merge"
  fi
done
```

### 9. Update PRD Status

If the epic references a PRD (check `prd:` field in epic frontmatter or find matching PRD in `.claude/prds/`):
- Update PRD frontmatter: set `status: complete` and `updated: {current_datetime}`

### 10. Final Output

```
✅ Epic Merged Successfully: $EPIC_NAME

Summary:
  Branch: epic/$EPIC_NAME → main
  Commits merged: {count}
  Files changed: {count}
  Issues closed: {count}

Cleanup completed:
  ✓ All tasks verified closed
  ✓ Epic status updated (completed, 100%)
  ✓ Worktree removed
  ✓ Branch deleted
  ✓ Epic archived
  ✓ GitHub issues closed
  ✓ PRD status updated (if applicable)

Next steps:
  - Start new epic: /pm:prd-new {feature}
  - View completed work: git log --oneline -20
```

## Conflict Resolution Help

If conflicts need resolution:
```
The epic branch has conflicts with main.

This typically happens when:
- Main has changed since epic started
- Multiple epics modified same files
- Dependencies were updated

To resolve:
1. Open conflicted files
2. Look for <<<<<<< markers
3. Choose correct version or combine
4. Remove conflict markers
5. git add {resolved files}
6. git commit
7. git push

Or abort and try later:
  git merge --abort
```

## Important Notes

- Always check for uncommitted changes first
- Run tests before merging when possible
- Use --no-ff to preserve epic history
- Archive epic data instead of deleting
- Close GitHub issues to maintain sync
