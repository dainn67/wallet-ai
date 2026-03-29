---
name: refactor-code
status: completed
created: 2026-03-28T17:46:23Z
updated: 2026-03-29T04:32:29Z
completed: 2026-03-29T04:32:29Z
progress: 100%
priority: P1
prd: .claude/prds/refactor-code.md
task_count: 8
github: "https://github.com/dainn67/wallet-ai/issues/136"
---

# Epic: refactor-code

## Overview

We are enforcing clean architecture across the wallet-ai codebase by fixing layer violations, extracting business logic from UI, consolidating redundant provider patterns, and standardizing coding style. The codebase is ~44 Dart files with a clear Provider/Repository/Service foundation that just needs consistent enforcement. The biggest concrete violation found: `ChatProvider` directly instantiates `RecordRepository` to save records from chat, completely bypassing `RecordProvider`. The approach is surgical — three sequential phases (providers → UI extraction → style/structure), each ending with `flutter analyze` and a smoke test, with per-phase commits for targeted rollback.

## Architecture Decisions

### AD-1: Keep single RecordProvider as data gateway
**Context:** ChatProvider currently bypasses RecordProvider by instantiating RecordRepository directly (chat_provider.dart:133). Need to decide how chat-created records flow through the system.
**Decision:** Route all record creation through RecordProvider. ChatProvider already holds a reference to RecordProvider (`_recordProvider`), so call `_recordProvider.addRecord()` instead of `RecordRepository().createRecord()`.
**Alternatives rejected:** Creating a separate ChatRecordProvider — adds complexity for no benefit since RecordProvider already handles all record CRUD.
**Trade-off:** ChatProvider becomes more coupled to RecordProvider, but this is the intended architecture (providers orchestrate, repos are internal).
**Reversibility:** Easy — single method call change.

### AD-2: Extract CRUD boilerplate via private helper in RecordProvider
**Context:** RecordProvider has 9 CRUD methods that all follow the same pattern: set loading → try → operation → loadAll/update state → catch → debugPrint/toast → finally → unset loading → notifyListeners → _updateWidget. Inconsistent: Record CRUD uses `debugPrint`, Category CRUD uses `ToastService().showError()`.
**Decision:** Extract a private `_performOperation(Future<void> Function() operation, {bool showToastOnError = false})` helper that handles the boilerplate. Standardize error handling to `debugPrint` + optional toast.
**Alternatives rejected:** Base class/mixin — overkill for a single provider with internal repetition.
**Trade-off:** Slightly more abstract internal code, but 9 methods reduced to ~3 lines each.
**Reversibility:** Easy — inline the helper back if needed.

### AD-3: Move inline widgets to separate component files
**Context:** `ChatBubble` (68 lines) and `_StreamingIndicator` (17 lines) are defined inside `chat_tab.dart`. `_showAddSubCategoryDialog` (65 lines) is an inline dialog in `categories_tab.dart`. These inflate tab files and blur the line between screen and component.
**Decision:** Extract `ChatBubble` to `lib/components/chat_bubble.dart`, `_StreamingIndicator` to stay private in chat_tab (too small to extract). Extract sub-category dialog to `lib/components/popups/add_sub_category_dialog.dart`.
**Alternatives rejected:** Keeping everything inline — violates FR-5 (files in correct layer).
**Trade-off:** More files, but each file has single responsibility.
**Reversibility:** Easy — just move code back.

### AD-4: Standardize import ordering convention
**Context:** Files use mixed styles — some use package imports (`package:wallet_ai/...`), others use relative (`../`). No consistent grouping.
**Decision:** All files use package imports for cross-directory references. Relative imports only within the same directory. Group order: `dart:` → `package:flutter/` → `package:third_party/` → `package:wallet_ai/` → relative. Blank line between groups.
**Alternatives rejected:** All-relative imports — harder to read across directories. All-package — verbose for same-directory.
**Trade-off:** Slightly more verbose, but consistent and grep-able.
**Reversibility:** Easy — find-and-replace.

## Technical Approach

### Provider & Data Layer

**ChatProvider fix (chat_provider.dart):**
- Remove `import 'package:wallet_ai/repositories/record_repository.dart'` (line 6)
- Remove `final recordRepository = RecordRepository()` (line 133)
- Replace `await recordRepository.createRecord(record)` with `await _recordProvider!.addRecord(record)` — but since `addRecord` calls `loadAll()` internally, we need a variant that returns the created record ID. Add a `createRecord(Record)` method to RecordProvider that returns `Future<int>` for this case.
- This is the critical FR-1 violation.

**RecordProvider cleanup (record_provider.dart):**
- Extract CRUD boilerplate into `_performOperation()` private helper
- Remove `fetchData()` alias (line 177) — it's redundant with `loadAll()`
- Standardize error handling: all operations use `debugPrint` for logging; category operations additionally use `ToastService` since they face user-visible validation errors
- Move `_calculateCategoryTotals()` and `_updateWidget()` logic — these are internal and correctly placed, just need consistent style

