---
epic: redesign-ui
task: 205
status: completed
created: 2026-05-24T09:07:33Z
updated: 2026-05-24T09:07:33Z
---

## What was done

Migrated all 4 records-surface files to the redesign system, executing T6:

- **`lib/components/date_divider.dart`** — replaced custom `Text` with `SectionLabel(label)`. Divider color now `AppColors.outline`, paddings use `AppSpacing.lg`/`AppSpacing.xs`/`AppSpacing.md`. SectionLabel uppercases the label string — so any existing test assertion against the raw mixed-case date string had to switch to the uppercased form.
- **`lib/components/record_widget.dart`** — added `_iconForRecord` and `_tintForRecord` helpers (per spec). Leading container now `IconSquare(icon: _iconForRecord(record), tint: _tintForRecord(record, sem))`. Amount text uses `Theme.of(context).textTheme.bodyMedium?.copyWith(color: amountColor, fontWeight: w600)` where `amountColor` = `sem.incomeGreen` / `sem.expenseRed` / `colorScheme.onSurface` per record type. Description switched to textTheme.bodyMedium (w600, `AppColors.onSurface`). Subtitle uses textTheme.labelMedium (`AppColors.onSurfaceVariant`). All edit/tap callbacks preserved verbatim. **Critical deviation**: the date `Text` keeps `const TextStyle(fontSize: 10, color: Color(0xFF64748B))` (no fontFamily) — the existing `record_widget_test.dart` "widget styling matches spec" test (lines 61–72) asserts those exact properties (`fontSize == 10`, `color == Color(0xFF64748B)`, `fontFamily isNull`). NFR-2 (test parity) overrides NFR-1 here. Documented inline.
- **`lib/components/records_overview.dart`** — full structural rewrite from single dark-gradient card → 3 vertically-stacked zones:
  1. **Zone 1 (Net Worth hero)** — white themed Container with `AppColors.surface` fill, `AppRadius.card`, subtle `Colors.black.withValues(alpha: 0.04)` shadow. `SectionLabel('total_balance_label')` header, large amount in `textTheme.headlineMedium` (w700, `AppColors.onSurface`), currency code in `textTheme.labelMedium` (`AppColors.onSurfaceVariant`), mask toggle as `InkWell + Icon` (visibility / visibility_off icons).
  2. **Zone 2 (Income/Expense tiles)** — `Row` with two `_OverviewTile` private widgets. Tile background = `tint.withValues(alpha: 0.12)` where tint is `sem.incomeGreen` / `sem.expenseRed`. Income tile respects mask state; **expense tile is always visible** per task spec.
  3. **Zone 3 (Money-source cards)** — themed Container (same surface+shadow) wrapping `SectionLabel('sources_label')` + `IconButton(Icons.add_rounded)` header row, then a horizontal `ListView.separated` of `_SourceCard` private widgets. Each card uses accent = `sem.categoryAccents[idx % sem.categoryAccents.length]` (sequential index modulo palette length — resolves PRD warning W2). Card background = `accent.withValues(alpha: 0.12)`, source name in `textTheme.labelMedium`, amount in `textTheme.bodyMedium` (w700, accent color).
  - Constructor signature **preserved** (`totalBalance`, `totalIncome`, `totalExpense`, `sources`, `onSourceTap`, `onAddSource`). Mask state remains internal `_valuesHidden` per existing pattern (no parent plumbing change).
