---
epic: redesign-ui
task: 206
status: completed
created: 2026-05-24T10:15:00Z
updated: 2026-05-24T10:15:00Z
---

## What was done

Migrated `categories_tab.dart` and `category_widget.dart` to the redesign system:

- **`lib/components/category_widget.dart`** — Full structural rewrite. `CategoryWidget` is now a `ListTile`-based widget (not an `InkWell`-wrapped `Container`). Leading uses `IconSquare(icon: _iconForCategory(), tint: AppColors.primary)`. Trailing shows: formatted total (w600, `AppColors.onSurface`) + currency code (`labelMedium`, `AppColors.onSurfaceVariant`) + edit `IconButton` (absorbs tap via non-null `onPressed`) + optional chevron. Added new **`SubCategoryWidget`** for sub-rows: `Container` with `BoxDecoration(border: Border(left: BorderSide(color: AppColors.primary, width: 3)), borderRadius: BorderRadius.only(bottomLeft/Right: AppRadius.tile))` wrapping a `ListTile`. No `IconSquare` on sub-rows per spec. NTH-2 comment added at `IconSquare` call site. `_iconForCategory()` helper: `income → arrow_downward_rounded`, `expense → arrow_upward_rounded`, default → `category_outlined`.
- **`lib/components/components.dart`** — Updated export to explicitly show both `CategoryWidget` and `SubCategoryWidget`.
- **`lib/screens/home/tabs/categories_tab.dart`** — Header row now shows `bodyLarge.bold` title + `FilledButton.icon(Icons.add, label: 'Add Category')`. Month navigator replaced with pill `Container(decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: AppRadius.pill))` flanked by `IconButton`s using `Icons.chevron_left_rounded` / `Icons.chevron_right_rounded`. `ExpansionTile` structure kept intact — expand/collapse behavior unchanged. Sub-rows use `SubCategoryWidget` instead of `CategoryWidget` with old offset padding. Add-sub-category button uses `AppColors.primary` tokens instead of `Colors.blue`. All hardcoded colors → `AppColors.*` / `AppSpacing.*` tokens.

## Files changed

- `lib/components/category_widget.dart` — MODIFIED: full redesign + new `SubCategoryWidget`
- `lib/components/components.dart` — MODIFIED: explicit show export for both widgets
- `lib/screens/home/tabs/categories_tab.dart` — MODIFIED: pill nav + FilledButton + token migration
- `.claude/epics/redesign-ui/7.md` — STATUS: open → completed

## Key decisions

- **InkWell absorption preserved via `IconButton.onPressed`**: The edit `IconButton` in both `CategoryWidget` and `SubCategoryWidget` has a non-null `onPressed`. This is the documented absorption pattern — the `IconButton` captures the pointer event before `ListTile.onTap` fires, so edit taps do NOT expand/collapse the tile and do NOT trigger the drill-down popup. No `GestureDetector` wrapper needed; Flutter's `Material` event bubbling handles this correctly.
- **`ExpansionTile` stays in `categories_tab.dart`**: Per the existing architecture, expansion controllers (`ExpansibleController`) are owned by `_CategoriesTabState`. `CategoryWidget` is composed as the `title` of the `ExpansionTile`, keeping expansion logic separate from display logic.
- **`Category` model has no `icon` field**: Used `_iconForCategory()` helper (type-based: income/expense/default) instead of `category.icon ?? fallback` per spec's intent. This avoids a model change.
- **`add_category_title` key used**: No standalone `add_category` l10n key exists in `l10n_config.dart`. Used `add_category_title` (value: "Add Category") with an inline comment noting T9 can add a dedicated key.
- **`Colors.transparent` kept**: `ExpansionTile` theming requires `Colors.transparent` for `dividerColor`/`splashColor`/`highlightColor`/`collapsedBackgroundColor`/`backgroundColor`. No token equivalent — this is acceptable per T6 baseline.
- **`Colors.black.withValues(alpha: 0.02)` for card shadow**: Same pattern established in T6. Allowed per project NFR-1 carve-out for shadow overlays.
- **`AppSpacing.sm + AppSpacing.xs` for add-sub-category button padding**: `10dp` from the original → approximated as `8 + 4 = 12dp` vertical padding (slightly more generous). No `AppSpacing.ten` token exists.

## Warnings for T8 (Popup wave — CategoryFormDialog, EditRecordPopup, etc.)

- **InkWell absorption pattern documented**: When building popup-triggering rows (e.g., in `CategoryFormDialog` or any popup with a tappable list), use `ListTile(onTap: ...) + IconButton(onPressed: ...)` rather than nested `GestureDetector`. The `IconButton` absorbs before `ListTile.onTap` fires.
- **`AppSemanticColors` fallback needed for bare-MaterialApp tests**: If any popup widget reads `Theme.of(context).extension<AppSemanticColors>()`, tests that wrap with bare `MaterialApp` (not `AppTheme.light()`) will get null. Use the `_fallbackSem(ThemeData)` helper pattern from T6's `record_widget.dart` (maps to `colorScheme.primary/error/secondary/tertiary`).
- **`FilledButton` pill shape is theme-automatic**: No `shape:` override needed on `FilledButton.icon` — the `filledButtonTheme` in `AppTheme.light()` already applies `BorderRadius.circular(AppRadius.pill)`. Popups that need pill buttons just use `FilledButton` directly.
- **`Category` model has no `icon` field**: If T8 popups need to display a category icon, they must use a type-based icon or store an icon code in a separate field. Do not assume `category.icon` exists.
- **`CategoryFormDialog` uses `add_category_title` / `edit_category_title` keys**: Both keys exist in l10n. The "Add Category" button in `CategoriesTab` also uses `add_category_title` — consistent.
- **The 14 pre-existing test failures remain**: 2 `records_overview_test.dart`, 5 `edit_source_popup_test.dart`, 3 `verification_test.dart`, 4 `record_provider_test.dart`. All `MockStorageService.setString` null-return bug. Unrelated to UI redesign.

## Test counts

228 pass, 14 fail — exactly matches pre-T7 baseline. No test assertion changes. No existing tests cover `CategoryWidget` or `CategoriesTab` directly.

## Verification snapshot

- `fvm flutter analyze lib/components/category_widget.dart lib/screens/home/tabs/categories_tab.dart` → **No issues found**
- `fvm flutter test` → 228 pass, 14 fail (same 14 pre-existing failures)
- Grep `Color(0x` on both lib files → empty (no hex literals)
- Grep `Colors.` on both lib files → only `Colors.transparent` (ExpansionTile theming, necessary) and `Colors.black.withValues(alpha: 0.02)` (card shadow, per T6 precedent)
