---
name: category-icons
status: completed
completed: 2026-05-26T04:51:17Z
created: 2026-05-25T02:25:41Z
updated: 2026-05-26T04:39:06Z
progress: 100%
priority: P1
prd: .claude/prds/category-icons.md
task_count: 6
github: https://github.com/dainn67/wallet-ai/issues/210
---

# Epic: category-icons

## Overview

Add a single `String emoji` column to the `Category` table (SQLite v9 → v10) and round-trip it through the existing model/repository/provider stack. The chatbot-flow-server's `SuggestedCategory` JSON gains an `emoji` field that the client persists on confirm; the three existing render sites (`CategoryWidget`, `RecordWidget`, `SuggestionBanner`) gain a leading/inline emoji glyph. We deliberately reuse the `Category` model, the `RecordMigrationService` pattern, and the existing seed-map shape — no new package, no new asset bundle, no new widget. The only meaningful risk is server prompt regression on the existing `name`/`type` suggestion path; everything else is small, additive, and isolated.

## Architecture Decisions

### AD-1: Single `String emoji` column on `Category`, not a separate icon table
**Context:** Each category needs exactly one glyph. We considered a `CategoryIcon` join table (icon_id, codepoint, source) and a `Map<int, IconData>` allowlist.
**Decision:** Store the emoji as plain `TEXT NOT NULL DEFAULT '🏷️'` directly on `Category`.
**Alternatives rejected:** (a) Icon table — overkill for one glyph per row and adds JOIN overhead to a hot path (CategoriesTab and RecordsTab pagination); (b) `Map<String, IconData>` Material allowlist — explicitly out of scope per PRD, requires asset bundle.
**Trade-off:** No central icon dictionary; if we ever need to validate or migrate the emoji set we scan rows. Acceptable — the validation happens server-side at write time, not read time.
**Reversibility:** Easy. Column is additive; could be replaced by a join table in a future migration without losing data.

### AD-2: SQLite v9 → v10 migration uses `ADD COLUMN` + guarded UPDATE, not a table rebuild
**Context:** `SuggestedCategory` (`name`, `type`) needs to gain `emoji`, and the existing `Category` table needs `emoji` plus seed backfill. The repository already has both patterns: an additive ADD COLUMN with default (`addOccurredAtColumn`, v7→v8) and a rebuild (`addTargetSourceIdColumn`, v8→v9).
**Decision:** `ALTER TABLE Category ADD COLUMN emoji TEXT NOT NULL DEFAULT '🏷️'`, then run a single guarded `UPDATE` per seed `category_id` only where `emoji = '🏷️'`. Idempotent via `PRAGMA table_info(Category)` existence check, in line with `RecordMigrationService.addOccurredAtColumn`.
**Alternatives rejected:** Table rebuild (copy/drop/rename) — unnecessary, no constraint change; risks reintroducing a v8→v9-style bug.
**Trade-off:** The `WHERE emoji = '🏷️'` guard means if a user somehow set a seed category's emoji *before* migration runs (impossible today), we'd preserve their choice. Costs nothing.
**Reversibility:** Easy. Column drop on rollback (SQLite 3.35+) or leave dormant.

### AD-3: Emoji input is a plain `TextField` + OS emoji keyboard — no `emoji_picker_flutter`
**Context:** PRD FR-4 mentions "tap-to-open emoji picker (using `emoji_picker_flutter` or equivalent)" but Out-of-Scope explicitly defers "in-app emoji picker grid". The Risk entry resolves the tie: try TextField first.
**Decision:** Use a `TextField` with `maxLength` ~8 codepoints, no special keyboard request — both iOS and Android show the emoji key on the system keyboard. On save, validate that the input is non-empty and contains at least one emoji codepoint; fall back to `🏷️` otherwise.
**Alternatives rejected:** `emoji_picker_flutter` package — adds a dependency, is unmaintained risk per PRD, and Out-of-Scope already defers it. Custom emoji grid widget — out of scope.
**Trade-off:** Discoverability of the OS emoji key is platform-dependent. Mitigation: place an inline emoji preview next to the field as the "tap target" hint.
**Reversibility:** Trivial. Swap the TextField for the picker package in a follow-up if UX testing fails.

