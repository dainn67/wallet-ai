---
epic: suggest-category
phase: A
generated: 2026-04-05T17:03:06Z
assessment: EPIC_READY
quality_score: 4.5/5
total_issues: 7
closed_issues: 6
open_issues: 1
---

# Epic Verification Report: suggest-category
## Phase A: Semantic Review

**Generated:** 2026-04-05T17:03:06Z
**Epic:** suggest-category
**Total Issues:** 7 (Closed: 6 task issues, Open: 1 epic tracker #160)
**Overall Assessment:** 🟢 EPIC_READY
**Quality Score:** 4.5/5

---

### Analysis 1: Coverage Matrix

Mapping PRD functional requirements (source of truth) to implementing issues.

| # | Acceptance Criteria | Issue(s) | Status | Evidence |
|---|---------------------|----------|--------|----------|
| FR-1 | Parse `suggested_category` from record JSON when `category_id == -1`; store as transient; silently ignore malformed | #163, #161 | ✅ | chat_provider.dart +2 lines: `categoryId == -1 ? SuggestedCategory.fromJson(item['suggested_category']) : null`. `SuggestedCategory.fromJson` try-catch validates name/type. 5 new stream-parsing tests in chat_provider_test.dart |
| FR-2 | `SuggestedCategory` data class + transient `suggestedCategory` field on `Record`; excluded from `toMap/fromMap`; `copyWith` reset via `clearSuggestedCategory` flag | #161 | ✅ | `lib/models/suggested_category.dart` (34 lines, const ctor, defensive fromJson). `record.dart` +7 lines: nullable field, copyWith flag (AD-4). 15 tests (toMap exclusion, fromMap null, copyWith clear/passthrough) |
| FR-3 | Banner widget rendered as sibling beneath each record card with `suggestedCategory != null`; shows message, name+type, Confirm/Cancel; hidden during stream | #164, #165 | ✅ | `lib/components/suggestion_banner.dart` (164 lines, StatefulWidget, `_isProcessing` guard). `chat_bubble.dart` switched `.map` → `.expand` emitting `[RecordWidget, SuggestionBanner?]`; gated on `suggestedCategory != null && categoryId == -1` (AD-3). 9 widget tests |
| FR-4 | Confirm: resolve-or-create category, reassign record, update in-memory message state, clear suggestion; name-exists de-dup; parent_id validation with top-level fallback | #162, #165 | ✅ | `RecordProvider.resolveCategoryByNameOrCreate` (record_provider.dart:288, 44 lines): case-insensitive name+parentId match, parent existence check with fallback to -1 (record_provider.dart:299-305), returns new id from `db.insert`. Wired in chat_bubble._handleConfirm: resolve → updateRecord → updateMessageRecord with `clearSuggestedCategory: true`. 7 provider tests |
| FR-5 | Cancel clears banner via `copyWith(clearSuggestedCategory: true)` passed to `chatProvider.updateMessageRecord`; no DB write; no category created | #165 | ✅ | chat_bubble._handleCancel (sync, calls updateMessageRecord only). No recordProvider interaction. Covered indirectly by widget tests (cancel fires callback, no provider touched) |
| NFR-1 | No regression on existing record parsing | #161, #163, #166 | ✅ | `toMap`/`fromMap` left unchanged (AD-1); 178 tests pass (6 failures all pre-existing and unrelated per #166 summary); no changes to Record DB column set |
| NFR-2 | No crash on malformed/absent `suggested_category` | #161, #163, #166 | ✅ | `SuggestedCategory.fromJson(dynamic json)` try/catch + validates non-empty name + type in {expense,income}. Tests: missing name → null, string-valued json → null, mixed batch → no crash |
| NFR-3 | Confirm/Cancel idempotent (double-tap guard) | #164 | ✅ | `SuggestionBanner._isProcessing` flag; Confirm shows spinner and `onPressed: null` while processing; re-enabled on error. Test: "double-tap guard fires confirm exactly once" |

**Coverage:** 8/8 criteria fully covered. Out-of-scope item NTH-1 (editable name) correctly deferred per PRD.

---

### Analysis 2: Gap Report

**No Critical or High gaps identified.** Minor items below.

**Gap #1: E2E confirm-flow integration test absent**
- Category: 1 (Integration Gap)
- Severity: Low
- Related issues: #165, #166
- Description: `chat_bubble._handleConfirm` composes 3 provider calls (resolveCategoryByNameOrCreate → updateRecord → updateMessageRecord). Each is unit-tested in isolation, but no test exercises the full sequence with a real ChangeNotifier stack. Widget test for SuggestionBanner only verifies callback firing.
- Evidence: `test/components/suggestion_banner_test.dart` tests the banner widget's callback contract only. `chat_bubble.dart._handleConfirm` (lines added in commit 7a608e4) has no dedicated test. #166 handoff explicitly documents: "ChatProvider._handleStream is a private method; tests exercise it indirectly via sendMessage".
- Recommendation: Add one widget/integration test that pumps a ChatBubble with a live RecordProvider+ChatProvider, taps Confirm, and asserts DB write + in-memory state update. Deferrable to Phase B.
- Estimated effort: Small

**Gap #2: Epic-level handoff notes file contains stale content**
- Category: 5 (Quality Gap)
- Severity: Low
- Related issues: all
- Description: `.claude/context/handoffs/latest.md` still contains the previous epic's handoff (`suggested-prompts` / T4 tests). Task subagents did not write fresh handoffs during epic-run execution.
- Evidence: Input-assembly output `06-handoff-notes.md` shows only the TEMPLATE + the old `suggested-prompts` latest.md content.
- Recommendation: Process-only finding — does not block epic acceptance. Consider updating epic-run prompt to enforce handoff writes.
- Estimated effort: Small

**Gap #3: ChatProvider stream tests may rely on public `sendMessage` path**
- Category: 5 (Quality Gap)
- Severity: Low
- Related issues: #163, #166
- Description: 5 new stream-parse tests live in `test/providers/chat_provider_test.dart` (+178 lines), driving through the public API. This matches the codebase's established pattern per #166 summary, but provides indirect coverage of the 2-line parse change.
- Evidence: #166 summary note: "ChatProvider._handleStream is a private method; the tests exercise it indirectly via sendMessage, which is the established pattern in this codebase."
- Recommendation: Accept as conforming to codebase convention. No action required.
- Estimated effort: N/A

**Gap #4: `_isProcessing` guard does not reset on Cancel tap**
- Category: 5 (Quality Gap)
- Severity: Low
- Related issues: #164
- Description: The banner's double-tap guard only applies to Confirm. If a user taps Confirm and before the async chain completes somehow also taps Cancel (impossible in current UI because banner rebuilds), the state handling is untested. Banner is removed after either action via `updateMessageRecord`, so race is benign.
- Evidence: `suggestion_banner.dart` _isProcessing is toggled only around Confirm.
- Recommendation: Accept — the banner disappears on either action via parent rebuild, eliminating the race.
- Estimated effort: N/A

---

### Analysis 3: Integration Risk Map

| Dependency | Interface | Risk | Notes |
|---|---|---|---|
| #163 → #161 | `Record.suggestedCategory` field + `SuggestedCategory.fromJson` | 🟢 Low | Types defensive; cherry-pick verified clean; 5 parse tests pass |
| #164 → #161 | `SuggestedCategory` data class | 🟢 Low | Used only to read fields (name, type, parentId, message); const value object |
| #165 → #161 | `Record.copyWith(clearSuggestedCategory:)` | 🟢 Low | New flag has default=false; existing copyWith callers unaffected |
| #165 → #162 | `RecordProvider.resolveCategoryByNameOrCreate(name,type,parentId) → Future<int?>` | 🟢 Low | Returns nullable; _handleConfirm correctly null-checks before updateRecord |
| #165 → #164 | `SuggestionBanner(record, messageId, suggestion, onConfirm, onCancel)` constructor | 🟢 Low | Callback-driven; no provider coupling in widget |
| #165 → ChatProvider.updateMessageRecord (existing) | Pre-existing API at chat_provider.dart:265 | 🟢 Low | Already in use for streaming; no signature change |
| #162 → RecordRepository.createCategory | Returns `int` from `db.insert` (sqflite) | 🟢 Low | No signature change required per PRD Assumption |

**Overall integration risk:** 🟢 Low across all edges. The epic layered cleanly without interface churn.

---

### Analysis 4: Quality Scorecard

| Criteria | Score | Rationale |
|---|---|---|
| Requirements Coverage | 5 | 5/5 FR + 3/3 NFR fully implemented, cited, and tested |
| Implementation Completeness | 5 | All code paths (happy + malformed + parent-fallback + dedup + cancel) have production code |
| Test Coverage | 4 | 29 epic-specific tests across 5 files; E2E confirm-flow test absent (Gap #1); pattern follows codebase convention |
| Integration Confidence | 5 | All interfaces documented in AD-1..4; dependencies unidirectional; analyzer clean |
| Documentation Quality | 4 | `docs/features/suggest-category.md` + `project_context/` updated; 4 ADRs present; individual task handoffs not written (Gap #2) |
| Regression Risk | 4 | `toMap`/`fromMap` untouched; NFR-1 satisfied; 6 pre-existing test failures unchanged; minor risk from `.expand` ordering in chat_bubble |
| **Average Score** | **4.5/5** | Strong epic with minor quality-process items |

---

### Analysis 5: Recommendations

**Overall Assessment:** 🟢 **EPIC_READY**

All 8 criteria (5 FR + 3 NFR) are covered with production code + tests. No critical/high gaps. Four low-severity quality items are non-blocking. Proceed to Phase B for integration test verification.

**Specific actions:**
1. [LOW] Add E2E confirm-flow widget test (Gap #1) — can be written in Phase B
2. [LOW] Epic process improvement: enforce handoff writes in epic-run (Gap #2) — out-of-scope for this epic
3. [ACCEPTED] Indirect stream-parse tests (Gap #3) — conforms to codebase convention
4. [ACCEPTED] Cancel double-tap (Gap #4) — benign race

**New issues to create:** None blocking. Optionally a follow-up issue for the E2E confirm-flow test.

---

### Analysis 6: Phase B Preparation

**E2E Test Scenarios to write:**

| # | Scenario | User Flow | Modules involved | Priority |
|---|---|---|---|---|
| 1 | Unclassified record shows banner | Send "50k Netflix" → stream completes → banner appears under record | ChatProvider, Record, SuggestionBanner, chat_bubble | High |
| 2 | Confirm creates category + reassigns | Tap Confirm on banner → new Category persisted → record.categoryId updated → banner gone | RecordProvider, ChatProvider, chat_bubble._handleConfirm | High |
| 3 | Cancel clears banner, no DB write | Tap Cancel → banner gone, record.categoryId still -1, no new Category | ChatProvider, chat_bubble._handleCancel | High |
| 4 | Duplicate-name dedup | Confirm suggestion where name matches existing → reuses existing categoryId, no INSERT | RecordProvider.resolveCategoryByNameOrCreate | Medium |
| 5 | Parent-fallback on schema drift | Suggestion with parent_id not in cache → category created at top level (-1) | RecordProvider.resolveCategoryByNameOrCreate | Medium |
| 6 | Multiple records in one message with mixed suggestions | Two records, one classified one not → only the unclassified shows banner | chat_bubble.expand branch | Medium |
| 7 | Malformed suggested_category JSON | Stream returns record with `suggested_category: "bad"` → record saved, no banner, no crash | ChatProvider.sendMessage, SuggestedCategory.fromJson | High |

**Integration Test Points:**
- ChatProvider ↔ Record: stream-complete path attaches SuggestedCategory only when categoryId==-1
- SuggestionBanner ↔ chat_bubble: Confirm/Cancel callbacks trigger provider wiring correctly
- RecordProvider ↔ RecordRepository: createCategory returns row id via sqflite; cache refresh after insert
- chat_bubble._handleConfirm ↔ RecordProvider+ChatProvider: composed 3-call chain with `context.mounted` check across await

**Smoke Test Checklist:**
- [ ] Run `fvm flutter analyze` — 0 new issues on epic files
- [ ] Run `fvm flutter test test/models/suggested_category_test.dart test/models/record_test.dart` — all green
- [ ] Run `fvm flutter test test/providers/chat_provider_test.dart test/providers/record_provider_test.dart test/components/suggestion_banner_test.dart` — all green
- [ ] Run full `fvm flutter test` — verify no new regressions (6 pre-existing failures acceptable)
- [ ] Manual: launch app, send "50k Netflix", observe banner, tap Confirm, verify category appears in Categories tab
- [ ] Manual: send same message again, tap Confirm again, verify no duplicate Streaming category
- [ ] Manual: send unclassifiable message, tap Cancel, verify record remains Uncategorized
