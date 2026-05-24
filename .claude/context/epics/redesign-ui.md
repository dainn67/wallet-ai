---
epic: redesign-ui
branch: epic/redesign-ui
started: 2026-05-24T07:49:09Z
status: in-progress
---
# Epic Context: redesign-ui

## Key Decisions

- **AD-1:** Centralized `AppTheme` in `lib/configs/app_theme.dart` — single file holds all tokens (colors, spacing, radius, elevation, typography). Easier to grep/edit; avoids over-engineering a custom design-system framework.
- **AD-2:** `ThemeExtension<AppSemanticColors>` for income/expense/transfer/category tokens. Forward-compatible with dark mode (deferred to follow-up PRD).
- **AD-3:** Single shared `IconSquare` primitive in `lib/components/icon_square.dart`. Used for category icons, transaction-row type indicators, and chat sparkle chip. Prevents the #1 source of NFR-1 violations.
- **AD-4:** `SuggestionBanner` refactored **in-place** — keep widget class + callbacks + double-tap guard state machine; only swap internal `FilledButton` → `TextButton`. Permits exactly 2 test-line changes (`suggestion_banner_test.dart` lines 130, 156).
- **AD-5:** TestTab gated by `if (kDebugMode)` — tab disappears entirely in release builds via Dart tree-shaker.

## Hard Constraints (carry forward into every task)

- **NFR-1 / Zero hardcoded literals** in `lib/components/` + `lib/screens/`. No `Color(0x…)`, no `Colors.X` (except `transparent`/shadow `black`), no numeric `fontSize`, no numeric `BorderRadius.circular(N)`.
- **NFR-2 / Behavioral parity.** `fvm flutter test` must pass with zero failures. The only permitted test-file change in the entire epic is `suggestion_banner_test.dart` lines 130 + 156 (FilledButton → TextButton).
- **NFR-3 / No google_fonts.** Plus Jakarta Sans must be a local asset only.
- **No new dependencies.** Material 3 + `ThemeExtension` only.

## PRD Warnings Resolved in Epic

- W2 (per-source accent color): T6 will use `categoryAccents[idx % 6]` sequential ramp; document in T6 PR.
- W3 (transfer icon-square tint): T6 will use `AppSemanticColors.transferTint` (= `AppColors.primary`).
- W1 (italic 400i in deps): Resolved by font assets — user committed all weights including italic variants.

## Notes

(Accumulate context across sessions here.)
