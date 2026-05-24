---
epic: redesign-ui
task: 208
status: completed
created: 2026-05-24T09:42:14Z
updated: 2026-05-24T09:42:14Z
---

## What was done

T9 — Three sub-tasks: onboarding step content polish, TestTab refactor, orphan/comment audit.

**Files changed:**
- `lib/components/popups/onboarding_dialog.dart` — Removed leftover T8 dev comments (the `// Slide text color — T9 will migrate…` comment block and the `T8:` / `T9 scope:` lines from the class docstring). Slide content was already correctly using `textTheme.bodyMedium` + `AppColors.onSurface` from T8. No step header was present in the data model (`_OnboardingSlide` only has `imageAsset` + `textKey`); `IconSquare` not applicable (slides use `Image.asset`, not `CircleAvatar`/`Icon`).
- `lib/screens/home/tabs/test_tab.dart` — Full hardcoded-literal sweep:
  - Added `import 'package:wallet_ai/configs/app_theme.dart'`
  - All `Color(0xFF...)` / `Color(0x...)` literals replaced with `AppColors.*` tokens
  - `Colors.white` replaced with `AppColors.onPrimary`
  - All `TextStyle(fontSize: N, ...)` replaced with `textTheme.titleLarge`, `textTheme.bodyMedium`, `textTheme.bodySmall` (with `.copyWith(...)` for weight/color)
  - `FilledButton.styleFrom(backgroundColor: Color(0xFF6366F1), ...)` removed — now inherits theme default (`AppColors.primary`)
  - `const EdgeInsets.all(24)` → `EdgeInsets.all(AppSpacing.xxl)`
  - `BorderRadius.circular(12)` → `BorderRadius.circular(AppRadius.tile)`
  - `TextButton.styleFrom(foregroundColor: Color(...))` removed — inherits theme default
  - `padding: EdgeInsets.symmetric(vertical: 16)` inline style overrides removed from FilledButton.styleFrom calls

## Key decisions

- **`onboarding_dialog.dart` slide content was already complete**: T8 had already applied `textTheme.bodyMedium` + `AppColors.onSurface` to the `_Slide` widget body text. No `CircleAvatar` or bare `Icon` illustration exists — slides use `Image.asset`. `IconSquare` was not applicable.
- **`Colors.black.withValues(alpha: 0.55)` in `barrierColor` retained**: This is part of the dialog chrome (set up by T8), and `Colors.black` is semantically appropriate for a modal overlay. Not a style regression.
- **`use_build_context_synchronously` info warnings in test_tab.dart**: These two pre-existing infos (lines for `_addDemoRecords` / `_addDemoMoneySources` async gaps) are unchanged by T9 — they are behavioral (not cosmetic) and would require logic refactoring outside T9 scope.
- **Orphan audit**: Zero confirmed orphans. The simplified grep (`grep -rl "$base" lib/`) confirmed every component file is referenced by at least one other file (typically the barrel `components.dart` plus direct screen imports).
- **Files deleted**: None.
- **Commented-out pre-redesign blocks**: Zero found across `lib/components/` and `lib/screens/`.

## Warnings for T10 (Final verification)

- **`test_tab.dart` bodySmall for monospace text**: The result panel and stored-pattern panel use `textTheme.bodySmall` with `fontFamily: 'monospace'`. T10 should visually verify the monospace font override works at runtime — if the `PlusJakartaSans` theme family wins over `'monospace'`, the display may not be monospace. This is cosmetic only (TestTab is a dev screen).
- **No new test failures**: Baseline is 228 pass / 14 fail. All 14 failures are pre-existing mock bugs (`MockStorageService.setString` returns null, unrelated to redesign).

## Test counts

228 pass, 14 fail — exact pre-T9 baseline. No new failures.

## Verification snapshot

- `fvm flutter analyze lib/components/popups/onboarding_dialog.dart lib/screens/home/tabs/test_tab.dart` → 2 info (pre-existing `use_build_context_synchronously`), no errors, no warnings
- `fvm flutter test` → 228 pass, 14 fail (same 14 pre-existing failures)
- No `Color(0x...)` literals in `test_tab.dart` or `onboarding_dialog.dart`
- No `fontSize: N` numeric literals in either file
- No `Colors.` references except `Colors.black` in `barrierColor` (documented above)
- Orphan audit: zero confirmed orphans
- Commented-out pre-redesign blocks: zero
