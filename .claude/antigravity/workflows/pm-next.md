---
name: pm-next
description: ## Hybrid Routing
# tier: medium
---

## Hybrid Routing

Check `$ARGUMENTS`:

**If `$ARGUMENTS` is empty** → run script path (0 LLM tokens):
```bash
bash .claude/scripts/pm/next.sh --smart
```
Display the output and stop.

**If `$ARGUMENTS` has text** → proceed with NL intent matching below.

---

## NL Intent Matching (only when $ARGUMENTS is non-empty)

### Step 1: Build command catalog via auto-discovery

Run this to build the catalog:
```bash
for f in commands/pm/*.md; do
  name=$(grep -m1 "^name:" "$f" 2>/dev/null | sed 's/name: *//')
  desc=$(grep -m1 "^description:" "$f" 2>/dev/null | sed 's/description: *//')
  [ -n "$name" ] && [ -n "$desc" ] && echo "- pm:$name — $desc"
done
```

If no commands found, output: `No commands found` and stop.

### Step 2: Load tier annotations (optional)

```bash
test -f config/model-tiers.json && cat config/model-tiers.json || echo "{}"
```

### Step 3: Match user intent

Using the catalog from Step 1 and the tiers from Step 2, match the user's query:

**User query:** `$ARGUMENTS`

**Matching rules:**
- Truncate query to first 100 characters for matching
- Support Vietnamese and English queries naturally
- Vietnamese hints: "xem tiến độ" → status/epic-show; "tạo PRD mới" → prd-new; "chạy test" → epic-verify; "decompose epic" → epic-decompose; "tìm kiếm" → search
- If clear single match → output:
  ```
  → pm:{command}  [tier/model]  # {why this matches}
  ```
- If ambiguous → output top-3 suggestions, each with tier annotation and brief reason
- If no match → output: `No matching commands found. Try: pm:help`

**Tier annotation format:** look up command name in model-tiers.json `commands` object → map tier value using `tiers` object (e.g., `"heavy"` → `opus`). If not found, omit annotation.

**Output format for suggestions:**
```
→ pm:{command}  [tier/model]  # {reason}
→ pm:{command}  [tier/model]  # {reason}
→ pm:{command}  [tier/model]  # {reason}
```