### AD-4: Server validates and coerces; client treats emoji as best-effort
**Context:** AI output is unreliable — it may return "transport", `""`, `null`, multi-grapheme strings, or full sentences.
**Decision:** Server-side: trim AI output, accept only if result is 1 grapheme (≤8 codepoints) containing at least one codepoint in the Unicode emoji ranges; otherwise rewrite to `'🏷️'` before the JSON leaves the server. Client-side: `SuggestedCategory.fromJson` reads `emoji` with the same fallback (defensive coalesce to `'🏷️'`). The app code must never receive or emit an empty/null/non-emoji string.
**Alternatives rejected:** Client-only validation — leaks bad data into the DB if the validation logic drifts. Server-only validation — fragile if the AI output schema changes.
**Trade-off:** Validation lives in two places. Acceptable: the cost is two ~20-line guards, the benefit is a hard invariant that no `'?'` or empty string ever renders.
**Reversibility:** N/A — validation is a constant property.

### AD-5: Curated seed emoji map is hard-coded in `record_repository.dart` `_seedDatabase` and the v9→v10 migration
**Context:** PRD validation flagged this as a gap — the seed map was only partially specified with examples. Without a concrete list, the migration and seed cannot be implemented identically across new and upgrading installs.
**Decision:** Hard-code the following map in both `_seedDatabase` (new installs) and the v10 migration (upgrades):

| category_id | name          | emoji |
| ----------- | ------------- | ----- |
| 1           | Uncategorized | 🏷️    |
| 2           | Food          | 🍔    |
| 3           | Transport     | 🚗    |
| 4           | Entertainment | 🎬    |
| 5           | Salary        | 💰    |
| 6           | Rent          | 🏠    |
| 7           | Health        | 🏥    |
| 8           | Shopping      | 🛍️    |
| 9           | Transfer      | 🔄    |
| —           | Groceries     | 🛒    |
| —           | Dining Out    | 🍽️    |
| —           | Taxi          | 🚕    |
| —           | Fuel          | ⛽    |
| —           | Cinema        | 🎥    |
| —           | Streaming     | 📺    |
| —           | Clothes       | 👕    |
| —           | Electronics   | 📱    |

Sub-categories are matched by `name` + `parent_id` in the migration since their ids are not pinned.
**Alternatives rejected:** Putting the map in a JSON asset — requires loading via `rootBundle` during migration, more complexity than constant declarations.
**Trade-off:** Map lives in code; changes require a code update. Acceptable — seed categories themselves are already hard-coded.
**Reversibility:** Easy. Edit the constant.

## Technical Approach

### Data Layer — `lib/models/category.dart`, `lib/repositories/record_repository.dart`, `lib/services/record_migration_service.dart`

- **`Category`**: add `final String emoji;` (non-null), defaulting to `'🏷️'`. Update `toMap` (always serialize), `fromMap` (`map['emoji'] as String? ?? '🏷️'` for legacy rows), and `copyWith` (add `String? emoji` parameter).
- **`record_repository.dart`**:
  - Bump `_dbVersion` from `9` to `10`.
  - In `_onCreate`'s Category DDL, add `emoji TEXT NOT NULL DEFAULT '🏷️'`.
  - In `_seedDatabase`, replace each `db.insert` with the matching emoji from AD-5's map.
  - In `_onUpgrade`, add `if (oldVersion < 10) { await RecordMigrationService.addEmojiColumn(db); }`.
- **`record_migration_service.dart`**: add `static Future<void> addEmojiColumn(DatabaseExecutor db)`:
  - `PRAGMA table_info(Category)` — skip if column already exists (idempotent, mirroring `addOccurredAtColumn`).
  - `ALTER TABLE Category ADD COLUMN emoji TEXT NOT NULL DEFAULT '🏷️'`.
  - For each seed row in AD-5: `UPDATE Category SET emoji = ? WHERE category_id = ? AND emoji = '🏷️'` (parent categories by id); `UPDATE Category SET emoji = ? WHERE name = ? AND parent_id = ? AND emoji = '🏷️'` (sub-categories).

### Server — `../chatbot-flow-server/` (wallyai scope)

- Locate the WalletAI category-detection prompt and the `SuggestedCategory` schema (per CLAUDE.md, files under `docs/features/` document this; the actual implementation lives in the wallyai service).
- Add `emoji` to the JSON output schema; update the prompt to instruct the model: *"Return one emoji glyph (single grapheme) that best represents this category. Example: Food → 🍔."*
- Add server-side validation: trim, check grapheme count == 1, check at least one codepoint in `U+1F300..U+1FAFF` ∪ `U+2600..U+27BF` ∪ standard emoji ranges. On failure, set `emoji = '🏷️'` before returning.
- Update existing WalletAI suggestion tests to assert the new field and the fallback path; do not change the `name`/`type` contract.

