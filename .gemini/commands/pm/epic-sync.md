---
model: sonnet
allowed-tools: Bash, Read, Write, LS
---

# Epic Sync

Push epic and tasks to GitHub as issues.

## Usage
```
/pm:epic-sync <feature_name>
```

## Preflight

Run these checks and **stop immediately** if any fail:

```bash
# 1. Verify epic exists
test -f .gemini/epics/$ARGUMENTS/epic.md || { echo "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"; exit 1; }

# 2. Check for task files (001.md, 002.md, etc.)
task_count=$(ls .gemini/epics/$ARGUMENTS/[0-9]*.md 2>/dev/null | grep -cv epic.md)
[ "$task_count" -eq 0 ] && { echo "❌ No tasks to sync. Run: /pm:epic-decompose $ARGUMENTS"; exit 1; }

# 3. Check if already synced (idempotency)
if [ -f ".gemini/epics/$ARGUMENTS/github-mapping.md" ]; then
  echo "⚠️ Epic already synced to GitHub. Mapping file exists."
  echo "To re-sync, first delete: .gemini/epics/$ARGUMENTS/github-mapping.md"
  exit 0
fi

# 4. Check remote is not the CCPM template
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]]; then
  echo "❌ Remote points to CCPM template repo. Update your remote origin first."
  exit 1
fi

# 5. Detect repo
REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
[ -z "$REPO" ] && { echo "❌ Cannot detect GitHub repo from remote origin."; exit 1; }
echo "Repository: $REPO"
echo "Tasks to sync: $task_count"
```

## Instructions

Execute steps 1-5 sequentially. Each step depends on the previous one.

### Step 1: Create Epic Issue

```bash
# Strip frontmatter from epic
sed '1,/^---$/d; 1,/^---$/d' .gemini/epics/$ARGUMENTS/epic.md > /tmp/epic-body.md

# Remove "## Tasks Created" section (internal metadata, not for GitHub)
awk '/^## Tasks Created/{skip=1; next} /^## / && skip{skip=0} !skip' /tmp/epic-body.md > /tmp/epic-body-clean.md
mv /tmp/epic-body-clean.md /tmp/epic-body.md

# Create epic issue — parse number from URL output
epic_url=$(gh issue create \
  --repo "$REPO" \
  --title "Epic: $ARGUMENTS" \
  --body-file /tmp/epic-body.md \
  --label "epic,epic:$ARGUMENTS")
epic_number=$(echo "$epic_url" | grep -oE '[0-9]+$')

echo "✅ Epic created: #$epic_number"
```

If `epic_number` is empty, stop and report: "❌ Failed to create epic issue."

### Step 2: Create Task Issues

Check if gh-sub-issue extension is available, then create tasks **sequentially**:

```bash
# Check sub-issue support
use_subissues=false
gh extension list 2>/dev/null | grep -q "yahsan2/gh-sub-issue" && use_subissues=true

# Clear temp mapping
> /tmp/task-mapping.txt

for task_file in .gemini/epics/$ARGUMENTS/[0-9]*.md; do
  [ -f "$task_file" ] || continue
  # Skip epic.md
  [ "$(basename "$task_file")" = "epic.md" ] && continue

  task_name=$(grep '^name:' "$task_file" | head -1 | sed 's/^name: *//')
  recommended_model=$(grep '^recommended_model:' "$task_file" | head -1 | sed 's/^recommended_model: *//')
  [ -z "$recommended_model" ] && recommended_model="sonnet"
  sed '1,/^---$/d; 1,/^---$/d' "$task_file" > /tmp/task-body.md

  if [ "$use_subissues" = true ]; then
    task_url=$(gh sub-issue create \
      --parent "$epic_number" \
      --title "$task_name" \
      --body-file /tmp/task-body.md \
      --label "task,epic:$ARGUMENTS,model:$recommended_model")
  else
    task_url=$(gh issue create \
      --repo "$REPO" \
      --title "$task_name" \
      --body-file /tmp/task-body.md \
      --label "task,epic:$ARGUMENTS,model:$recommended_model")
  fi

  task_number=$(echo "$task_url" | grep -oE '[0-9]+$')
  old_num=$(basename "$task_file" .md)

  echo "$old_num:$task_number" >> /tmp/task-mapping.txt
  echo "  ✅ #$task_number - $task_name (was $old_num)"
done
```

If no entries in `/tmp/task-mapping.txt`, stop and report error.

### Step 3: Rename Task Files and Update References

