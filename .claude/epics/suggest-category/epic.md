---
name: suggest-category
status: backlog
created: 2026-04-05T16:13:56Z
updated: 2026-04-05T16:24:09Z
progress: 0%
priority: P1
prd: .claude/prds/suggest-category.md
task_count: 6
github: https://github.com/dainn67/wallet-ai/issues/160
---

# Epic: suggest-category

## Overview

The server already ships `suggested_category` per-record in the normal conversation response; the Flutter client currently ignores it. We close this gap with the minimum surface area: add a transient `SuggestedCategory` field on `Record` (NOT persisted to SQLite), extend `ChatProvider._handleStream` to parse it from each record JSON, add a thin `resolveCategoryByNameOrCreate` helper on `RecordProvider` to side-step the "`addCategory` returns void" problem, and render a new `SuggestionBanner` widget as a sibling to each `RecordWidget` inside `chat_bubble.dart`. This is deliberately a 1-file-per-layer change — no new provider, no new table, no schema migration. The hardest part is getting the new category's `categoryId` back after `addCategory` (existing API returns void), which we solve with a name-lookup helper that also enforces the "no duplicate" guarantee from FR-4.

## Architecture Decisions

### AD-1: Transient field on `Record`, not separate provider state
**Context:** The `suggested_category` data is per-record and needs to flow from chat parse → UI banner → confirm/cancel action. It could live on `Record`, in a parallel map in `ChatProvider`, or in a new provider.
**Decision:** Add a nullable `suggestedCategory` field on `Record` that is NEVER passed through `toMap()`/`fromMap()`. Mutation is in-memory only via `copyWith`.
**Alternatives rejected:**
- Parallel `Map<int, SuggestedCategory>` in `ChatProvider`: requires keying by `recordId` which is 0 until DB insert; fragile during the stream-complete → DB-insert → UI-render window.
- New `SuggestionProvider`: over-engineered for 5 requirements; extra wiring in `main.dart` MultiProvider.
**Trade-off:** The `Record` model gains one session-only concern (minor model bloat). In exchange, the data stays co-located with the record it belongs to, `updateMessageRecord` already propagates it, and no new provider is needed.
**Reversibility:** Easy — field can be removed or lifted into a separate store later without schema changes.

### AD-2: `resolveCategoryByNameOrCreate` helper on `RecordProvider`
**Context:** `RecordProvider.addCategory(Category)` returns `Future<void>` — the caller cannot know the new `categoryId`. FR-4 requires re-assigning the record to the new category, and FR-4's duplicate guard requires reusing an existing category with the same name.
**Decision:** Add `Future<int?> resolveCategoryByNameOrCreate(String name, String type, int parentId)` on `RecordProvider`. It first searches the cached `_categories` by (name+parentId), returns the existing `categoryId` if found, otherwise calls `_repository.createCategory` directly and returns the new ID from the repository (sqflite `insert` returns the row id). It then refreshes the in-memory cache.
**Alternatives rejected:**
- Change `addCategory` signature to return `int`: breaks existing callers (`CategoryFormDialog`, `add_sub_category_dialog`).
- Query `_categories` by name *after* `addCategory` completes: fragile (what if two operations fire concurrently?) and couples the call site to the provider's internal refresh timing.
**Trade-off:** One new provider method vs. breaking the existing `addCategory` contract. Provider remains the single access point to the repository (preserves AD-1 from record-provider epic).
**Reversibility:** Easy — delete the method if a future refactor changes `addCategory`.

### AD-3: `SuggestionBanner` as sibling widget in `chat_bubble.dart`
**Context:** Where should the banner live in the widget tree? Inside `RecordWidget` or as a sibling?
**Decision:** New stateless `SuggestionBanner` widget, rendered as a sibling to `RecordWidget` inside the record mapping in `chat_bubble.dart:78`. Each record that has `suggestedCategory != null` emits `[RecordWidget, SuggestionBanner]`; records without suggestion emit only `[RecordWidget]`.
**Alternatives rejected:**
- Put banner inside `RecordWidget`: couples record rendering to suggestion logic; makes `RecordWidget` aware of providers (currently dumb display widget).
- Group-level banner at the bottom of the chat bubble: violates FR-3 "beneath that record card" and breaks multi-record messages with mixed suggestions.
**Trade-off:** A second widget file, but `RecordWidget` stays a presentation-only widget and each banner is independently actionable.
**Reversibility:** Easy — swap widget or lift into `RecordWidget` later.