### Client Suggestion Pipeline — `lib/models/suggested_category.dart`, `lib/providers/chat_provider.dart`

- **`SuggestedCategory`**: add `final String emoji;` (default `'🏷️'`); update `fromJson` to read `json['emoji']` with the same fallback; update `toString` and any equality.
- **`ChatProvider` / suggestion confirm flow**: the existing `resolveCategoryByNameOrCreate` (or equivalent helper that takes a `SuggestedCategory` and produces a `Category`) must pass `suggestion.emoji` through to the new `Category` record.

### Edit Dialogs — `lib/components/popups/category_form_dialog.dart`, `lib/components/popups/add_sub_category_dialog.dart`

- Add a single `TextField` ("Emoji") next to the existing "Name" field. Use `maxLength: 8` (allows ZWJ sequences); show the current emoji as the initial value; show an inline preview next to the input.
- On save: validate the input (non-empty, contains at least one emoji codepoint); if invalid or empty → coerce to `'🏷️'`. Persist via the existing repository update path.
- Disable the field for the Uncategorized (id=1) category, consistent with existing "not editable" behavior.

### Render Sites — `lib/components/category_widget.dart`, `lib/components/record_widget.dart`, `lib/components/suggestion_banner.dart`

- **`CategoryWidget`**: prefix the existing "Icon Container" with the emoji as a leading `Text` at font size 20. Keep the directional arrow (↗/↙) since it conveys income/expense direction, not category — they are complementary signals. (Alternative: replace the arrow icon with the emoji and move direction to the typeLabel color. We prefer keeping both — minimal risk.)
- **`RecordWidget`**: prefix the category-name subtitle with `'${category.emoji} '` so it renders as e.g. `🍔 Food & Drink • Cash`.
- **`SuggestionBanner`**: the banner already displays `widget.suggestion.message` — the server-controlled italic string. Two paths:
  - (a) Server includes the emoji inline in `message` (`"Should I create a new one called 🚌 'Commute'?"`) — preferred, zero client change.
  - (b) Client renders `suggestion.emoji` separately as a leading glyph.
  - **Pick (a)**: the message is server-generated and already shapes the suggestion phrasing; adding the emoji glyph there keeps the client display layer simple. The client persists the standalone `emoji` field on confirm regardless.

### Tests

