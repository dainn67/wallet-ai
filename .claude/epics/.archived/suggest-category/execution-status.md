---
epic: suggest-category
branch: epic/suggest-category
snapshot: 2026-04-05T16:33:14Z
---

# Execution Status: suggest-category

**Branch:** `epic/suggest-category`

## Counts
- Ready: 2
- Blocked: 4
- In progress: 0
- Complete: 0/6

## Ready
- #161 — SuggestedCategory model + transient field on Record (parallel, phase 1)
- #162 — resolveCategoryByNameOrCreate helper on RecordProvider (parallel, phase 1)

## Blocked
- #163 — Parse suggested_category in ChatProvider stream handler (depends: 161)
- #164 — Build SuggestionBanner widget (depends: 161)
- #165 — Integrate SuggestionBanner into chat_bubble + wire Confirm/Cancel (depends: 163, 164, 162)
- #166 — Tests + living docs update + integration verification (depends: 161, 162, 163, 164, 165)
