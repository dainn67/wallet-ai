---
epic: category-filter
task: 189
status: completed
created: 2026-04-27T08:39:53Z
updated: 2026-04-27T08:39:53Z
---

# Handoff: Task #189 — CategoryRecordsBottomSheet

## Status

COMPLETED. One new file created.

## What Was Done

Created `lib/components/popups/category_records_bottom_sheet.dart` — a `StatelessWidget` wrapping a `DraggableScrollableSheet` that shows records for a category (or union of parent + subs).

## Widget Location & Constructor

**File:** `lib/components/popups/category_records_bottom_sheet.dart`

```dart
const CategoryRecordsBottomSheet({
  super.key,
  required this.category,     // Category — the tapped item (for title + parent-direct filter)
  required this.categoryIds,  // List<int> — all ids to include (union for parent, single for sub)
  required this.subCategories, // List<Category> — empty for sub tap, non-empty for parent tap
});
```

## How to Invoke (for #190)

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => CategoryRecordsBottomSheet(
    category: category,
    categoryIds: ids,        // build with: [category.categoryId!, ...subCats.map((s) => s.categoryId!)]
    subCategories: subCats,  // from: provider.getSubCategories(category.categoryId!)
  ),
);
```

`backgroundColor: Colors.transparent` on `showModalBottomSheet` lets the sheet's own `BorderRadius` show cleanly.

## Edit Flow

The sheet uses `showDialog<Record>` (not `showModalBottomSheet`) to open `EditRecordPopup` — matching `RecordsTab._showEditRecordPopup` exactly:

```dart
final updatedRecord = await showDialog<Record>(
  context: context,
  builder: (_) => EditRecordPopup(record: record),
);
if (updatedRecord != null && context.mounted) {
  await context.read<RecordProvider>().updateRecord(updatedRecord);
}
```

The `Consumer<RecordProvider>` in the sheet causes auto-refresh after `updateRecord` calls `notifyListeners()`.

## RecordWidget Reused

- **Name:** `RecordWidget`
- **Path:** `lib/components/record_widget.dart`
- **Usage:** `RecordWidget(record: record, isEditable: true, onEdit: () => _showEditPopup(context, record))`
- `onEdit` is `VoidCallback?` — no changes needed to `RecordWidget`.

## Key Implementation Details

- `DraggableScrollableSheet`: `initialChildSize: 0.6`, `maxChildSize: 0.95`, `minChildSize: 0.3`, `expand: false`
- Header shows: category name (bold), `CurrencyHelper.format(total.abs())` + month label (via `DateFormat('MMM yyyy')`)
- Total sign: positive sums green, negative (expenses dominate) red
- Grouped sections use `Border.all(color: Color(0xFFE2E8F0))` matching `category_widget.dart`
- Empty state: centered `Text('No records in this category for {month}.')`
- `_Section` is a private internal class — not exported

## Analyze Result

`fvm flutter analyze lib/components/popups/category_records_bottom_sheet.dart` — **No issues found.**

## Files Changed

- `lib/components/popups/category_records_bottom_sheet.dart` — new file, ~226 lines
- `.claude/epics/category-filter/189.md` — frontmatter updated to `status: closed`
- `docs/features/categories.md` — added drill-down popup section

## Next Task: #190 — Rewire Categories tab interactions

Key things to know:
1. Import `category_records_bottom_sheet.dart` and call it as described above
2. Build `categoryIds` union: `[category.categoryId!, ...subCats.map((s) => s.categoryId!)]`
3. Get subCats via `context.read<RecordProvider>().getSubCategories(category.categoryId!)`
4. The `CategoriesTab` may need conversion to `StatefulWidget` for `ExpansionTileController` map — check current class declaration first
5. `EditRecordPopup` returns `Record?` from `showDialog` — the sheet handles saving internally, no changes needed in CategoriesTab for the edit flow
