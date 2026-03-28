---
name: Extract sub-category dialog to popup component
status: open
created: 2026-03-28T17:50:49Z
updated: 2026-03-28T17:50:49Z
complexity: simple
recommended_model: sonnet
phase: 2
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/141"
depends_on: []
parallel: true
conflicts_with: []
files:
  - lib/screens/home/tabs/categories_tab.dart
  - lib/components/popups/add_sub_category_dialog.dart
  - lib/components/components.dart
prd_requirements:
  - FR-5
  - FR-6
---

# Extract sub-category dialog to popup component

## Context

CategoriesTab contains a `_showAddSubCategoryDialog()` method (lines 33-97) that builds an entire AlertDialog inline. This is a 65-line dialog that should live in `lib/components/popups/` per AD-3 and the layer mapping table. All other dialogs (CategoryFormDialog, EditRecordPopup, etc.) already live in that directory.

## Description

Extract the add sub-category dialog into a standalone function or widget in `lib/components/popups/add_sub_category_dialog.dart`. Update CategoriesTab to call the extracted version. Add the export to `components.dart`.

## Acceptance Criteria

- [ ] **FR-5 / Happy path:** Add sub-category dialog logic exists in `lib/components/popups/add_sub_category_dialog.dart`
- [ ] **FR-5 / Happy path:** CategoriesTab no longer contains the `_showAddSubCategoryDialog` method body — it calls the extracted version
- [ ] **FR-5 / Happy path:** `components.dart` exports the new popup file
- [ ] **FR-6 / Behavior preservation:** Tapping "Add sub-category" on a parent category opens the dialog
- [ ] **FR-6 / Behavior preservation:** Entering a name and saving creates a sub-category with correct parent ID and type
- [ ] **FR-6 / Behavior preservation:** Dialog styling matches current (white background, rounded corners, Poppins font)

## Implementation Steps

### Step 1: Create `lib/components/popups/add_sub_category_dialog.dart`

- Create new file
- Implement as a top-level function (matching the pattern of `showCurrencySelectionPopup`):
  ```dart
  Future<void> showAddSubCategoryDialog({
    required BuildContext context,
    required Category parent,
  }) async {
    // Move the dialog logic from CategoriesTab._showAddSubCategoryDialog here
    // Read RecordProvider and LocaleProvider from context inside the function
  }
  ```
- Move the full dialog UI code from CategoriesTab lines 37-96
- Add imports for models, providers, and Flutter material

### Step 2: Update CategoriesTab

- Modify `lib/screens/home/tabs/categories_tab.dart`
- Remove the `_showAddSubCategoryDialog` method entirely (lines 33-97)
- Replace the call site (line ~221 in build):
  - From: `_showAddSubCategoryDialog(context, category)`
  - To: `showAddSubCategoryDialog(context: context, parent: category)`
- Import the new file (via components barrel or direct)

### Step 3: Update barrel file

- Modify `lib/components/components.dart`
- Add: `export 'popups/add_sub_category_dialog.dart';`

## Technical Details

- **Approach:** Per AD-3, extract inline dialog to popup directory
- **Files to create:** `lib/components/popups/add_sub_category_dialog.dart`
- **Files to modify:** `lib/screens/home/tabs/categories_tab.dart`, `lib/components/components.dart`
- **Patterns to follow:** See `lib/components/popups/currency_selection_popup.dart` for the function-based popup pattern, or `category_form_dialog.dart` for the widget-based pattern
- **Edge cases:**
  - The dialog reads `RecordProvider` via `context.read` for `addCategory()` — this works as long as context is from within the widget tree (which it is, since `showDialog` inherits context)
  - The dialog uses `controller.text.trim()` for validation (non-empty check) — preserve this

## Tests to Write

### Unit Tests
- No unit tests needed — this is a UI extraction with no logic changes

### Integration Tests
- Test: Call `showAddSubCategoryDialog()` with a mock parent category → expect dialog renders with correct title and input

## Verification Checklist

- [ ] `flutter analyze` passes with zero errors
- [ ] `grep -n "_showAddSubCategoryDialog" lib/screens/home/tabs/categories_tab.dart` returns empty
- [ ] `grep -n "showAddSubCategoryDialog" lib/components/popups/add_sub_category_dialog.dart` returns the function definition
- [ ] Manual test: Click "Add sub-category" on Food → dialog opens with "Add sub-category" title
- [ ] Manual test: Enter "Coffee" and save → sub-category appears under Food with type "expense"

## Dependencies

- **Blocked by:** None
- **Blocks:** T7 (barrel file update depends on new file existing)
- **External:** None