**LocaleProvider (locale_provider.dart):**
- Already clean. Only change: standardize import ordering.

### UI Logic Extraction

**RecordsTab (records_tab.dart:22-24):**
- Lines 22-24 compute `totalIncome`, `totalExpense`, `totalBalance` inline in build(). These are business logic (filtering + aggregation).
- Move to computed getters on RecordProvider: `filteredTotalIncome`, `filteredTotalExpense`, `totalBalance`.

**CategoriesTab (categories_tab.dart):**
- `_updateMonth()` (lines 11-18) — date manipulation logic → move to a method on RecordProvider
- `_showAddSubCategoryDialog()` (lines 33-97) — inline dialog → extract to `lib/components/popups/add_sub_category_dialog.dart`

**ChatTab (chat_tab.dart):**
- Extract `ChatBubble` class to `lib/components/chat_bubble.dart` — it's a reusable component with its own build logic and popup handling
- `_StreamingIndicator` stays — it's tiny and private, only used here

### File Structure & Style

**Import standardization:** Apply AD-4 convention across all ~44 files.

**Barrel file updates:**
- `helpers/helpers.dart` — missing export for `currency_helper.dart` (currently only exports `api_helper.dart`)
- `components/components.dart` — add export for new `chat_bubble.dart` and `popups/add_sub_category_dialog.dart`
- All other barrel files are currently accurate

**File placement audit against layer mapping table:**
- `ChatBubble` currently in `screens/home/tabs/chat_tab.dart` → move to `components/chat_bubble.dart`
- Sub-category dialog currently inline → extract to `components/popups/add_sub_category_dialog.dart`
- All other files are correctly placed

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
|-----------------|---------------|---------|--------------|
| FR-1: Provider-only repository access | §Provider & Data Layer / ChatProvider fix | T1 | `grep -r "import.*repositories" lib/screens/ lib/components/` returns 0 |
| FR-2: Extract business logic from UI | §UI Logic Extraction / RecordsTab + CategoriesTab | T3, T4 | Manual audit of build() methods |
| FR-3: Consolidate redundant provider logic | §Provider & Data Layer / RecordProvider cleanup | T2 | Manual audit — no duplicate methods |
| FR-4: Standardize coding style | §File Structure & Style + Provider cleanup | T2, T6 | Checklist: error handling pattern, import ordering |
| FR-5: Align file structure | §File Structure & Style + UI extraction | T4, T5, T7 | Barrel file check + layer mapping audit |
| FR-6: Preserve all behavior | All tasks | T1-T8 | `flutter analyze` + manual smoke test per phase |
| NFR-1: Zero regressions | All tasks | T8 | Full manual walkthrough |
| NFR-2: Startup time | All tasks | T8 | `flutter run --profile` baseline comparison |
| NFR-3: Max 400 lines/file | Provider cleanup + extraction | T2, T4 | `wc -l` check |
| NTH-1: Doc comments on providers | Deferred | — | — |
| NTH-2: Private method naming | Deferred | — | — |

## Implementation Strategy

### Phase 1: Provider & Data Layer (T1, T2)
**What:** Fix ChatProvider's direct repository access. Clean up RecordProvider boilerplate and inconsistent error handling.
**Why first:** This is the highest-risk, highest-impact work. All UI extraction in Phase 2 depends on clean providers.
**Exit criterion:** `flutter analyze` passes. `grep -r "import.*repositories" lib/providers/chat_provider.dart` returns 0 repository imports in ChatProvider (it should only access via RecordProvider). Manual test: create record via chat → record appears in records tab. Manual test: all CRUD operations (records, categories, sources) work.

### Phase 2: UI Logic Extraction (T3, T4, T5)
**What:** Move business logic out of RecordsTab/CategoriesTab build methods. Extract ChatBubble to component. Extract sub-category dialog to popup.
**Why second:** Depends on clean provider interfaces from Phase 1. These are mechanical moves with lower risk.
**Exit criterion:** `flutter analyze` passes. `grep -r "import.*repositories" lib/screens/ lib/components/` returns 0. No inline aggregation/filtering in build() methods. Manual test: all tabs render correctly, popups work.

### Phase 3: File Structure & Style (T6, T7, T8)
**What:** Standardize imports, update barrel files, final audit.
**Why last:** Cosmetic changes that touch every file — doing them last avoids merge conflicts with Phase 1-2 changes.
**Exit criterion:** `flutter analyze` passes. All barrel files match directory contents. Import ordering consistent. `wc -l` — no file exceeds 400 lines. Full manual walkthrough passes.

## Task Breakdown

