# Handoff Notes: Task #005 - Extract sub-category dialog to popup component

## What was done
Extracted the inline `_showAddSubCategoryDialog` method from `CategoriesTab` into a standalone top-level function `showAddSubCategoryDialog` in the popups directory.

- Created `lib/components/popups/add_sub_category_dialog.dart` with `Future<void> showAddSubCategoryDialog({required BuildContext context, required Category parent})`.
- Moved the full dialog UI (AlertDialog with text field and save/cancel buttons) from CategoriesTab lines 22–87.
- Removed `_showAddSubCategoryDialog` method entirely from `categories_tab.dart`.
- Updated call site in CategoriesTab to use `showAddSubCategoryDialog(context: context, parent: category)`.
- Added export `export 'popups/add_sub_category_dialog.dart';` to `lib/components/components.dart`.

## Verification
- `fvm flutter analyze` on 3 modified files — No issues found.
- `_showAddSubCategoryDialog` no longer in categories_tab.dart (grep confirms not found).
- `showAddSubCategoryDialog` defined at line 6 of add_sub_category_dialog.dart.

## Files Changed
- `lib/components/popups/add_sub_category_dialog.dart` — created (new popup component)
- `lib/screens/home/tabs/categories_tab.dart` — removed inline method, updated call site
- `lib/components/components.dart` — added export

## Key Decisions
- Followed function-based popup pattern (same as `currency_selection_popup.dart`).
- `context.read<LocaleProvider>()` and `context.read<RecordProvider>()` captured before `showDialog` call, preserving original behavior.
- Import via components barrel — categories_tab.dart already imports `components.dart`, so no new import needed.

## Warnings for Next Task
- No issues. `add_sub_category_dialog.dart` is now exported from `components.dart` and available app-wide.
