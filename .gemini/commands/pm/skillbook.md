---
model: haiku
---

# Skillbook View

View all entries in the accumulated skillbook.

## Usage
```
/pm:skillbook
```

## Instructions

1. **Load skillbook:**
   ```bash
   skillbook=".gemini/context/skillbook.md"
   test -f "$skillbook" || { echo "📚 Skillbook is empty. Entries are added automatically after task completion."; exit 0; }
   ```

2. **Count entries:**
   ```bash
   count=$(grep -c '^id: SKL-' "$skillbook" 2>/dev/null) || count=0
   [ "$count" -eq 0 ] && echo "📚 Skillbook is empty. Entries are added automatically after task completion." && exit 0
   ```

3. **Display table header:**
   ```
   📚 Skillbook ($count entries)

   | ID | Pattern | Context | Source | Matched | Count |
   |----|---------|---------|--------|---------|-------|
   ```

4. **Parse and display each entry:**
   Read the skillbook file and extract per-entry metadata from YAML frontmatter blocks:
   - `id:` → ID column
   - `pattern:` → Pattern type (helpful/pitfall)
   - `context:` → Keywords (truncate to 30 chars)
   - `source_task:` → Source
   - `last_matched:` → Date only (YYYY-MM-DD)
   - `match_count:` → Count

   Display one table row per entry.

5. **Footer:**
   ```
   Manage: /pm:skillbook-prune (remove unused entries)
   ```