##### T1: Fix ChatProvider direct repository access
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** moderate
- **What:** Remove direct `RecordRepository` usage from ChatProvider's `onDone` handler (line 133-161). Add a `createRecord(Record)` method to RecordProvider that returns `Future<int>` (the inserted ID) so ChatProvider can use it. Update ChatProvider to call `_recordProvider!.createRecord(record)` instead. Remove the repository import from chat_provider.dart.
- **Key files:** `lib/providers/chat_provider.dart`, `lib/providers/record_provider.dart`
- **PRD requirements:** FR-1, FR-6
- **Key risk:** Chat record creation flow is complex (streaming → parse JSON → create records in loop → update message with record IDs). Must preserve the loop that creates multiple records and collects their IDs.
- **Interface produces:** `RecordProvider.createRecord(Record) → Future<int>` method for T2 to consolidate.

##### T2: Clean up RecordProvider — extract boilerplate, standardize error handling
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Extract the repetitive CRUD boilerplate (loading state, try-catch, notifyListeners, _updateWidget) into a private `_performOperation()` helper. Remove the `fetchData()` alias. Standardize error handling: use `debugPrint` everywhere + `ToastService` only for category operations where user sees errors. Ensure all CRUD methods follow the same flow.
- **Key files:** `lib/providers/record_provider.dart`
- **PRD requirements:** FR-3, FR-4, FR-6
- **Key risk:** The subtle differences between CRUD methods (addMoneySource partially updates state locally vs reloading, updateMoneySource patches list vs reloading) must be preserved. Don't unify behavior that's intentionally different.
- **Interface receives from T1:** New `createRecord()` method to include in consolidation.

##### T3: Extract business logic from RecordsTab and CategoriesTab
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T2 | **Complexity:** simple
- **What:** Move `totalIncome`/`totalExpense`/`totalBalance` calculations from RecordsTab build() (lines 22-24) to computed getters on RecordProvider. Move `_updateMonth()` date manipulation from CategoriesTab to a method on RecordProvider (e.g., `navigateMonth(int delta)`). Update tabs to use the new provider getters/methods.
- **Key files:** `lib/providers/record_provider.dart`, `lib/screens/home/tabs/records_tab.dart`, `lib/screens/home/tabs/categories_tab.dart`
- **PRD requirements:** FR-2, FR-6
- **Key risk:** `totalBalance` is computed from all moneySources (not filtered), while `totalIncome`/`totalExpense` use `filteredRecords`. Must preserve this distinction.

##### T4: Extract ChatBubble to separate component file
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1 | **Complexity:** simple
- **What:** Move the `ChatBubble` class (lines 150-222 of chat_tab.dart) to `lib/components/chat_bubble.dart`. Update imports in chat_tab.dart. Add export to components.dart barrel file. ChatBubble accesses RecordProvider and ChatProvider via context.read — this is acceptable for a popup-triggering component per the PRD layer mapping rules.
- **Key files:** `lib/screens/home/tabs/chat_tab.dart`, `lib/components/chat_bubble.dart` (new), `lib/components/components.dart`
- **PRD requirements:** FR-5, FR-6
- **Key risk:** ChatBubble uses `_showEditRecordPopup` which accesses providers. Ensure the method works correctly when ChatBubble is in a different file (it should — it uses `context.read` which traverses the widget tree).

##### T5: Extract sub-category dialog to popup component
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Extract `_showAddSubCategoryDialog()` from CategoriesTab (lines 33-97) into `lib/components/popups/add_sub_category_dialog.dart` as a standalone dialog widget or a `showAddSubCategoryDialog()` function. Update CategoriesTab to call the extracted version. Add export to components.dart.
- **Key files:** `lib/screens/home/tabs/categories_tab.dart`, `lib/components/popups/add_sub_category_dialog.dart` (new), `lib/components/components.dart`
- **PRD requirements:** FR-5, FR-6
- **Key risk:** The dialog reads `RecordProvider` and `LocaleProvider` via `context.read` — ensure the extracted version receives context correctly (either via function parameter or by being a widget that reads providers itself).

##### T6: Standardize import ordering across all files
- **Phase:** 3 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1-T5 | **Complexity:** simple
- **What:** Apply AD-4 import convention to all ~44 Dart files: `dart:` → `package:flutter/` → `package:third_party/` → `package:wallet_ai/` → relative imports. Blank line between groups. Use package imports for cross-directory references, relative only within same directory. Fix mixed styles (e.g., chat_provider.dart uses relative `../configs/configs.dart` while others use package).
- **Key files:** All `.dart` files in `lib/`
- **PRD requirements:** FR-4, FR-6
- **Key risk:** Import changes should be purely cosmetic but could break if a file path is wrong. `flutter analyze` catches this immediately.