### AD-4: `copyWith` nullable-reset for `suggestedCategory`
**Context:** Dart `copyWith` with nullable parameters cannot distinguish "don't change" from "set to null" using the standard `value ?? this.value` idiom. After confirm/cancel we need to clear the suggestion to hide the banner.
**Decision:** Use a sentinel-parameter approach: add a `bool clearSuggestedCategory = false` flag to `Record.copyWith`. When true, `suggestedCategory` is set to `null` regardless of the passed value.
**Alternatives rejected:**
- Use the "wrap in Object()" sentinel trick: clever but unfamiliar to contributors.
- Mutate `Record` in place: violates immutability convention in the codebase.
**Trade-off:** One extra boolean param on `copyWith` vs. a cleaner clearing semantic. Easy to read.
**Reversibility:** Easy — swap technique later without call-site churn if the flag is used only in 1-2 places.

## Technical Approach

### Model Layer (`lib/models/`)

**New file: `lib/models/suggested_category.dart`**
- Simple data class: `name: String`, `type: String`, `parentId: int`, `message: String`
- Factory `SuggestedCategory.fromJson(Map<String, dynamic> json)` with try-catch returning `null` on malformed input (NFR-2)
- Validates required fields (`name` non-empty, `type` in `{expense, income}`); returns `null` if invalid

**Modified: `lib/models/record.dart`**
- Add nullable `final SuggestedCategory? suggestedCategory` field
- Constructor: add optional `this.suggestedCategory`
- `toMap()`: unchanged — never includes `suggestedCategory`
- `fromMap()`: unchanged — `suggestedCategory` defaults to `null`
- `copyWith`: add `SuggestedCategory? suggestedCategory` param + `bool clearSuggestedCategory = false` param; result is `clearSuggestedCategory ? null : (suggestedCategory ?? this.suggestedCategory)`

**Modified: `lib/models/models.dart`** (barrel file)
- Export `suggested_category.dart`

### Parsing Layer (`lib/providers/chat_provider.dart`)

**Modified: `ChatProvider._handleStream` (line ~195)**
- In the `for (var item in recordsJson)` loop, after extracting existing fields, extract `item['suggested_category']` via `SuggestedCategory.fromJson` (returns `null` if absent/malformed)
- Pass to `Record(...)` constructor as `suggestedCategory: parsedSuggestion`
- Record is still saved via `_recordProvider!.createRecord(record)` with `categoryId: -1` (or whatever the server returned)

**No new fields added to ChatProvider state** — suggestion lives on `Record` inside `ChatMessage.records`.

### Category Resolution (`lib/providers/record_provider.dart`)

**New method: `Future<int?> resolveCategoryByNameOrCreate(String name, String type, int parentId)`**
- Search `_categories` for existing category where `c.name.toLowerCase().trim() == name.toLowerCase().trim() && c.parentId == parentId`; if found, return its `categoryId`
- If `parentId != -1`, validate that parent exists in `_categories`; if not, log warning and fall back to `parentId = -1`
- Otherwise: `final newId = await _repository.createCategory(Category(name: name, type: type, parentId: parentId));` — `createCategory` already returns the inserted `int` from sqflite (verify signature; if not, add it)
- Refresh `_categories` cache (same pattern as `addCategory` via `_performOperation`)
- Return `newId`
- On error: show toast (existing pattern) and return `null`

