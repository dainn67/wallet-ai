---
epic: suggest-category
branch: epic/suggest-category
started: 2026-04-05T16:33:14Z
status: in-progress
---
# Epic Context: suggest-category

## Key Decisions
- **AD-1:** Transient `suggestedCategory` field on `Record` (not persisted, not a separate provider).
- **AD-2:** New `resolveCategoryByNameOrCreate` helper on `RecordProvider` works around `addCategory` returning void. `RecordRepository.createCategory` may need return type changed from `void` to `int` (sqflite `db.insert` already returns row id).
- **AD-3:** `SuggestionBanner` as sibling widget in `chat_bubble.dart:78` (via `expand`), NOT nested inside `RecordWidget`.
- **AD-4:** `Record.copyWith` uses `bool clearSuggestedCategory = false` flag for nullable reset.

## Notes
- GitHub: epic #160, tasks #161–#166.
- Phase 1 parallel: #161 (model) + #162 (resolver helper) — no file conflicts.
- Phase 2 parallel: #163 (chat parse, depends #161) + #164 (banner widget, depends #161).
- Phase 3 sequential: #165 (integration) → #166 (tests + docs).
