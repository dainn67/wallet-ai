---
name: pm-upstream-sync
description: Upstream Sync
# tier: medium
---

# Upstream Sync

Fetch latest changes from upstream `automazeio/ccpm` and selectively apply them to this fork.

## Usage
```
/pm:upstream-sync
```

## Preflight

```bash
test -f .claude/scripts/pm/upstream-sync.sh || { echo "❌ Script not found: .claude/scripts/pm/upstream-sync.sh"; exit 1; }
```

## Instructions

### Step 1: Fetch and categorize upstream changes

```bash
bash .claude/scripts/pm/upstream-sync.sh --summary
```

**If output is `UP_TO_DATE`:**
Display: "✅ Already up to date with upstream."
Exit.

**Otherwise:** Parse the output and build a categorized summary.

### Step 2: Display categorized summary

Parse output lines:
- `CATEGORY:{cat}:{count}` — category header with file count
- `  FILE:{status}:{path}` — individual file entry (A=added, M=modified, D=deleted)
- `UPSTREAM_COMMIT:{hash}` — upstream HEAD commit (save for later)

Display to user:

```
Upstream Changes (since last sync):

📁 New/Modified Scripts ({count} files):
  {status} {file}
  ...

📝 New/Modified Commands ({count} files):
  {status} {file}
  ...

📋 Rule Changes ({count} files):
  {status} {file}
  ...

⚙️ Config Changes ({count} files):
  {status} {file}
  ...

⚠️ Breaking Changes ({count} files):
  {status} {file}
  ...
```

Skip categories with 0 files.

### Step 3: Accept/reject per category

Also get the diff base commit:
```bash
BASE=$(bash .claude/scripts/pm/upstream-sync.sh --base)
```

For each category that has changes, ask the user:

```
[{category}] — {count} file(s). Accept / Reject / Review?
```

- **Accept** → mark category as accepted
- **Reject** → mark category as rejected
- **Review** → show diff for each file in this category:
  ```bash
  bash .claude/scripts/pm/upstream-sync.sh --diff-file "$BASE" "{file}"
  ```
  Then re-ask: Accept or Reject?

For **breaking changes**: add extra warning before accepting:
```
⚠️ Breaking changes may affect existing workflows. Review carefully before accepting.
```

### Step 4: Apply accepted changes

For each accepted category:
```bash
bash .claude/scripts/pm/upstream-sync.sh --apply-category "{category}" "$BASE"
```

If a file causes a conflict (already modified locally), display:
```
⚠️ Conflict: {file} — modified both locally and upstream. Showing both versions.
```
Show local version, show upstream diff. Ask: Override / Skip?
- Override → `bash .claude/scripts/pm/upstream-sync.sh --apply-file "{file}"`
- Skip → leave local version

### Step 5: Update sync log

After applying, update the sync log:
```bash
bash .claude/scripts/pm/upstream-sync.sh --update-log "{upstream_commit}" "{accepted_categories}" "{rejected_categories}"
```

Where `{accepted_categories}` and `{rejected_categories}` are space-separated category names.

### Step 6: Commit applied changes

If any files were applied:
```bash
git add -A
git commit -m "upstream-sync: apply upstream changes from automazeio/ccpm@{short_commit}"
```

### Step 7: Final output

```
✅ Upstream sync complete

  Accepted: {accepted_categories}
  Rejected: {rejected_categories}
  Files applied: {count}
  Sync log: .claude/context/upstream-sync-log.md

Next: Review applied changes and run tests if needed.
```
