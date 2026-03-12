---
model: haiku
---

# Skillbook Prune

Remove unused skillbook entries (match_count=0, older than threshold).

## Usage
```
/pm:skillbook-prune
```

## Instructions

1. **Load skillbook:**
   ```bash
   skillbook=".gemini/context/skillbook.md"
   test -f "$skillbook" || { echo "📚 No skillbook found. Nothing to prune."; exit 0; }
   ```

2. **Get prune threshold from config:**
   ```bash
   source .gemini/scripts/pm/lifecycle-helpers.sh 2>/dev/null || true
   if command -v read_ace_config &>/dev/null; then
     prune_after=$(read_ace_config "skillbook" "prune_after_unused_tasks" "20")
   else
     prune_after=20
   fi
   ```

3. **Identify entries to prune:**
   Parse the skillbook and find entries where `match_count: 0`.
   For age check: compare `created:` date to current date — if older than `$prune_after` tasks (approximate: 1 task ≈ 1 day), mark for pruning.

   Display prune candidates:
   ```
   🔍 Found {N} entries eligible for pruning (match_count=0, unused):

   | ID | Source | Created | Context |
   |----|--------|---------|---------|
   | SKL-003 | epic/test#5 | 2025-01-01 | api,validation |
   ```

4. **Ask for confirmation:**
   ```
   Remove these {N} entries? (yes/no)
   ```
   - **yes**: Remove entries, rewrite skillbook file without pruned entries
   - **no**: Cancel, show: "✅ No changes made."

5. **Rewrite skillbook (if confirmed):**
   Keep header + all non-pruned entries. Update entry IDs to be sequential (SKL-001, SKL-002, ...) after pruning.

   ```bash
   source .gemini/scripts/pm/skillbook-extract.sh 2>/dev/null || true
   if command -v ace_log &>/dev/null; then
     ace_log "PRUNE" "removed ${N} unused entries from skillbook"
   fi
   ```

6. **Output:**
   ```
   ✅ Pruned {N} entries. Skillbook now has {remaining} entries.
   ```