- **`lib/screens/home/tabs/records_tab.dart`** — outer wrapper changed to `Container(color: Theme.of(context).colorScheme.surfaceContainerLow)` per T5 handoff guidance. All hardcoded paddings/text styles swapped for `AppSpacing.*` and `textTheme` + `AppColors.*` tokens. `'recent_records'` heading now rendered via `SectionLabel`. Month filter / sort logic / `RecordsOverview` + `ListView` composition unchanged. All callbacks (`onSourceTap`, `onEdit`, `_showEditRecordPopup`, `_showEditSourceDialog`) preserved.
- **`test/screens/records_tab_test.dart`** — exactly 1 line changed (line 135): `expect(find.text('Fri, 15 Mar 2024'), findsOneWidget)` → `expect(find.text('FRI, 15 MAR 2024'), findsOneWidget)`. Reason: `DateDivider` now renders the date string through `SectionLabel`, which calls `.toUpperCase()`. This is a *text-case* assertion adjustment, not a semantic change. Inline comment added explaining the change. (T4 handoff already established this pattern for drawer's `SETTINGS`.)

## Files changed

- `lib/components/date_divider.dart` — MODIFIED: SectionLabel + tokens
- `lib/components/record_widget.dart` — MODIFIED: IconSquare type indicator + semantic amount color
- `lib/components/records_overview.dart` — MODIFIED: structural rewrite to 3-zone layout
- `lib/screens/home/tabs/records_tab.dart` — MODIFIED: surfaceContainerLow bg + token migration
- `test/screens/records_tab_test.dart` — MODIFIED: 1 line (135) — uppercased date string assertion
- `.claude/epics/redesign-ui/6.md` — STATUS: open → closed

## Key decisions

- **Money-source accent assignment rule**: sequential index modulo `sem.categoryAccents.length` (palette has 6 entries). Code: `sem.categoryAccents[index % sem.categoryAccents.length]`. Each `MoneySource` in the horizontal scroll gets the next accent in the palette, wrapping after the 6th. **Resolves PRD warning W2.** Documented in `records_overview.dart` class-level doc comment.
- **Transfer record tint**: `sem.transferTint` (= `AppColors.primary` per `app_theme.dart` registration). Icon = `Icons.swap_horiz_rounded`. **Resolves PRD warning W3.**
- **Income amount color = `sem.incomeGreen`; expense = `sem.expenseRed`; transfer/default = `colorScheme.onSurface`** (neutral) — matches FR-6 acceptance.
- **Expense visibility under mask**: only Net Worth (Zone 1) and Income tile (Zone 2 left) honor `_valuesHidden`. Expense tile (Zone 2 right) ignores the mask flag per task spec ("Expense always visible"). Money-source card amounts (Zone 3) honor the mask (existing behavior preserved).
- **Internal mask state, not external prop**: existing `_valuesHidden` StatefulWidget pattern is retained — the task spec suggested external `isMasked`/`onToggleMask` but stipulated "preserve the constructor signature." The current signature has no such params, so internal state was kept. The InkWell toggle in Zone 1 still calls `setState`.
- **`AppSemanticColors` fallback for tests without the theme extension**: both `RecordWidget` and `RecordsOverview` access `Theme.of(context).extension<AppSemanticColors>()` defensively, falling back to a `_fallbackSem(theme)` helper that maps to `ColorScheme` tokens (primary/error/secondary/tertiary) when null. This preserves the 4 pre-existing `record_widget_test.dart` cases that wrap the widget in a bare `MaterialApp` (no `AppTheme.light()`). The fallback uses scheme tokens, not hex literals, so it does not violate NFR-1.
- **Tab wrapper = `Container`, not nested `Scaffold`**: follows T5 handoff guidance to avoid `MediaQuery` padding double-up when nested inside HomeScreen's outer Scaffold.
- **Date text style intentionally hardcoded**: `record_widget.dart:144` — `const TextStyle(fontSize: 10, color: Color(0xFF64748B))` with no fontFamily. This is **the only NFR-1 violation in T6**, forced by `record_widget_test.dart:69–71` which asserts exactly those values. NFR-2 (test parity) supersedes here. The hex `0xFF64748B` does not map to any `AppColors` token (closest is `onSurfaceVariant` = `0xFF6B7280`, slightly different).
- **`Sources` text + `Icons.add_rounded` IconButton preserved**: `records_overview_test.dart` asserts `find.text('Sources')`, `find.byType(IconButton)` (singular), and `find.byIcon(Icons.add_rounded)`. The Zone 3 section header keeps both. (The test itself remains broken by the pre-existing `MockStorageService.setString` bug — but I did not introduce that, and it's part of the 14-failure baseline.)

## Warnings for T7/T8 (Categories tab, polish/orphan cleanup)

- **`AppSemanticColors` fallback pattern**: if a component reads the `AppSemanticColors` theme extension, the host theme MUST register it via `AppTheme.light()` — bare `MaterialApp` in widget tests will return null. Either:
  (a) Wrap your component's test widget in `MaterialApp(theme: AppTheme.light(), ...)`, OR
  (b) Add a `_fallbackSem(ThemeData theme) -> AppSemanticColors` helper that maps to `ColorScheme` tokens (primary/error/secondary/tertiary) when the extension is null. T6 used pattern (b) so the pre-existing record_widget tests keep passing without modification.
- **`SectionLabel` upcasing trips test assertions**: any `find.text('Foo Bar')` test against a string that was previously rendered as raw mixed-case `Text` and is now wrapped in `SectionLabel` will fail — match the uppercased form. T4/T5/T6 each had 1 such adjustment (`SETTINGS`, `EXPENSE DETECTED`, `FRI, 15 MAR 2024`). This is the expected pattern, not a violation of NFR-2.
- **IconSquare in records**: the records area uses 4 type→icon mappings (`income→arrow_downward_rounded`, `expense→arrow_upward_rounded`, `transfer→swap_horiz_rounded`, fallback→`receipt_long_outlined`). For Categories tab, follow the same pattern: build an `_iconForCategory(Category)` helper and use `sem.categoryAccents[idx % 6]` for tinting if rendering a list of categories. The `_OverviewTile` and `_SourceCard` private widget pattern in `records_overview.dart` is a reusable template for Categories list items.
- **Sequential `categoryAccents[idx % 6]` rule** is the canonical accent assignment for any horizontal/grid scroll of color-tinted items. The same rule should apply to categories in T7 (resolves PRD warning W2 consistently across surfaces).
- **`textTheme.labelMedium` is the new subtitle font** (12pt, w500). `textTheme.bodyMedium` is the new body font (14pt, w400 default — copy with w600 for emphasis). `textTheme.headlineMedium` is hero-amount font (28pt, w600 default — copy with w700 for tightness).
- **Card surface = `AppColors.surface` + `Colors.black.withValues(alpha: 0.04)` shadow + `AppRadius.card`** — this is the T6-established "white card on grey background" pattern. Reuse for Categories cards rather than reinventing.
- **Mask state pattern**: T6 kept internal `_valuesHidden` rather than threading `isMasked`/`onToggleMask` through props. If T9 (orphan cleanup) wants to standardize this across the app, that's an isolated future refactor — current behavior parity is preserved.
- **The 14 pre-existing test failures remain**: 2 in `records_overview_test.dart`, 5 in `edit_source_popup_test.dart`, 3 in `verification_test.dart`, 4 in `record_provider_test.dart`. All caused by `MockStorageService.setString` returning Null instead of `Future<bool>`. Unrelated to UI redesign — leave for a separate test-fixture epic.

## Test counts

228 pass, 14 fail — exactly matches the pre-T5/T6 baseline (same 14 tests fail, all pre-existing `MockStorageService.setString` mock issues unrelated to UI). The 4 `record_widget_test.dart` cases all pass (including the strict styling assertion on date text). The 1 modified `records_tab_test.dart:135` assertion now passes with the uppercased date string.

## Verification snapshot

- `git diff -- test/screens/records_tab_test.dart` shows exactly 1 logical line changed (line 135) — date string uppercased to match `SectionLabel` rendering.
- `fvm flutter analyze` on the 4 migrated files: **No issues found**
- Grep for `Color(0x|Colors\.[a-zA-Z]|fontSize: [0-9]|BorderRadius.circular([0-9]` on the 4 lib files: only intentional exceptions remain:
  - 3 × `Colors.black.withValues(alpha: 0.0X)` for card/row shadows (allowed per NFR-1 spec)
  - 1 × `Color(0xFF64748B)` + `fontSize: 10` on `record_widget.dart:144` date text (forced by `record_widget_test.dart:69–71` — documented inline)
- All `AppColors.*` token usages are correctly recognized (not hardcoded literals).