For each task, rename `001.md` → `{issue_number}.md` and update `depends_on`/`conflicts_with` references:

```bash
epic_dir=".gemini/epics/$ARGUMENTS"
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

while IFS=: read -r old_num new_num; do
  old_file="$epic_dir/${old_num}.md"
  new_file="$epic_dir/${new_num}.md"

  [ -f "$old_file" ] || continue

  # Read content
  content=$(cat "$old_file")

  # Replace all old references with new issue numbers
  while IFS=: read -r o n; do
    content=$(echo "$content" | sed "s/${o}/${n}/g")
  done < /tmp/task-mapping.txt

  # Update github and updated fields in frontmatter
  github_url="https://github.com/$REPO/issues/$new_num"
  content=$(echo "$content" | sed "/^github:/s|.*|github: $github_url|")
  content=$(echo "$content" | sed "/^updated:/s|.*|updated: $current_date|")

  # If no github: field exists, add it before the closing --- of frontmatter
  # (uses awk for cross-platform compatibility — the sed equivalent fails on macOS)
  if ! echo "$content" | grep -q '^github:'; then
    content=$(echo "$content" | awk -v val="github: $github_url" 'NR>1 && /^---$/ && !added{print val; added=1} {print}')
  fi

  # Write new file and remove old
  echo "$content" > "$new_file"
  [ "$old_file" != "$new_file" ] && rm "$old_file"
done < /tmp/task-mapping.txt
```

### Step 4: Update Epic File

Update the epic frontmatter with GitHub URL:

```bash
epic_file=".gemini/epics/$ARGUMENTS/epic.md"
epic_github_url="https://github.com/$REPO/issues/$epic_number"
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Read epic content and update frontmatter fields
# Use Read + Write tools to update the github: and updated: fields in epic.md frontmatter
```

Read `.gemini/epics/$ARGUMENTS/epic.md` with the Read tool. Then use the Write tool to update:
- Set `github:` field to the epic GitHub URL
- Set `updated:` field to current datetime
- Update the `## Tasks Created` section to use real issue numbers from the mapping

### Step 5: Create Mapping File and Report

```bash
epic_dir=".gemini/epics/$ARGUMENTS"
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build mapping file content
{
  echo "# GitHub Issue Mapping"
  echo ""
  echo "Epic: #${epic_number} - https://github.com/${REPO}/issues/${epic_number}"
  echo ""
  echo "Tasks:"

  for task_file in "$epic_dir"/[0-9]*.md; do
    [ -f "$task_file" ] || continue
    issue_num=$(basename "$task_file" .md)
    task_name=$(grep '^name:' "$task_file" | head -1 | sed 's/^name: *//')
    echo "- #${issue_num}: ${task_name} - https://github.com/${REPO}/issues/${issue_num}"
  done

  echo ""
  echo "Synced: $current_date"
} > "$epic_dir/github-mapping.md"
```

If NOT using gh-sub-issue, also update the epic issue body with a task checklist:

```bash
if [ "$use_subissues" = false ]; then
  # Build task list
  task_list=""
  for task_file in "$epic_dir"/[0-9]*.md; do
    [ -f "$task_file" ] || continue
    issue_num=$(basename "$task_file" .md)
    task_name=$(grep '^name:' "$task_file" | head -1 | sed 's/^name: *//')
    task_list="${task_list}\n- [ ] #${issue_num} ${task_name}"
  done

  # Append to epic issue
  gh issue view "$epic_number" --repo "$REPO" --json body -q .body > /tmp/epic-update.md
  printf "\n## Tasks\n%b\n" "$task_list" >> /tmp/epic-update.md
  gh issue edit "$epic_number" --repo "$REPO" --body-file /tmp/epic-update.md
fi
```

### Output

```
✅ Synced to GitHub
  - Epic: #{epic_number}
  - Tasks: {count} issues created
  - Labels: epic, task, epic:{name}
  - Files renamed to issue numbers
  - Mapping: .gemini/epics/$ARGUMENTS/github-mapping.md

Next steps:
  - Create branch: /pm:epic-start $ARGUMENTS
  - Or work on single issue: /pm:issue-start {issue_number}
  - View epic: https://github.com/{REPO}/issues/{epic_number}
```

## Error Handling

If any issue creation fails:
- Report what succeeded and what failed
- Do NOT retry automatically
- Do NOT attempt rollback (partial sync is fine)
- User can delete `github-mapping.md` and re-run to start fresh