##### T7: Update barrel files and verify file placements
- **Phase:** 3 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T4, T5 | **Complexity:** simple
- **What:** Fix `helpers/helpers.dart` — add missing `export 'currency_helper.dart'`. Add new file exports to `components/components.dart` (chat_bubble.dart, add_sub_category_dialog.dart). Verify all barrel files match their directory contents. Audit each file against the layer mapping table — confirm no misplacements.
- **Key files:** `lib/helpers/helpers.dart`, `lib/components/components.dart`, all other barrel files
- **PRD requirements:** FR-5, FR-6
- **Key risk:** Adding `currency_helper.dart` to barrel file could surface unused import warnings elsewhere. Check with `flutter analyze`.

##### T8: Final audit — flutter analyze, line counts, smoke test
- **Phase:** 3 | **Parallel:** no | **Est:** 0.5d | **Depends:** T6, T7 | **Complexity:** simple
- **What:** Run `flutter analyze` — must be zero errors. Run `wc -l lib/**/*.dart | sort -rn` — no file exceeds 400 lines. Run `grep -r "import.*repositories" lib/screens/ lib/components/` — must return 0. Manual walkthrough of all screens: chat (send message, see records), records tab (filter, edit, delete), categories tab (add/edit/delete, sub-categories, month navigation), drawer (language, currency, reset). Compare with pre-refactor behavior.
- **Key files:** All `lib/` files
- **PRD requirements:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, NFR-1, NFR-2, NFR-3
- **Key risk:** Regression found during walkthrough requires targeted fix and re-test.

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
|------|----------|------------|--------|------------|
| ChatProvider record creation breaks after removing direct repo access | High | Medium | Chat records not saved to DB | T1: Test immediately after change — send a chat message that generates records, verify they appear in records tab |
| RecordProvider CRUD boilerplate extraction changes subtle behavior differences | High | Medium | addMoneySource/updateMoneySource have intentionally different reload vs local-update patterns | T2: Map each method's current behavior before extracting; preserve per-method differences in the helper |
| Extracting ChatBubble breaks provider context access | Medium | Low | Edit record popup fails from chat | T4: ChatBubble uses context.read which traverses widget tree — works regardless of file location. Test edit flow. |
| Import reordering breaks builds | Low | Low | Compilation errors | T6: Run `flutter analyze` after each batch of files |
| record-provider epic overlap | Medium | Medium | Conflicting changes to record_provider.dart | Coordinate: complete this refactor first since record-provider epic is still in backlog |

## Dependencies

- **record-provider epic (backlog)** — Both touch `record_provider.dart`. This refactor should complete first since it restructures the file. Owner: self. Status: pending — recommend completing refactor-code before starting record-provider.
- **setup-font epic (done)** — No conflict. Status: resolved.

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
|---------------|-----------------|--------|----------------|
| Zero repository imports in UI | grep across screens/ + components/ | 0 matches | `grep -r "import.*repositories" lib/screens/ lib/components/` |
| Zero inline business logic in build() | Manual code review of all build() methods | No filtering, aggregation, or validation inline | Checklist per file |
| No duplicate provider methods | RecordProvider method count + review | No method pairs that do the same thing; `fetchData()` removed | Code review |
| Consistent coding style | Import ordering + error handling pattern | All files follow AD-4; all provider errors use debugPrint pattern | `flutter analyze` + checklist |
| All barrel files up-to-date | Barrel file exports vs directory contents | 1:1 match | Script: compare exports to `ls *.dart` per directory |
| All files in correct layer | File placement vs layer mapping table | 0 misplacements | Manual audit against table |
| No file exceeds 400 lines | Line count check | Max ≤400 | `wc -l lib/**/*.dart \| sort -rn \| head -5` |
| Zero behavior regressions | Full manual walkthrough | All features work identically | Test plan: chat, records, categories, drawer, widget |
| Startup time | Profile run comparison | Within ±10% of baseline | `flutter run --profile` before/after |

## Estimated Effort

- **Total:** ~4.5 days
- **Critical path:** T1 → T2 → T3 (sequential) = 2 days
- **Phase 1:** 1.5 days (T1 + T2, sequential)
- **Phase 2:** 1 day (T3 + T4 + T5, parallelizable)
- **Phase 3:** 1 day (T6 + T7 parallel, then T8 sequential)

## Deferred / Follow-up

- **NTH-1: Doc comments on provider public methods** — Deferred to keep this epic focused on structure, not documentation. Can be a quick follow-up task.
- **NTH-2: Private method naming convention** — Deferred. The refactored private methods from T2 will already follow a consistent naming pattern, but a full audit of all private methods across all files is out of scope.
- **RecordRepository splitting** — At 513 lines (will remain the largest file), record_repository.dart could be split into separate files per entity (RecordDao, MoneySourceDao, CategoryDao). Deferred as it's architectural redesign, not structural cleanup.