**Verification needed:** Read `_repository.createCategory` signature. If it currently returns void, this task includes changing it to return the inserted row id (sqflite `db.insert` already returns the id — it's just not propagated).

### UI Layer (`lib/components/`)

**New file: `lib/components/suggestion_banner.dart`**
- Stateful widget (needs to disable Confirm button on tap to prevent double-fire — NFR-3)
- Constructor params: `Record record`, `String messageId`, `SuggestedCategory suggestion`
- Layout: Card with `message` text, category name + type badge, Confirm button (primary), Cancel button (secondary)
- Confirm handler:
  1. `setState(() => _isProcessing = true)` to disable button
  2. `final newId = await recordProvider.resolveCategoryByNameOrCreate(suggestion.name, suggestion.type, suggestion.parentId)`
  3. If newId is null → toast already shown, re-enable button, return
  4. `final updatedRecord = record.copyWith(categoryId: newId, clearSuggestedCategory: true)`
  5. `await recordProvider.updateRecord(updatedRecord)`
  6. `chatProvider.updateMessageRecord(messageId, updatedRecord)` — triggers UI rebuild
- Cancel handler:
  1. `final updatedRecord = record.copyWith(clearSuggestedCategory: true)`
  2. `chatProvider.updateMessageRecord(messageId, updatedRecord)` — banner disappears; no DB write

**Modified: `lib/components/chat_bubble.dart:78`**
- Change record mapping: for each record, emit `RecordWidget(record: record)` followed by `SuggestionBanner(...)` if `record.suggestedCategory != null`
- The `messageId` needs to be available in the builder (already is — `message.id`)

### State Flow

```
1. Server returns record JSON with suggested_category
2. ChatProvider._handleStream parses → Record with suggestedCategory
3. Record saved to DB via createRecord (categoryId: -1, suggestedCategory stays in-memory on the returned object)
4. records list populated; _messages[index].copyWith(records: records); notifyListeners()
5. chat_bubble.dart rebuilds → renders RecordWidget + SuggestionBanner for each record with suggestion
6. User taps Confirm → resolveCategoryByNameOrCreate → updateRecord → updateMessageRecord
7. ChatMessage.records now has record with categoryId: newId, suggestedCategory: null
8. chat_bubble.dart rebuilds → SuggestionBanner is gone (suggestedCategory is null); RecordWidget shows new category name via RecordProvider.getCategoryName
```

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --- | --- | --- | --- |
| FR-1: Parse `suggested_category` | §Parsing Layer | T2 | Unit test on `_handleStream` with/without/malformed JSON |
| FR-2: Transient `SuggestedCategory` on `Record` | §Model Layer + AD-1 + AD-4 | T1 | Unit test: `toMap()` excludes field; `fromMap()` returns null |
| FR-3: Render suggestion banner | §UI Layer + AD-3 | T4, T5 | Widget test: banner renders, visibility toggles on state |
| FR-4: Confirm creates + re-assigns | §Category Resolution + §UI Layer + AD-2 | T3, T5 | Unit test: new/existing/subcategory paths in resolveCategoryByNameOrCreate |
| FR-5: Cancel clears banner | §UI Layer | T5 | Widget test: cancel clears suggestion without DB write |
| NTH-1: Editable name | Deferred | — | — |
| NFR-1: No regression | §Parsing Layer (additive only) | T2, T6 | `fvm flutter test` passes with no new failures |
| NFR-2: No crash on malformed JSON | §Model Layer (`SuggestedCategory.fromJson` try-catch) | T1, T2 | Unit test injects malformed payload |
| NFR-3: Idempotent confirm/cancel | §UI Layer (`_isProcessing` guard) | T4 | Widget test: rapid double-tap fires 1 DB write |

## Implementation Strategy

### Phase 1: Foundation (Model + Resolver)
**What:** T1 (SuggestedCategory model + Record.copyWith) and T3 (resolveCategoryByNameOrCreate).
**Why first:** All other tasks depend on these types/methods existing. The two are independent of each other and can run in parallel.
**Exit:** `SuggestedCategory` class exists, `Record` has the transient field + clearing semantic, `RecordProvider.resolveCategoryByNameOrCreate` returns an int by name-lookup or create.

### Phase 2: Core (Parsing + UI)
**What:** T2 (parse from chat stream) and T4 (SuggestionBanner widget).
**Why:** These are the two consumer sides of Phase 1. Can run in parallel — they touch different files.
**Exit:** Chat stream parses `suggested_category` into `Record.suggestedCategory`; `SuggestionBanner` renders standalone with test harness state.

### Phase 3: Integration + Verification
**What:** T5 (wire banner into `chat_bubble.dart`, hook up Confirm/Cancel) and T6 (tests + docs).
**Why:** Integration must come last — it depends on T2+T4. T6 closes the loop with end-to-end verification and living-docs updates.
**Exit:** All PRD scenarios verified with unit/widget tests; living docs updated; `fvm flutter test` green.

## Task Breakdown

##### T1: Add `SuggestedCategory` model + transient field on `Record`
- **Phase:** 1 | **Parallel:** yes | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Create `lib/models/suggested_category.dart` with fields (name, type, parentId, message) and a defensive `fromJson` factory that returns `null` on malformed input (missing/empty `name`, invalid `type`). Add nullable `suggestedCategory` field to `Record`, thread through constructor and `copyWith` including a `bool clearSuggestedCategory = false` flag (AD-4). Explicitly do NOT add the field to `toMap()` or `fromMap()` (AD-1). Export from `lib/models/models.dart`.
- **Key files:** `lib/models/suggested_category.dart` (new), `lib/models/record.dart`, `lib/models/models.dart`
- **PRD requirements:** FR-2, NFR-2
- **Key risk:** `copyWith` signature change may silently miss callers that currently reset other nullable fields; grep for all `.copyWith(` usages on Record.
- **Interface produces:** `SuggestedCategory` class + `Record.suggestedCategory` field + `clearSuggestedCategory` flag for T2, T4, T5.

##### T2: Parse `suggested_category` in ChatProvider stream handler
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1 | **Complexity:** simple
- **What:** In `ChatProvider._handleStream`'s `onDone` record loop (around line 195 of `chat_provider.dart`), call `SuggestedCategory.fromJson(item['suggested_category'])` and pass the result to `Record(...)`. Wrap in try/catch to honor NFR-2 — malformed payload is silently ignored. The record is still saved via `createRecord` with whatever `category_id` the server sent.
- **Key files:** `lib/providers/chat_provider.dart`
- **PRD requirements:** FR-1, NFR-1, NFR-2
- **Key risk:** `item['suggested_category']` may be present but not a Map (e.g., null, string, array) — `fromJson` must tolerate any JSON type.
- **Interface receives from T1:** `SuggestedCategory.fromJson` factory.

##### T3: Add `resolveCategoryByNameOrCreate` to `RecordProvider`
- **Phase:** 1 | **Parallel:** yes | **Est:** 0.5d | **Depends:** — | **Complexity:** moderate
- **What:** Add `Future<int?> resolveCategoryByNameOrCreate(String name, String type, int parentId)` to `RecordProvider`. Implementation: case-insensitive name+parentId lookup in `_categories` → return existing ID if found; else call `_repository.createCategory(...)` which must return the new row id (verify/adjust `RecordRepository.createCategory` signature — sqflite `insert` returns `int` already). Refresh `_categories` cache after create. Validate `parentId != -1` refers to an existing top-level category; fall back to `-1` with a debugPrint warning if not. Show toast + return null on error.
- **Key files:** `lib/providers/record_provider.dart`, `lib/repositories/record_repository.dart` (verify/adjust return type of `createCategory`)
- **PRD requirements:** FR-4 (duplicate guard, schema drift fallback)
- **Key risk:** `RecordRepository.createCategory` may currently return void — changing it affects `addCategory` caller. Keep the old `addCategory` working by just ignoring the returned int at the old call site.
- **Interface produces:** `resolveCategoryByNameOrCreate(name, type, parentId) → Future<int?>` for T5.

##### T4: Build `SuggestionBanner` widget
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Create `lib/components/suggestion_banner.dart` as a `StatefulWidget` (state needed for the `_isProcessing` double-tap guard — NFR-3). Props: `record`, `messageId`, `suggestion`, plus callbacks `onConfirm` and `onCancel` (so unit testing doesn't need provider context). Layout: Card with `suggestion.message` text, a category chip showing `suggestion.name` + type badge (red for expense / green for income), and two buttons (Confirm primary, Cancel secondary). Confirm tap sets `_isProcessing = true`, awaits `onConfirm`, re-enables on error. Use existing design tokens (Color(0xFF6366F1) primary, rounded 12px corners — match `CategoryFormDialog`).
- **Key files:** `lib/components/suggestion_banner.dart` (new)
- **PRD requirements:** FR-3, NFR-3
- **Key risk:** Visual inconsistency with existing record cards; match padding/margin of `RecordWidget`.
- **Interface produces:** `SuggestionBanner(record, messageId, suggestion, onConfirm, onCancel)` widget for T5.

##### T5: Integrate banner into chat bubble + wire Confirm/Cancel
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Depends:** T2, T3, T4 | **Complexity:** moderate
- **What:** Modify `lib/components/chat_bubble.dart` at line 78 to emit a `SuggestionBanner` sibling after each `RecordWidget` where `record.suggestedCategory != null`. Inside `chat_bubble.dart`, define the onConfirm handler: call `recordProvider.resolveCategoryByNameOrCreate(...)` → if non-null, build `record.copyWith(categoryId: newId, clearSuggestedCategory: true)` → `recordProvider.updateRecord(updated)` → `chatProvider.updateMessageRecord(message.id, updated)`. Define onCancel: `record.copyWith(clearSuggestedCategory: true)` → `chatProvider.updateMessageRecord(message.id, updated)` (no DB write).
- **Key files:** `lib/components/chat_bubble.dart`
- **PRD requirements:** FR-3, FR-4, FR-5
- **Key risk:** `chat_bubble.dart` may not currently have provider access; verify via `context.read<RecordProvider>()` / `context.read<ChatProvider>()` at the integration point. Also: `updateMessageRecord` uses `recordId` to find the record in the list, but records from chat have `recordId` set only after `createRecord` completes — verify the ID is populated by the time the banner fires.
- **Interface receives from T2:** `Record.suggestedCategory` populated from stream.
- **Interface receives from T3:** `resolveCategoryByNameOrCreate` on RecordProvider.
- **Interface receives from T4:** `SuggestionBanner` widget.

##### T6: Tests + living docs update
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Depends:** T5 | **Complexity:** moderate
- **What:** Unit tests for `SuggestedCategory.fromJson` (valid/missing/malformed), `Record.copyWith` (nullable reset + pass-through), `ChatProvider._handleStream` (record w/ suggestion, record w/o, mixed batch), `resolveCategoryByNameOrCreate` (new / existing by name / subcategory / schema-drift fallback). Widget test for `SuggestionBanner` (renders, double-tap fires once, confirm/cancel callbacks). Update `docs/features/suggest-category.md` (new — technical overview, flow diagram, response format), `project_context/context.md` (Logic Locations entry), `project_context/architecture.md` (Record model notes transient field).
- **Key files:** `test/models/suggested_category_test.dart`, `test/models/record_test.dart`, `test/providers/chat_provider_test.dart`, `test/providers/record_provider_test.dart`, `test/components/suggestion_banner_test.dart`, `docs/features/suggest-category.md` (new), `project_context/context.md`, `project_context/architecture.md`
- **PRD requirements:** NFR-1, NFR-2, NFR-3, all Success Criteria verification
- **Key risk:** Provider mock setup for `resolveCategoryByNameOrCreate` tests — follow existing pattern from `chat_provider_test.dart` using mocktail.

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| `RecordRepository.createCategory` returns void — cannot get new ID | High | High | FR-4 (reclassify) blocked | T3 adjusts signature to return `int` from sqflite `insert`; old `addCategory` call sites just ignore the return |
| `Record.copyWith` nullable reset semantics silently breaks existing callers | High | Med | Existing code paths set null unintentionally | T1 adds a separate `bool clearSuggestedCategory = false` flag rather than sentinel tricks; existing callers unchanged |
| Record has `recordId: 0` at the moment the banner fires (before DB insert completes) | Med | Med | `updateMessageRecord` can't find the record to update | `ChatProvider._handleStream` already awaits `createRecord(record)` and uses `record.copyWith(recordId: recordId)` before adding to records list (line 221) — verify and document |
| User scrolls past banner or navigates away mid-stream, banner shows briefly for streaming messages | Low | Low | UI flicker | FR-3 scenario: suggestion state is only set after stream completes (onDone); won't render during streaming |
| `parent_id` from server references a categoryId that doesn't exist locally | Low | Low | Category created at wrong hierarchy level | T3's fallback: validate parent exists; if not, create at top level with debug log |
| `suggestedCategory` field on Record leaks into test fixtures / debug logs / JSON encoders | Low | Med | Debug noise, confusing test output | T1 keeps `toMap()` untouched; `toString()` unchanged — no other serialization paths exist |

## Dependencies

- **`RecordProvider.addCategory`, `updateRecord`, `_categories` cache** — `lib/providers/record_provider.dart` — **resolved**
- **`ChatProvider.updateMessageRecord`** — `lib/providers/chat_provider.dart:265` — **resolved**
- **`chat_bubble.dart` record rendering** — `lib/components/chat_bubble.dart:78` — **resolved**
- **`RecordRepository.createCategory` signature** — `lib/repositories/record_repository.dart` — **pending verification in T3**; adjust return type to `int` if currently void
- **Category model + sub-category support** — `lib/models/category.dart` — **resolved** (parentId column already exists in DB schema)

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
| --- | --- | --- | --- |
| Functional coverage | % of records with `categoryId == -1 && suggestedCategory != null` that render banner | 100% | Widget test iterating a mixed-batch message; QA |
| Create accuracy | `recordProvider.categories.length` delta per Confirm | +1 (new name) or 0 (existing name) | Unit test on `resolveCategoryByNameOrCreate` |
| No regression | Existing unit + widget test count pass | 0 new failures | `fvm flutter test` |
| Graceful failure | Crashes on malformed `suggested_category` JSON | 0 | Unit test with 5+ malformed payloads |
| Duplicate guard | New categories after confirming 2 suggestions with same name | 1 | Unit test on `resolveCategoryByNameOrCreate` |
| Cancel purity | `updateRecord` and `addCategory` calls during Cancel | 0 | Mocktail `verifyNever` in widget test |
| Idempotency | `resolveCategoryByNameOrCreate` calls after double-tap Confirm | 1 | Widget test firing two rapid taps |

## Estimated Effort

- **Total:** ~3.5 developer-days
- **Critical path:** T1 → T2 → T5 → T6 ≈ 3 days (T3, T4 run in parallel with T2 in Phase 1-2)
- **Phase timeline:**
  - Phase 1 (Foundation): 0.5d (T1 and T3 in parallel)
  - Phase 2 (Core): 1d (T2 and T4 in parallel, T4 is the long pole)
  - Phase 3 (Integration+Verify): 2d (T5 sequential, then T6)

## Deferred / Follow-up

- **NTH-1 Editable suggested name**: Follow-up epic. Add an edit-icon to `SuggestionBanner` that swaps the name chip for an inline `TextField` pre-filled with `suggestion.name`. Low priority — server-generated names are typically usable as-is.

## Tasks Created

| #   | Task                                                    | Phase | Parallel | Est.  | Depends On        | Status |
| --- | ------------------------------------------------------- | ----- | -------- | ----- | ----------------- | ------ |
| 001 | SuggestedCategory model + transient field on Record     | 1     | yes      | 0.5d  | —                 | open   |
| 002 | resolveCategoryByNameOrCreate helper on RecordProvider  | 1     | yes      | 0.5d  | —                 | open   |
| 010 | Parse suggested_category in ChatProvider stream handler | 2     | yes      | 0.5d  | 001               | open   |
| 011 | Build SuggestionBanner widget                           | 2     | yes      | 1d    | 001               | open   |
| 020 | Integrate banner into chat_bubble + wire Confirm/Cancel | 3     | no       | 1d    | 010, 011, 002     | open   |
| 090 | Tests + living docs update + integration verification   | 3     | no       | 1d    | 001,002,010,011,020 | open |

### Summary
- **Total tasks:** 6
- **Parallel tasks:** 4 (001, 002, 010, 011)
- **Sequential tasks:** 2 (020, 090)
- **Estimated total effort:** ~4d
- **Critical path:** 001 → 010 → 020 → 090 (~3d)

### Dependency Graph
```
001 (parallel) ──→ 010 (parallel) ──→ 020 ──→ 090
001 (parallel) ──→ 011 (parallel) ──→ 020
002 (parallel) ──────────────────────→ 020
```

### PRD Coverage
| PRD Requirement | Covered By   | Status     |
| --------------- | ------------ | ---------- |
| FR-1: Parse suggested_category | 010, 090 | ✅ Covered |
| FR-2: Transient SuggestedCategory on Record | 001, 090 | ✅ Covered |
| FR-3: Render suggestion banner | 011, 020, 090 | ✅ Covered |
| FR-4: Confirm creates + re-assigns | 002, 020, 090 | ✅ Covered |
| FR-5: Cancel clears banner | 020, 090 | ✅ Covered |
| NFR-1: No regression | 090 | ✅ Covered |
| NFR-2: No crash on malformed JSON | 001, 010, 090 | ✅ Covered |
| NFR-3: Idempotent confirm/cancel | 011, 020, 090 | ✅ Covered |
| NTH-1: Editable name | — | ⏭️ Deferred |
