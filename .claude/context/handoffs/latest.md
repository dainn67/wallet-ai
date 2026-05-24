---
epic: redesign-ui
task: 207
status: completed
created: 2026-05-24T09:34:05Z
updated: 2026-05-24T09:34:05Z
---

## What was done

Migrated all 11 popup surfaces in `lib/components/popups/` to the redesign-ui design language.

**Files changed:**
- `lib/components/popups/edit_record_popup.dart` — Dialog via theme, FilledButton save, TextButton cancel, themed InputDecoration, AppColors tokens throughout
- `lib/components/popups/edit_source_popup.dart` — same pattern; Icons.delete_outline preserved (test-locked)
- `lib/components/popups/transfer_popup.dart` — FilledButton confirm, TextButton cancel, themed dropdowns and fields
- `lib/components/popups/transfer_info_popup.dart` — FilledButton.icon delete (error color), TextButton close, AppColors.primaryContainer icon background
- `lib/components/popups/confirmation_dialog.dart` — AlertDialog via theme, ElevatedButton kept (NFR-2 test lock), TextButton cancel
- `lib/components/popups/currency_selection_popup.dart` — themed Dialog, themed ListTile with AppColors.primaryContainer tileColor for selected
- `lib/components/popups/add_source_popup.dart` — FilledButton save, TextButton cancel, themed fields
- `lib/components/popups/category_form_dialog.dart` — FilledButton save, TextButton cancel, _TypeButton uses AppColors tokens + colorScheme.error
- `lib/components/popups/add_sub_category_dialog.dart` — FilledButton save, TextButton cancel
- `lib/components/popups/category_records_bottom_sheet.dart` — AppColors tokens for drag handle, header, section borders; AppSemanticColors for income/expense total color
- `lib/components/popups/onboarding_dialog.dart` — Dialog via theme, FilledButton next/finish, LinearProgressIndicator with AppColors.primary, _DotIndicator replaced with LinearProgressIndicator (chrome migration only)
- `.claude/epics/redesign-ui/8.md` — STATUS: open → completed

## Key decisions

- **`ConfirmationDialog` destructive variant uses `ElevatedButton` (NFR-2 lock)**: `confirmation_dialog_test.dart` line 126 does `tester.widget(find.byType(ElevatedButton))` and then `expect(color, Colors.red.shade600)`. Cannot migrate to `FilledButton` — would break the test. Kept `ElevatedButton` with `Colors.red.shade600` for destructive and `AppColors.primary` for standard. All other popups use `FilledButton`.
- **Standard (non-destructive) `ConfirmationDialog` primary button**: Uses `AppColors.primary` background instead of the old `Color(0xFF6366F1)` — semantically identical (both are the primary purple).
- **`OnboardingDialog` chrome-only**: Replaced `_DotIndicator` (custom dot animation) with `LinearProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary))` as specified. Slide content, `PageController`, `_slides` list, step count, and navigation callbacks (`_handleNext`, `_handleGotIt`) are byte-identical. The `_PrimaryPill` custom widget replaced with `FilledButton` via theme. T9 owns all content changes.
- **Dropdowns use themed container pattern**: `DropdownButton` inside `Container(decoration: BoxDecoration(color: AppColors.surfaceContainerLow, border: Border.all(color: AppColors.outline), borderRadius: BorderRadius.circular(AppRadius.input)))` — the `InputDecorationTheme` doesn't apply to dropdowns so manual theming is needed.
- **`CategoryRecordsBottomSheet` color for income/expense total**: Reads `AppSemanticColors` via `Theme.of(context).extension<AppSemanticColors>()` — falls back to `colorScheme.error`/`colorScheme.primary` if extension is null (bare test MaterialApp safety).
- **`Colors.white` replaced with `AppColors.onPrimary`**: In `confirmation_dialog.dart` and `transfer_popup.dart` — same value, semantic token used.

## Warnings for T9 (OnboardingDialog content + post-popup cleanup)

- **`OnboardingDialog._DotIndicator` removed**: T8 replaced the custom animated dot row with `LinearProgressIndicator`. T9 should be aware — if it wants to restore the animated dot indicator (for design reasons), it needs to add it back. Current chrome uses `LinearProgressIndicator` as specified.
- **`onboarding_dialog.dart` slide content untouched**: `_slides` list (imageAsset, textKey), `PageController`, `NeverScrollableScrollPhysics`, `onPageChanged`, `_handleGotIt` (StorageService write) — ALL unchanged. T9 is safe to edit content without risk of breaking navigation.
- **No `_PrimaryPill` class** in the new file — the custom Material+InkWell pill was replaced by `FilledButton`. If T9 needs custom InkWell behavior on the button (e.g., specific splash), use `FilledButton` with a custom `style`.

## Test counts

228 pass, 14 fail — exact pre-T8 baseline. No new failures.

Failing tests (all pre-existing):
- 5x `edit_source_popup_test.dart` — `MockStorageService.setString` null-return bug (unrelated to UI)
- 2x `records_overview_test.dart` — same mock bug
- 3x `verification_test.dart` — same mock bug
- 4x `record_provider_test.dart` — same mock bug

## Verification snapshot

- `fvm flutter analyze lib/components/popups/` → 1 info (pre-existing `use_build_context_synchronously` in `category_form_dialog.dart`), no errors, no warnings
- `fvm flutter test` → 228 pass, 14 fail (same 14 pre-existing failures)
- `Colors.red.shade600` only in `confirmation_dialog.dart` with NFR-2 inline comment
- No `Color(0x...)` hex literals in any popup file
- No `fontSize: N` numeric literals in any popup file
