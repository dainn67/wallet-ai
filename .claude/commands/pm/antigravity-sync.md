---
model: sonnet
allowed-tools: Bash, Read
---

# Antigravity Sync

Sync features from Claude Code to Antigravity IDE. Detects gaps and transforms command files.

## Usage
```
/pm:antigravity-sync [--dry-run] [--type workflows|rules|all]
```

**Flags:**
- `--dry-run` — Detect gaps only, no files written
- `--type workflows` — Sync only workflow commands
- `--type rules` — Sync only rules
- `--type all` — Sync everything (default)

## Preflight

```bash
test -f .claude/scripts/pm/antigravity-sync.sh || { echo "❌ Script not found: .claude/scripts/pm/antigravity-sync.sh"; exit 1; }
```

## Instructions

Parse `$ARGUMENTS` for flags:

```bash
dry_run=false
type_filter="all"

for arg in $ARGUMENTS; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --type) : ;; # next arg is value
    workflows|rules|all)
      # previous arg was --type, this is the value
      type_filter="$arg"
      ;;
  esac
done
```

**If `--dry-run`:**
```bash
bash .claude/scripts/pm/antigravity-sync.sh detect
```
Show output and stop — no files written.

**Otherwise (sync):**
```bash
bash .claude/scripts/pm/antigravity-sync.sh sync --type "$type_filter" --yes
```

## Error Handling

If script fails:
- Show: `❌ Sync failed. Check that config/antigravity-sync.json exists and jq is installed.`
- Show script stderr for details

## Output

Show script output directly to user.
