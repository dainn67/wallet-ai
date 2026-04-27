---
epic: category-filter
task: 190
status: completed
created: 2026-04-27T09:10:00Z
updated: 2026-04-27T09:10:00Z
---

# Handoff: Task #190 — Rewire Categories Tab

## Status

COMPLETED. Two existing files modified.

## What Was Done

1. Converted `CategoriesTab` from `StatelessWidget` to `StatefulWidget` with a `Map<int, ExpansibleController> _controllers` field.
2. Added `_openCategoryPopup(context, category, {required bool isParent})` helper that reads `RecordProvider.getSubCategories`, builds the `categoryIds` union, and calls `showModalBottomSheet` with `CategoryRecordsBottomSheet`.
3. Rewired parent `CategoryWidget.onTap` from `null` to `_openCategoryPopup(..., isParent: true)` — the tile no longer expands on row body tap.
4. Added `ExpansibleController` to each `ExpansionTile` via `controller:` parameter; added trailing `IconButton` (keyboard_arrow_down_rounded icon) that calls `controller.isExpanded ? controller.collapse() : controller.expand()`.
5. Rewired sub-category `CategoryWidget.onTap` to `_openCategoryPopup(..., isParent: false)` and added `onEdit: () => _showEditDialog(context, sub)` so the pencil icon opens the edit dialog.
6. Added `category_records_bottom_sheet.dart` export to `lib/components/components.dart`.

**Note:** Flutter 3.35.7 deprecated `ExpansionTileController` (typedef `ExpansibleController`). Code uses `ExpansibleController` directly to avoid deprecation warnings. `ExpansibleController` has no `toggle()` — used `isExpanded ? collapse() : expand()` instead.

## Files Changed

- `lib/screens/home/tabs/categories_tab.dart` — converted to StatefulWidget, ~200 lines total
- `lib/components/components.dart` — added one export line
- `.claude/epics/category-filter/190.md` — status: closed

## Key Behavior Notes for #191 Verification

| Action | Expected Behavior |
|--------|-------------------|
| Tap parent category row body | `CategoryRecordsBottomSheet` opens; `categoryIds` = [parentId, sub1Id, ...]; `subCategories` = list of subs; tile does NOT expand |
| Tap trailing chevron button | `ExpansionTile` expands/collapses; no popup opens |
| Tap sub-category row | `CategoryRecordsBottomSheet` opens; `categoryIds` = [subId]; `subCategories` = [] |
| Tap pencil icon on sub row | `CategoryFormDialog` opens (edit category name/type) — NOT the records popup |
| Tap pencil icon on parent row (non-Uncategorized) | `CategoryFormDialog` opens |
| Uncategorized row (categoryId == 1) | Tap opens popup; no pencil icon (onEdit == null for categoryId == 1) |
| "+ Add sub-category" button | `showAddSubCategoryDialog` called — unchanged |
| Top-right add button | `CategoryFormDialog` (add mode) — unchanged |

## Controller Note

`_controllers` uses `putIfAbsent` so existing controllers (and their expanded state) survive `notifyListeners()` rebuilds. Controllers are NOT disposed — they are `ChangeNotifier`s owned by the State. This is acceptable for a tab-level state.

## Analyze Result

`fvm flutter analyze lib/screens/home/tabs/categories_tab.dart lib/components/components.dart` — **No issues found.**

## Next Task: #191 — Verification

Verify all acceptance criteria from tasks 188, 189, 190:
- `getRecordsForCategory` returns correct union
- `CategoryRecordsBottomSheet` renders grouped/flat correctly
- Parent/sub tap behaviors, chevron, edit pencil all work as described above
