---
name: category-filter
status: completed
created: 2026-04-25T11:50:25Z
updated: 2026-04-27T10:00:00Z
progress: 100%
priority: P1
prd: .claude/prds/category-filter.md
task_count: 4
tasks_decomposed: true
github: https://github.com/dainn67/wallet-ai/issues/187
---

# Epic: category-filter

## Overview

Four targeted changes across two files and one new widget. The data layer change (T1, T2) is a one-line sort fix and a new in-memory filter method on `RecordProvider` — no new repository queries or DB migrations needed, since `_records` is already fully loaded. The UI layer (T3, T4) adds a `CategoryRecordsBottomSheet` widget that reuses the existing `RecordWidget` and `EditRecordPopup`, and rewires Categories tab tap behavior using Flutter's built-in `InkWell` absorption: setting `CategoryWidget.onTap` to a non-null callback causes its inner `InkWell` to absorb the tap before `ExpansionTile`'s header handler fires, so the expansion chevron can be moved to an `ExpansionTileController`-driven trailing button with no custom state management. The result is four surgical changes with one new widget file.

## Architecture Decisions

### AD-1: In-memory filtering — no new DB query
**Context:** The popup needs records filtered by category id(s) and month.
**Decision:** Filter from `RecordProvider._records` (already loaded in memory) using a new `getRecordsForCategory(categoryIds, dateRange)` method. Reuse the same `_selectedDateRange` the tab already uses.
**Alternatives rejected:** New `RecordRepository` query per popup open — unnecessary round-trip, adds latency, requires new SQL, and the in-memory cache is the source of truth for all other UI views.
**Trade-off:** Minimal latency, zero DB changes. If a user has >10k lifetime records the in-memory filter over all records is still O(n) and completes in <1ms for typical dataset sizes.
**Reversibility:** Easy — method is additive, removal is trivial.

