---
name: pm-sync
description: Sync
# tier: medium
---

# Sync

Bidirectional sync between local files and GitHub issues.

## Usage
```
/pm:sync [epic_name]
```

If epic_name provided, sync only that epic. Otherwise sync all.

## Preflight

```bash
# Detect GitHub repo (smart: epic config → mapping → git remote)
REPO=$(bash .claude/scripts/pm/github-helpers.sh get-repo-for-issue 2>/dev/null || echo "")
[ -z "$REPO" ] && { echo "❌ Cannot detect GitHub repo. Ensure epic has github: field or init git repo."; exit 1; }

# Check remote is not CCPM template
[[ "$REPO" == *"automazeio/ccpm"* ]] && { echo "❌ Cannot sync with CCPM template repo."; exit 1; }

# Verify gh auth
gh auth status 2>/dev/null || { echo "❌ Not authenticated. Run: gh auth login"; exit 1; }
```

Use `--repo "$REPO"` in ALL `gh` commands below.

## Instructions

### Step 1: Pull from GitHub

```bash
gh issue list --repo "$REPO" --label "epic" --limit 100 --json number,title,state,updatedAt
gh issue list --repo "$REPO" --label "task" --limit 100 --json number,title,state,updatedAt
```

### Step 2: Update Local from GitHub

For each GitHub issue, find the corresponding local file (by issue number in filename):
- If GitHub is **closed** but local `status: open` → update local to `status: closed`
- If GitHub is **reopened** but local `status: closed` → update local to `status: open`
- Update local `updated:` field

### Step 3: Push Local to GitHub

For each local task/epic with a `github:` URL:
- If local `updated` is newer than GitHub `updatedAt`, push changes:
  ```bash
  sed '1,/^---$/d; 1,/^---$/d' {local_file} > /tmp/sync-body.md
  gh issue edit {number} --repo "$REPO" --body-file /tmp/sync-body.md
  ```

### Step 4: Handle Conflicts

If both local and GitHub changed since last sync:
- Show the user both versions (local status vs GitHub status)
- Ask: "Conflict on #{number}. Keep **local** or **GitHub** version?"
- Apply user's choice
- Do NOT offer a "merge" option — pick one or the other to avoid confusion

### Step 5: Update Timestamps

Update all synced files with current `last_sync` timestamp in frontmatter.

### Output

```
✅ Sync complete

Pulled: {count} updates from GitHub
Pushed: {count} updates to GitHub
Conflicts: {count} resolved

Next steps:
  - View status: /pm:status
  - View specific epic: /pm:epic-show {name}
```

## Error Handling

If any sync operation fails:
- Report what succeeded and what failed
- Do NOT retry automatically
- Local files are never deleted during sync