- **Model round-trip** (`test/models/category_test.dart`, `test/models/suggested_category_test.dart`): `toMap`/`fromMap`/`fromJson` with and without emoji, fallback to `🏷️` for null/empty.
- **Migration** (`test/services/record_migration_service_test.dart`): create a v9 DB with seed categories, run `addEmojiColumn`, assert (i) column exists, (ii) seed rows have curated emoji, (iii) running it again is a no-op.
- **Repository** (`test/repositories/record_repository_test.dart`): create a fresh DB at v10, assert seed categories have curated emojis, assert a user-created category default is `🏷️`.
- **UI smoke** (`test/components/category_widget_test.dart`, `record_widget_test.dart`): emoji renders next to name; fallback `🏷️` renders when emoji is empty (shouldn't happen but guard).
- **E2E** (`tests/e2e/epic_category_icons/`): upgrade-from-v9 path — open the app on a v9 DB, verify all categories have an emoji after migration.

## Traceability Matrix

| PRD Requirement                                              | Epic Coverage                                                                | Task(s) | Verification                                                         |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------- | ------- | -------------------------------------------------------------------- |
| FR-1: Add `emoji` field to Category model and schema         | §Technical Approach / Data Layer (model, schema, seed)                       | T1      | Unit: model round-trip + repository v10 seed test                    |
| FR-2: Server returns emoji on `SuggestedCategory`            | §Technical Approach / Server                                                 | T2      | Server unit tests: AI valid output → emoji; AI invalid → fallback 🏷️ |
| FR-3: Client parses and persists the suggested emoji         | §Technical Approach / Client Suggestion Pipeline                             | T3      | Unit: `SuggestedCategory.fromJson` + confirm-flow test               |
| FR-4: Category edit dialog supports emoji input              | §Technical Approach / Edit Dialogs                                           | T4      | Widget test: enter emoji → save → repository called with emoji       |
| FR-5: Render emoji in all category-display sites             | §Technical Approach / Render Sites                                           | T5      | Widget test on each site; manual visual QA                           |
| FR-6: Migration backfill is idempotent and one-time          | §AD-2, §Technical Approach / Data Layer (migration_service)                  | T1      | Migration test: run twice → no overwrites; v9→v10 backfill correct   |
| NFR-1: Validation and fallback                               | §AD-4 (both sides)                                                           | T1, T2, T3, T4 | Tests covering invalid AI output and empty client input         |
| NFR-2: No performance regression on Categories/Records tab   | §Render Sites (emoji is plain `Text`, no asset/async)                        | T5      | Dev-profiler trace before/after on RecordsTab (QA pass)              |
| NFR-3: Cross-platform rendering parity                       | §Render Sites; fallback 🏷️ is U+1F3F7 (Unicode 7+)                          | T5      | Manual QA on iOS + Android                                           |
| NTH-1: AI suggests emoji when user renames a category        | Deferred to follow-up                                                        | —       | —                                                                    |

## Implementation Strategy

### Phase 1: Foundation (T1, T2)
Add the data column, migration, and seed map (T1) and the server contract change (T2) in parallel. **Exit criterion:** a fresh-install DB has all seed emojis; a v9-upgrade DB has all seed emojis; the server returns `emoji` on every `SuggestedCategory` (including the fallback path).

### Phase 2: Pipeline + UI (T3, T4, T5)
Wire the suggested emoji into the client suggestion pipeline (T3), add the emoji input to the two edit dialogs (T4), and render the emoji at all three sites (T5). T3 depends on T2's JSON shape and T1's model field; T4 and T5 depend on T1 only. T3/T4/T5 can run in parallel once T1 lands. **Exit criterion:** AI-suggested emoji is persisted on confirm; users can edit any category's emoji; all three render sites show the emoji.

### Phase 3: Verification (folded into T5)
Run the dev profiler on RecordsTab/CategoriesTab for NFR-2; manual visual QA across iOS + Android for NFR-3. No separate task — these are checklist items inside T5.

## Task Breakdown

##### T1: Add emoji column, migration, and seed map
- **Phase:** 1 | **Parallel:** yes (with T2) | **Est:** 1d | **Depends:** — | **Complexity:** moderate
- **What:** Add `String emoji` (default `'🏷️'`) to `Category` model (`toMap`/`fromMap`/`copyWith`). Bump `_dbVersion` 9→10 in `record_repository.dart`. Add `emoji TEXT NOT NULL DEFAULT '🏷️'` to `_onCreate`'s Category DDL. Update `_seedDatabase` to insert the curated emoji per AD-5's map. Add `RecordMigrationService.addEmojiColumn(db)` mirroring `addOccurredAtColumn` (idempotent column check + ALTER + guarded UPDATE per seed). Wire it in `_onUpgrade` via `if (oldVersion < 10)`.
- **Key files:** `lib/models/category.dart`, `lib/repositories/record_repository.dart`, `lib/services/record_migration_service.dart`, `test/models/category_test.dart`, `test/services/record_migration_service_test.dart`, `test/repositories/record_repository_test.dart`
- **PRD requirements:** FR-1, FR-6
- **Key risk:** SQLite cannot ALTER a NOT NULL column without a default; we use a constant default so this is safe, but the migration test must explicitly cover the "v9 seed row with default 🏷️ gets backfilled" case to prove the WHERE-guard does not silently skip rows.
- **Interface produces:** `Category` model with `emoji` field (for T3, T4, T5); a v10 DB with curated emojis (for T5 manual QA and E2E).

##### T2: Server `SuggestedCategory.emoji` + validation
- **Phase:** 1 | **Parallel:** yes (with T1) | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** In `../chatbot-flow-server/` (wallyai scope only), extend the `SuggestedCategory` JSON output schema with `emoji`. Update the category-detection prompt to ask the LLM for a single emoji glyph and include one in the in-prompt example. Add a validation step: trim AI output, accept only if 1 grapheme + ≤8 codepoints + contains at least one emoji codepoint; else rewrite to `'🏷️'`. Update WalletAI suggestion tests on the server with valid + invalid AI output cases; verify existing `name`/`type` contract is unchanged.
- **Key files:** server files for the WalletAI `SuggestedCategory` schema, prompt, and validator (paths per `../chatbot-flow-server/docs/features/`).
- **PRD requirements:** FR-2, NFR-1 (server side)
- **Key risk:** Prompt change regresses the existing `name`/`type` extraction. Mitigation: keep the new field strictly additive; add a regression test that asserts the existing fields' values on a known input.
- **Interface produces:** A `SuggestedCategory` JSON object that always includes a non-empty `emoji` (real or `'🏷️'`) (for T3).

##### T3: Parse server emoji on client and persist on confirm
- **Phase:** 2 | **Parallel:** yes (with T4, T5) | **Est:** 0.5d | **Depends:** T1, T2 | **Complexity:** simple
- **What:** In `lib/models/suggested_category.dart`, add `final String emoji;` and read `json['emoji']` in `fromJson` with the same `'🏷️'` fallback. Update the suggestion-confirm flow in `lib/providers/chat_provider.dart` (the helper that resolves or creates a `Category` from a `SuggestedCategory`) so the resolved/created `Category` carries `suggestion.emoji`. Update `test/models/suggested_category_test.dart` for valid + missing + empty emoji cases.
- **Key files:** `lib/models/suggested_category.dart`, `lib/providers/chat_provider.dart`, `test/models/suggested_category_test.dart`
- **PRD requirements:** FR-3, NFR-1 (client side)
- **Key risk:** The "resolve by name or create" helper currently doesn't take an emoji — adding the parameter must not break existing call sites that don't have a suggested emoji (default to `'🏷️'`).
- **Interface receives from T1:** `Category` constructor accepts `emoji`. **Interface receives from T2:** server JSON includes `emoji` field.

##### T4: Emoji input in category form dialogs
- **Phase:** 2 | **Parallel:** yes (with T3, T5) | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Add a single `TextField` labeled "Emoji" to both `category_form_dialog.dart` and `add_sub_category_dialog.dart`, placed next to the existing "Name" field. `maxLength: 8`, initial value = current emoji. Show a live preview adjacent to the input. On save, validate (non-empty + contains at least one emoji codepoint); if invalid → coerce to `'🏷️'`. Persist via the existing repository update path. Disable the field for the Uncategorized category (id=1). Add widget tests covering: enter emoji → save → category persisted; clear → save → coerced to `'🏷️'`.
- **Key files:** `lib/components/popups/category_form_dialog.dart`, `lib/components/popups/add_sub_category_dialog.dart`, `test/components/popups/category_form_dialog_test.dart`
- **PRD requirements:** FR-4
- **Key risk:** OS emoji keyboard discoverability on Android — users may not realize they should switch to the emoji key. Mitigation: the live emoji preview adjacent to the field acts as a hint; if QA finds this insufficient we add `emoji_picker_flutter` in a follow-up (per AD-3).
- **Interface receives from T1:** `Category.copyWith(emoji: ...)`.

##### T5: Render emoji in CategoryWidget, RecordWidget, SuggestionBanner
- **Phase:** 2 | **Parallel:** yes (with T3, T4) | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** In `CategoryWidget`, prepend a leading `Text(category.emoji, style: TextStyle(fontSize: 20))` before the existing icon container; keep the direction arrow. In `RecordWidget`, prefix the category-name subtitle with `'${category.emoji} '` (final string e.g. `🍔 Food & Drink • Cash`). In `SuggestionBanner`, no client change needed — the server message string carries the emoji inline (per Render Sites decision). Widget tests for each site. Manual QA pass: capture dev-profiler frame times on RecordsTab + CategoriesTab before/after (NFR-2 ≤5ms regression target); visual QA on iOS + Android for NFR-3 parity (no tofu/missing-glyph). Update `docs/features/category-icons.md` and `project_context/architecture.md` per the Living Docs mandate.
- **Key files:** `lib/components/category_widget.dart`, `lib/components/record_widget.dart`, `lib/components/suggestion_banner.dart`, `test/components/category_widget_test.dart`, `test/components/record_widget_test.dart`, `docs/features/category-icons.md`, `project_context/architecture.md`
- **PRD requirements:** FR-5, NFR-2, NFR-3
- **Key risk:** First-frame regression on RecordsTab (paginated list) if emoji rendering forces a reflow. Mitigation: emoji is rendered as a normal `Text` widget at a known font size — no async, no asset, no layout thrash; profiler trace confirms the ≤5ms budget.
- **Interface receives from T1:** `Category.emoji` is populated for all rows.

## Risks & Mitigations

| Risk                                                                            | Severity | Likelihood | Impact                                                                              | Mitigation                                                                                                                                                                  |
| ------------------------------------------------------------------------------- | -------- | ---------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AI returns invalid emoji (text, multi-emoji, missing field)                     | High     | High       | Empty/garbage strings render in UI, breaking visual consistency                     | AD-4: server-side validation + grapheme count + emoji-range check; client-side defensive fallback in `SuggestedCategory.fromJson`. Both sides covered by unit tests.        |
| Server prompt change regresses existing `name`/`type` suggestion contract       | Medium   | Medium     | AI stops returning correct name/type; category suggestions break across the app    | T2 keeps the change strictly additive; explicit regression test asserts existing fields on known input; staged server deploy if possible.                                   |
| Migration ALTER fails on a corrupted/partial v9 DB                              | Medium   | Low        | App crashes on launch for affected users                                            | Mirror `addOccurredAtColumn`'s `PRAGMA table_info` guard + DEFAULT-on-ADD; sqflite's `onUpgrade` runs in a transaction so a crash rolls back to v9 and next launch retries. |
| `redesign-ui` epic is in flight (working-tree changes), not yet merged          | Medium   | High       | `RecordWidget`/`SuggestionBanner`/`CategoryWidget` integration surface shifts mid-build | Treat redesign-ui as a hard predecessor: start this epic only after redesign-ui's widgets are merged to `main`. If redesign-ui rolls back, revisit T5's render-site paths. |
| Cross-platform emoji parity (iOS Apple Color Emoji vs Android Noto)             | Low      | High       | Visual differences between platforms                                                | Per PRD: accept platform-native rendering. The only hard requirement is no missing-glyph "tofu" — fallback 🏷️ is Unicode 7+, universally supported.                        |
| Sub-category seed backfill identifies the wrong rows (matches by name+parent)   | Medium   | Low        | Wrong emoji applied or none applied                                                 | Migration test asserts exact emoji per (name, parent_id) pair on a v9 seed snapshot. The `WHERE emoji = '🏷️'` guard prevents overwriting any user-set value.               |

## Dependencies

- **`chatbot-flow-server` (WalletAI prompt + `SuggestedCategory`)** — Owner: same team — Status: pending (T2). The category-detection prompt and JSON schema must add `emoji` + validation. Blocks T3.
- **`redesign-ui` epic** — Owner: same team — Status: backlog (per `.claude/epics/redesign-ui/epic.md`) but working-tree changes are pending commit (per git status). **The PRD declares it "completed (recently merged)" — this epic assumes the redesigned `CategoryWidget`, `RecordWidget`, `SuggestionBanner` are the integration surface.** Confirm redesign-ui is merged to `main` before starting T5.
- **No new pub.dev package.** AD-3 explicitly defers `emoji_picker_flutter`. If post-launch UX testing requires it, add as a follow-up.

## Success Criteria (Technical)

| PRD Criterion                                                                                       | Technical Metric                                                                                                   | Target                          | How to Measure                                                                                                       |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| All categories render an emoji within 1 launch of the upgrade                                       | `SELECT COUNT(*) FROM Category WHERE emoji IS NULL OR emoji = ''` post-migration                                   | `= 0`                           | E2E test in `tests/e2e/epic_category_icons/` running migration on a v9 seeded DB; dev-mode assertion in `init` flow. |
| AI-suggested emoji is accepted by users in ≥80% of confirmations                                    | Manual beta review of ≥100 confirmations, sampled from beta channel                                                | ≥ 80% non-edited within 24h     | Out-of-band qualitative review post-launch (no analytics package added).                                             |
| No reported "missing icon / broken emoji" issues from beta users                                    | Beta-channel issue count in the 14 days post-launch                                                                | `= 0` qualifying issues         | Manual triage of beta feedback channel; tag template emoji-related issues.                                           |
| Categories tab and Records tab first-frame render time does not regress beyond 5ms                  | Flutter dev profiler trace, average over 10 cold opens, with/without this epic                                     | `Δ ≤ 5ms`                       | Capture profiler trace before merging T5; record results in `tests/integration/epic_category_icons/perf-notes.md`.   |

## Estimated Effort

- **Total work:** ~4 dev-days across 5 tasks.
- **Critical path:** T1 (1d) → T3 (0.5d) — 1.5 days minimum.
- **Parallelism:** T1 ‖ T2 in Phase 1; T3 ‖ T4 ‖ T5 in Phase 2 once T1 (and T2 for T3) lands.
- **Calendar:** With one engineer working serially: ~4 days. With server change picked up in parallel: ~3 days.

## Deferred / Follow-up

- **NTH-1: AI suggests an emoji on rename.** Defer. The user can already pick from the OS keyboard; adding a server round-trip to the edit dialog is a marginal benefit. Revisit if user feedback shows post-rename emojis are usually wrong.
- **In-app emoji picker grid.** Defer per Out-of-Scope and AD-3. Add `emoji_picker_flutter` only if QA on T4 shows the plain TextField is unclear.
- **Emoji on `MoneySource`, `Record`, or other models.** Defer per Out-of-Scope. Sources keep their existing visuals.
- **New-user persona story (orphan flagged in PRD validation).** Persona is implicitly served by T1's seed backfill and T5's render — no separate work needed in this epic.
- **Custom Material icon library.** Permanently out of scope per PRD.
- **Per-category color picker.** Permanently out of scope per PRD.

## Tasks Created
| #   | Task                                                                              | Phase | Parallel | Est. | Depends On         | Status |
| --- | --------------------------------------------------------------------------------- | ----- | -------- | ---- | ------------------ | ------ |
| 211 | Add emoji column, migration & curated seed map                                    | 1     | yes      | 1d   | —                  | open   |
| 212 | Server SuggestedCategory.emoji + validation (wallyai)                             | 1     | yes      | 0.5d | —                  | open   |
| 213 | Parse server emoji on client and persist on confirm                               | 2     | yes      | 0.5d | 211, 212           | open   |
| 214 | Emoji input in category form dialogs                                              | 2     | yes      | 1d   | 211                | open   |
| 215 | Render emoji in CategoryWidget/RecordWidget/SuggestionBanner + perf/visual + docs | 2     | yes      | 1d   | 211                | open   |
| 216 | Integration verification & cleanup                                                | 3     | no       | 0.5d | 211, 212, 213, 214, 215 | open |

### Summary
- **Total tasks:** 6
- **Parallel tasks:** 5 (001‖002 in Phase 1; 010‖011‖012 in Phase 2)
- **Sequential tasks:** 1 (090 — final integration gate)
- **Estimated total effort:** ~4.5 dev-days
- **Critical path:** 001 → 010 → 090 (~2 days minimum; 002 in parallel with 001 so doesn't extend it)

### Dependency Graph
```
#211 (foundation) ──┬─→ #213 ─→ #216
                    ├─→ #214 ─→ #216
                    └─→ #215 ─→ #216
#212 (server)     ──→ #213 ─→ #216
```

Critical path: **#211 → #213 → #216** (~2 days). Parallelism upside: with two engineers, Phase 1 (#211‖#212) finishes in 1 day; Phase 2 (#213‖#214‖#215) finishes in 1 day; Phase 3 (#216) in 0.5 day = **~2.5 days calendar** vs. 4.5 dev-days of work.

### PRD Coverage
| PRD Requirement                                 | Covered By    | Status     |
| ----------------------------------------------- | ------------- | ---------- |
| FR-1: Add emoji to Category model/schema        | #211          | ✅ Covered  |
| FR-2: Server returns emoji on SuggestedCategory | #212          | ✅ Covered  |
| FR-3: Client parses + persists suggested emoji  | #213          | ✅ Covered  |
| FR-4: Category edit dialogs support emoji input | #214          | ✅ Covered  |
| FR-5: Render emoji in all category-display sites | #215         | ✅ Covered  |
| FR-6: Migration backfill is idempotent          | #211          | ✅ Covered  |
| NFR-1: Validation + fallback (both sides)       | #212, #213, #214 | ✅ Covered |
| NFR-2: No ≥5ms render regression                | #215          | ✅ Covered  |
| NFR-3: Cross-platform emoji parity              | #215          | ✅ Covered  |
| NTH-1: AI suggests emoji on rename              | —             | Deferred   |