### AD-2: InkWell absorption to decouple row tap from ExpansionTile expansion
**Context:** `ExpansionTile` intercepts header taps to toggle expansion. We need the category row tap to open a popup instead, with expansion moved to a dedicated trailing icon button.
**Decision:** Pass a non-null `onTap` to `CategoryWidget` (its `InkWell` absorbs the tap before `ExpansionTile`'s gesture handler fires). Drive expand/collapse via `ExpansionTileController` wired to a trailing `IconButton`. No modification to `CategoryWidget` required; no custom stateful expansion widget needed.
**Alternatives rejected:** Custom `StatefulWidget` replacing `ExpansionTile` — more lines, loses the built-in expand animation for no gain. `GestureDetector` with `HitTestBehavior.opaque` wrapping the title — fragile layering.
**Trade-off:** Relies on Flutter's documented InkWell hit-test absorption behavior. Reversibility: Easy — revert `onTap` to `null` to restore default expansion.
**Reversibility:** Easy.

### AD-3: Modal bottom-sheet for the records popup
**Context:** PRD says "popup." Category tab is already a full-screen tab; a dialog would feel cramped.
**Decision:** `showModalBottomSheet` with a `DraggableScrollableSheet` containing a `ListView` of `RecordWidget` rows. Grouped by sub-category via a lightweight header `Text` + border `Container`. Reuses `RecordWidget` from `lib/components/record_widget.dart` directly.
**Alternatives rejected:** Full-screen pushed route — heavier navigation for a quick review. `showDialog` — feels out of place for a scrollable list.
**Trade-off:** Bottom-sheet is dismissible by tap-outside and drag-down, which is the expected Flutter idiom. Slightly less real estate than full-screen but sufficient for typical monthly record counts.
**Reversibility:** Easy — swap `showModalBottomSheet` → `Navigator.push` with no logic changes.

## Technical Approach

### Data Layer — RecordProvider

**File:** `lib/providers/record_provider.dart`

**Change 1 — Sort fix (FR-4):**
Line 112-115 currently sorts `filteredRecords` by `recordId DESC`. Replace with `occurredAt DESC`:
```dart
filtered.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
```
`occurredAt` already exists on the `Record` model (int millis, populated since schema v8). No migration needed.

**Change 2 — New filter method (FR-1, FR-2):**
Add `getRecordsForCategory(List<int> categoryIds, DateTimeRange? dateRange)` method that filters `_records` by the provided ids and date range, sorted `occurredAt DESC`. Callers pass either a single-element list `[subId]` or a union list `[parentId, sub1Id, sub2Id, ...]`. The Categories tab builds the id list using the existing `getSubCategories(parentId)`.

```dart
List<Record> getRecordsForCategory(List<int> categoryIds, DateTimeRange? range) {
  final r = range ?? _selectedDateRange;
  return _records.where((rec) {
    if (!categoryIds.contains(rec.categoryId)) return false;
    if (r == null) return true;
    final occurred = DateTime.fromMillisecondsSinceEpoch(rec.occurredAt);
    return !occurred.isBefore(r.start) && !occurred.isAfter(r.end);
  }).toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
}
```

No `notifyListeners` — pure read. Method is called lazily on popup open.

### UI Layer — CategoryRecordsBottomSheet

**New file:** `lib/components/popups/category_records_bottom_sheet.dart`

Accepts:
- `category` (`Category`) — the tapped category (used for title)
- `categoryIds` (`List<int>`) — ids to include (union for parent, single for sub)
- `subCategories` (`List<Category>`) — empty for sub-tap, non-empty for parent-tap (used to build group headers)

Renders:
- A `DraggableScrollableSheet` with `initialChildSize: 0.6`, `maxChildSize: 0.95`
- Header: category name + month label (read from `provider.selectedDateRange`)
- `ListView` of sections:
  - For parent popup: one section per sub-category group + one for parent-direct records. Each section has a header `Text` (sub-category name) and its records wrapped in a `Container` with a `Border`.
  - For sub popup: flat list, no grouping needed.
- Each record row: reuse `RecordWidget` (`lib/components/record_widget.dart`) — check its `onEdit` signature and pass `() => showEditRecordPopup(context, record)` using the existing `EditRecordPopup` (`lib/components/popups/edit_record_popup.dart`).
- After edit saves: `RecordProvider` calls `notifyListeners()`, and the bottom-sheet rebuilds via `Consumer<RecordProvider>`.
- Empty-state: if no records for the scope, show a centered `Text`.

### UI Layer — Categories Tab Rewiring

**File:** `lib/screens/home/tabs/categories_tab.dart`

**Parent rows:**
1. Add `ExpansionTileController _controller = ExpansionTileController()` per parent (use `Map<int, ExpansionTileController>` keyed by `categoryId` at the `build` level, or manage in a `StatefulWidget` if the tab is stateless).
2. `CategoryWidget.onTap: () => _openCategoryPopup(context, category, isParent: true)` — InkWell absorbs tap, ExpansionTile does not toggle.
3. Move expand/collapse to `ExpansionTile(trailing: IconButton(icon: RotatedBox(...), onPressed: () => _controllers[id]!.toggle()))`.
4. Keep `CategoryWidget.onEdit: () => _showEditDialog(context, category)` for the pencil icon (unchanged).

**Sub rows:**
1. `CategoryWidget.onTap: () => _openCategoryPopup(context, sub, isParent: false)`.
2. Add `CategoryWidget.onEdit: () => _showEditDialog(context, sub)` — edit dialog moves to pencil icon (CategoryWidget already renders the pencil icon when `onEdit != null`; sub rows currently omit it).

**`_openCategoryPopup` helper (private method on tab):**
```dart
void _openCategoryPopup(BuildContext context, Category category, {required bool isParent}) {
  final provider = context.read<RecordProvider>();
  final subCats = isParent ? provider.getSubCategories(category.categoryId!) : <Category>[];
  final ids = [category.categoryId!, ...subCats.map((s) => s.categoryId!)];
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => CategoryRecordsBottomSheet(
      category: category,
      categoryIds: ids,
      subCategories: subCats,
    ),
  );
}
```

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Tappable rows open popup | AD-2, Categories Tab Rewiring | T4 | Manual: tap parent + sub, popup opens |
| FR-2: Parent shows union with group borders | CategoryRecordsBottomSheet (grouping logic) | T3 | Manual: parent with 2 subs shows 3 bordered groups |
| FR-3: Edit action on popup rows | CategoryRecordsBottomSheet (RecordWidget + EditRecordPopup) | T3 | Manual: tap edit, form opens; save refreshes popup |
| FR-4: Records tab sorts by occurredAt | RecordProvider.filteredRecords sort key | T1 | Unit test + manual: edit old record, position unchanged |
| NTH-1: Empty state in popup | CategoryRecordsBottomSheet (empty branch) | T3 | Manual: tap category with 0 records this month |
| NFR-1: Popup renders <200ms for 100 records | In-memory filter (AD-1) + plain ListView | T2, T3 | Profile on Galaxy A52 or similar |
| NFR-2: ≤1 new widget file | One new file: category_records_bottom_sheet.dart | T3 | Diff check |

## Implementation Strategy

### Phase 1 — Data (parallel)
**T1** (sort fix) and **T2** (new filter method) — independent, both in `record_provider.dart`. Exit: `fvm flutter test` passes, manual verify Records tab order after editing an old record.

### Phase 2 — Popup Widget
**T3** — builds and tests the bottom-sheet in isolation (can open it from a test button). Depends on T2's method existing. Exit: popup opens with correct grouping, edit round-trip works.

### Phase 3 — Tab Wiring
**T4** — wires the popup into the live Categories tab, rewires expansion. Depends on T3. Exit: full golden path (tap parent → union popup; tap sub → scoped popup; chevron → expand/collapse; edit icon → edit dialog).

## Task Breakdown

##### T1: Fix Records tab sort key
- **Phase:** 1 | **Parallel:** yes | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** In `RecordProvider.filteredRecords` (line 112-115 of `lib/providers/record_provider.dart`), replace `b.recordId.compareTo(a.recordId)` with `b.occurredAt.compareTo(a.occurredAt)`. The `occurredAt` field (int millis) is already on the `Record` model. The popup sort (T3) uses the same key via `getRecordsForCategory`, so both surfaces are consistent.
- **Key files:** `lib/providers/record_provider.dart`
- **PRD requirements:** FR-4
- **Key risk:** None — single-line change. Verify visually that the Records tab still groups correctly by date after the change.
- **Interface produces:** Sorted `filteredRecords` by `occurredAt DESC` — T3/T4 can rely on the same sort convention.

##### T2: Add `getRecordsForCategory` to RecordProvider
- **Phase:** 1 | **Parallel:** yes | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Add `getRecordsForCategory(List<int> categoryIds, DateTimeRange? range)` to `lib/providers/record_provider.dart`. Filters `_records` by `categoryId` membership and optional date range (falls back to `_selectedDateRange`). Returns list sorted `occurredAt DESC`. Pure read, no `notifyListeners`. See exact implementation in Technical Approach → Data Layer.
- **Key files:** `lib/providers/record_provider.dart`
- **PRD requirements:** FR-1, FR-2, NFR-1
- **Key risk:** Verify that records with `categoryId == null` or `-1` (Uncategorized) are handled safely — `contains` on a typed `List<int>` will not match `null`.
- **Interface produces:** `getRecordsForCategory(List<int>, DateTimeRange?)` method — consumed by T3 and T4.

##### T3: Build CategoryRecordsBottomSheet
- **Phase:** 2 | **Parallel:** no | **Est:** 1.5d | **Depends:** T2 | **Complexity:** moderate
- **What:** Create `lib/components/popups/category_records_bottom_sheet.dart`. Accepts `category`, `categoryIds`, `subCategories`. Calls `context.watch<RecordProvider>().getRecordsForCategory(categoryIds, provider.selectedDateRange)` inside `Consumer` so edits auto-refresh. Renders a `DraggableScrollableSheet` (initial 0.6, max 0.95) with grouped sections: for a parent tap, one `Container(decoration: Border(...))` group per sub-category plus one for parent-direct records; for a sub tap, flat list. Each row uses existing `RecordWidget` passing its `onEdit` callback that calls `showModalBottomSheet` again with `EditRecordPopup` (or the existing `showEditRecordPopup` helper if one exists). Empty state: `Center(child: Text(...))`.
- **Key files:** `lib/components/popups/category_records_bottom_sheet.dart` (new), `lib/components/record_widget.dart` (read-only), `lib/components/popups/edit_record_popup.dart` (read-only)
- **PRD requirements:** FR-2, FR-3, NTH-1, NFR-1, NFR-2
- **Key risk:** `RecordWidget`'s `onEdit` signature — verify it accepts `VoidCallback` or equivalent; if `EditRecordPopup` requires a `BuildContext` captured at call-time, ensure the bottom-sheet's context is used, not a stale one.
- **Interface receives from T2:** `provider.getRecordsForCategory(List<int>, DateTimeRange?)` method
- **Interface produces:** `CategoryRecordsBottomSheet` widget importable by T4.

##### T4: Rewire Categories tab interactions
- **Phase:** 3 | **Parallel:** no | **Est:** 1.5d | **Depends:** T2, T3 | **Complexity:** moderate
- **What:** In `lib/screens/home/tabs/categories_tab.dart`, make two sets of changes. (1) Parent rows: add `ExpansionTileController` per parent (use a `Map<int, ExpansionTileController>` built once in `build` or convert the tab to `StatefulWidget`), set `CategoryWidget.onTap` to `_openCategoryPopup(context, category, isParent: true)`, move expand/collapse to `ExpansionTile(trailing: IconButton(..., onPressed: controller.toggle))`, preserve `onEdit` pencil. (2) Sub rows: change `onTap` from `_showEditDialog` to `_openCategoryPopup(context, sub, isParent: false)`, add `onEdit: () => _showEditDialog(context, sub)` so the existing pencil icon handles the edit dialog (CategoryWidget already renders the pencil when `onEdit != null`). Add the `_openCategoryPopup` private helper as described in Technical Approach.
- **Key files:** `lib/screens/home/tabs/categories_tab.dart`, `lib/components/popups/category_records_bottom_sheet.dart` (import)
- **PRD requirements:** FR-1, FR-2, FR-3
- **Key risk:** If the Categories tab is currently a `StatelessWidget`, adding `ExpansionTileController` per parent requires converting it to `StatefulWidget`. Check the class declaration first; if already stateful, just initialize controllers in `initState`.
- **Interface receives from T3:** `CategoryRecordsBottomSheet` widget

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| InkWell absorption behavior differs on some Flutter versions or platform targets | Medium | Low | Parent row tap opens both popup and toggles expansion | Verify on both Android and iOS after T4; if both fire, fall back to `ExpansionTileController`-only approach with `tilePadding: EdgeInsets.zero` disabling header tap area |
| `RecordWidget` doesn't expose `onEdit` and requires internal changes | Medium | Low | T3 scope grows; may need to touch record_widget.dart | Inspect `record_widget.dart` in T3 before building the sheet; if no `onEdit`, wrap each row in a Stack with an overlay edit button — 1 extra widget, still no new file |
| Categories tab is a `StatelessWidget` — `ExpansionTileController` requires `State` | Low | Medium | T4 needs extra conversion step | Check class declaration at start of T4; if stateless, convert to `StatefulWidget` (mechanical, ~10 lines) |
| Edit from popup doesn't refresh the bottom-sheet (stale data) | High | Medium | User edits record, sees old value | Wrap the `ListView` content in `Consumer<RecordProvider>`; since `RecordProvider.notifyListeners()` fires after any edit, the sheet rebuilds automatically |

## Dependencies

- `lib/components/record_widget.dart` — dainn / resolved (exists, used by RecordsTab)
- `lib/components/popups/edit_record_popup.dart` — dainn / resolved (exists, used by RecordsTab and ChatTab)
- `lib/providers/record_provider.dart` — dainn / resolved (exists, `getSubCategories` and `_selectedDateRange` already available)

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Popup opened by ≥30% weekly active users | Analytics event `category_records_popup_opened` (pending NFR-3 from PRD) | N/A until instrumented | Add event in `_openCategoryPopup` if analytics package is in use; else defer |
| Zero "can't see category records" complaints | QA smoke test: all tap paths work, no crashes | 0 issues in 30-day window | Manual regression + crash reporting |
| Records tab render within 10% of baseline | `filteredRecords` sort is O(n log n) same as before | Visually equivalent scroll performance | Profile before/after on a 1000-record dataset using Flutter DevTools |

## Estimated Effort
- **Total:** ~4 days
- **Critical path:** T2 (0.5d) → T3 (1.5d) → T4 (1.5d) = 3.5d
- **T1** runs in parallel with T2 on day 1, adds no critical path time

## Deferred / Follow-up
- **NTH-1 (empty state):** Included in T3 as a small branch — low effort, not deferred.
- **Analytics instrumentation (NFR-3 gap from validation):** Add `category_records_popup_opened` event in `_openCategoryPopup` if the project uses an analytics package. Not blocking — deferred until analytics infrastructure is confirmed.
- **SC-3 baseline capture:** Record Records-tab render time on 1000-record dataset before T1 merges, to enable post-deploy comparison.

## Tasks Created
| #   | Task                                                  | Phase | Parallel | Est.  | Depends On  | Status |
| --- | ----------------------------------------------------- | ----- | -------- | ----- | ----------- | ------ |
| 188 | RecordProvider data layer — sort fix + filter method  | 1     | no       | 1d    | —           | open   |
| 189 | Build CategoryRecordsBottomSheet widget               | 2     | no       | 1.5d  | 188         | open   |
| 190 | Rewire Categories tab — row tap opens popup           | 3     | no       | 1.5d  | 001, 010    | open   |
| 191 | Integration verification & cleanup                    | 3     | no       | 0.5d  | all         | open   |

### Summary
- **Total tasks:** 4
- **Parallel tasks:** 0 (tasks 001+002 consolidated into one file to avoid concurrent edits to `record_provider.dart`)
- **Sequential tasks:** 4
- **Estimated total effort:** 4.5d
- **Critical path:** 001 → 010 → 020 → 090 (~4.5d)

### Dependency Graph
```
001 ──→ 010 ──→ 020 ──→ 090
001 ────────────────→ 090 (direct dep via 020)
```

### PRD Coverage
| PRD Requirement       | Covered By   | Status     |
| --------------------- | ------------ | ---------- |
| FR-1: Tappable rows   | 190          | ✅ Covered |
| FR-2: Union + groups  | 010, 020     | ✅ Covered |
| FR-3: Edit action     | 189          | ✅ Covered |
| FR-4: Sort by occurredAt | 188       | ✅ Covered |
| NTH-1: Empty state    | 189          | ✅ Covered |
| NFR-1: <200ms latency | 001, 010     | ✅ Covered |
| NFR-2: ≤1 new file    | 010, 090     | ✅ Covered |
