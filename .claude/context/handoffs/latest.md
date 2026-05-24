---
epic: redesign-ui
task: 200
status: completed
created: 2026-05-24T08:07:27Z
updated: 2026-05-24T08:07:27Z
---

## What was done

Created the full theme token foundation for the redesign-ui epic:
- `lib/configs/app_theme.dart` with all design token classes and `AppTheme.light()` factory
- Exported `app_theme.dart` from the `lib/configs/configs.dart` barrel
- Replaced the old hardcoded `ThemeData(...)` in `lib/main.dart` with `AppTheme.light()`
- Wrote 14 unit/widget tests covering token values, `copyWith`, `lerp`, and `ThemeExtension` registration

## Files changed

- `lib/configs/app_theme.dart` — CREATED (new; all tokens, `AppSemanticColors`, `AppTheme`)
- `lib/configs/configs.dart` — MODIFIED (added `export 'app_theme.dart';`)
- `lib/main.dart` — MODIFIED (replaced old inline `ThemeData` with `AppTheme.light()`)
- `test/configs/app_theme_test.dart` — CREATED (14 tests, all pass)

## Key decisions

- Used `CardThemeData` and `DialogThemeData` (not `CardTheme`/`DialogTheme`) — Flutter 3.35.7 requires these types in `ThemeData`.
- `AppSemanticColors.lerp` returns `this` when `other` is null — standard `ThemeExtension` contract.
- `extensions` list uses `const` — all six category accent colors and semantic colors are compile-time constants, so `AppSemanticColors` is a `const` constructor.
- No `google_fonts` import anywhere in `lib/` — font family is `'PlusJakartaSans'` string literal only; font assets will be provided by T2.
- The old `ThemeData` used `fontFamily: 'Poppins'` and seed color `0xFF6366F1` (indigo); these are fully replaced. Any widget tests that matched on the old theme colors will now see the new violet palette (`AppColors.primary = 0xFF8B5CF6`).

## Warnings for next task

- **Pre-existing test failures (14):** `test/components/popups/edit_source_popup_test.dart` fails with `type 'Null' is not a subtype of type 'Future<bool>'` — this is unrelated to theme work and existed before T1. Do not count these against NFR-2.
- **Font fallback until T2:** `fontFamily: 'PlusJakartaSans'` renders with system fallback until T2 delivers the TTF assets to `pubspec.yaml`.
- **Token names for downstream tasks:** Use `AppColors.*`, `AppSpacing.*`, `AppRadius.*`, `AppElevation.*` constants — never raw hex/numeric literals. Use `AppSemanticColors.incomeGreen`, `.expenseRed`, `.transferTint`, `.categoryAccents[idx % 6]` for semantic tokens.
- **Accessing `AppSemanticColors` in widgets:** `Theme.of(context).extension<AppSemanticColors>()!` — always non-null under `MaterialApp(theme: AppTheme.light())`.
