---
name: redesign-ui
status: backlog
created: 2026-05-24T07:23:44Z
progress: 0%
priority: P1
prd: .claude/prds/redesign-ui.md
task_count: 10
github: "199"
---

# Epic: redesign-ui

## Overview

We rebuild Wally AI's entire visual layer on top of a single `AppTheme` class with Plus Jakarta Sans as a locally bundled font, then migrate every existing UI surface (3 production tabs + drawer + bottom nav + 11 popups + chat components + records overview + categories) to consume the new tokens with zero hardcoded literals. The architecture leans hard on Flutter's native `ThemeData` + `ThemeExtension<T>` machinery rather than introducing a custom design-system framework — keeping the surface area inside familiar Material 3 patterns and avoiding any new abstraction the team would later have to learn or maintain. The hardest part is not building the theme but containing the blast radius: ten existing components and eleven popups must all migrate without behavior regression, and a single hardcoded `Colors.purple` slipping through dilutes the entire system. We mitigate this by extracting one shared visual primitive (`IconSquare`) that absorbs the most-repeated pattern, refactoring `SuggestionBanner` in-place (preserving `find.byType(SuggestionBanner)` test assertions), and running a verification sweep at the end.

## Architecture Decisions

### AD-1: Centralized `AppTheme` in `lib/configs/app_theme.dart`
**Context:** Theme tokens must live in one place so future changes (dark mode, brand tweaks) touch one file. The project's existing convention places cross-cutting configuration in `lib/configs/` (`app_config.dart`, `chat_config.dart`, `l10n_config.dart`).
**Decision:** Create `lib/configs/app_theme.dart` exposing a single `AppTheme` class with static `light()` returning `ThemeData`, plus nested constant classes `AppColors`, `AppSpacing`, `AppRadius`, `AppElevation`, `AppTypography` for direct widget access (`AppSpacing.md`, `AppRadius.card`).
**Alternatives rejected:** (a) Split into 5 separate files — wins nothing, adds import churn. (b) Build a custom design-system framework — over-engineered; violates project's "avoid over-engineering" mandate. (c) Move to `lib/theme/` as a new top-level directory — breaks the configs convention.
**Trade-off:** One larger file (~250 lines) vs scattered tokens. Easier to grep and edit; harder to navigate at scale (acceptable for this size).
**Reversibility:** Easy — token consumers reference `AppColors.primary` etc., not the file location. Could split later without touching callers.

### AD-2: `ThemeExtension<AppSemanticColors>` for non-Material tokens
**Context:** Material 3 `ColorScheme` has slots for primary/secondary/tertiary/error/surface, but not for `incomeGreen`, `expenseRed`, or a six-step category-accent ramp — and these vary per theme (light/dark).
**Decision:** Define `class AppSemanticColors extends ThemeExtension<AppSemanticColors>` carrying `incomeGreen`, `expenseRed`, `transferTint`, `categoryAccents` (List<Color>). Register on `ThemeData.extensions`. Widgets access via `Theme.of(context).extension<AppSemanticColors>()!`.
**Alternatives rejected:** (a) Static const in `AppColors` — works for v1 but breaks dark-mode token-swapping in the follow-up PRD; better to set the pattern now. (b) Provider-based theme — overkill; theme is per-app-build, not reactive.
**Trade-off:** Slightly verbose access pattern (one extra `.extension<…>()!`) vs forward-compatible with dark mode.
**Reversibility:** Easy — `AppSemanticColors` is purely additive; can be removed by inlining values back into widgets.

### AD-3: Single shared `IconSquare` primitive
**Context:** The mockup uses tinted rounded icon-square containers in at least three places: category icons, transaction-row entity icons, and chat assistant sparkle chip. Without a shared primitive, each surface would re-implement the rounded container + tinted background + padded glyph pattern with its own padding/radius literals — the #1 source of NFR-1 violations.
**Decision:** Create `lib/components/icon_square.dart` exposing `IconSquare({required IconData icon, required Color tint, double size = AppSpacing.iconSquare})`. All tinted icon containers in the app use it.
**Alternatives rejected:** (a) Inline in each widget — invites token drift. (b) Extension method on `Icon` — Dart syntax fights the use site.
**Trade-off:** One more shared component vs DRY across 3 use sites.
**Reversibility:** Easy — `IconSquare` has no behavior, only layout; replacements are mechanical.

### AD-4: Refactor `SuggestionBanner` in-place
**Context:** The mockup shows the AI category suggestion inline in the assistant bubble as italic text + chip actions, not as a separate card. The PRD's NFR-2 forbids test-assertion changes except for two named lines in `suggestion_banner_test.dart`.
**Decision:** Keep `SuggestionBanner` as a named widget class. Change its internal rendering from a `Card` with `FilledButton` actions to a `Padding` with italic `Text` + two `TextButton`s (chip-styled). The widget class, its constructor, its `onConfirm`/`onCancel` callbacks, and the double-tap guard state machine are preserved. `find.byType(SuggestionBanner)` continues to work. The only test change is `find.byType(FilledButton)` → `find.byType(TextButton)` on lines 130, 156.
**Alternatives rejected:** (a) Inline the suggestion UI directly into `ChatBubble` — kills the test suite. (b) Build a parallel `InlineSuggestion` widget and route around `SuggestionBanner` — leaves dead code, fails NFR-6.
**Trade-off:** Slightly awkward class name for inline UI vs full test-suite preservation.
**Reversibility:** Easy — internal rendering swap is a single-file change.

### AD-5: TestTab gated by `if (kDebugMode)` compile-out
**Context:** The 4th tab (TestTab) is a developer tool that must not appear in release builds. Two patterns are common: (a) build-flavor / dart-define flag, (b) `kDebugMode` constant.
**Decision:** Wrap the TestTab `BottomNavigationBarItem` and its `PageView` page in `if (kDebugMode)` blocks. Dart's tree-shaker eliminates the dead code in release builds.
**Alternatives rejected:** (a) Build flavors — adds Android/iOS config complexity for one toggle. (b) `--dart-define` env flag — requires release scripts to remember the flag.
**Trade-off:** Tab disappears entirely in release (not even hidden behind a debug menu) — acceptable since it's a developer tool, not a beta feature.
**Reversibility:** Trivial — flip the conditional.

## Technical Approach

### Theme layer (`lib/configs/app_theme.dart`)
Single new file. Defines:
- `class AppColors` — static const hex values: `primary = Color(0xFF8B5CF6)`, `secondary = Color(0xFFF9FAFB)`, `tertiary = Color(0xFFEC4899)`, `neutral = Color(0xFF1F2937)`. Plus auto-derived `primaryContainer`, `onPrimary`, `onSurface`, `outline`, `outlineVariant`, `error`.
- `class AppSpacing` — `xs = 4`, `sm = 8`, `md = 12`, `lg = 16`, `xl = 20`, `xxl = 24`, `iconSquare = 40`.
- `class AppRadius` — `chip = 999`, `pill = 999`, `card = 16`, `tile = 12`, `input = 24`.
- `class AppElevation` — `none = 0`, `card = 1`, `dialog = 4`.
- `class AppTypography` — Material text theme bound to `'PlusJakartaSans'` with weight overrides per role (display/headline = SemiBold, body = Regular, label = Medium).
- `class AppSemanticColors extends ThemeExtension<AppSemanticColors>` — `incomeGreen = Color(0xFF22C172)`, `expenseRed = Color(0xFFEF4444)`, `transferTint = AppColors.primary`, `categoryAccents = [violet, blue, orange, pink, emerald, slate]`. Required `copyWith` and `lerp` overrides.
- `class AppTheme` with `static ThemeData light()` assembling `ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light, primary: …)` plus component themes for `AppBarTheme`, `BottomNavigationBarTheme` (or `NavigationBarTheme` for Material 3), `CardTheme`, `ChipTheme`, `InputDecorationTheme`, `DialogTheme`, `BottomSheetThemeData`, `FilledButtonTheme`, `OutlinedButtonTheme`, `TextButtonTheme`, `ElevatedButtonTheme`.

Wire into `main.dart`: `MaterialApp(theme: AppTheme.light(), …)`.

### Font asset wiring (`pubspec.yaml` + `assets/fonts/`)
- Drop TTFs: `PlusJakartaSans-Regular.ttf`, `PlusJakartaSans-Italic.ttf`, `PlusJakartaSans-Medium.ttf`, `PlusJakartaSans-SemiBold.ttf`, `PlusJakartaSans-Bold.ttf` in `assets/fonts/`.
- Replace the current Poppins block in `pubspec.yaml` with a `PlusJakartaSans` family declaring all 5 weights (400 normal, 400 italic, 500, 600, 700).
- `AppTheme.light()` sets `fontFamily: 'PlusJakartaSans'`.
- Verify with `find /Users/nguyendai/StudioProjects/wallet-ai/lib -name "*.dart" | xargs grep -l "google_fonts"` returning empty.

### Shared UI primitives (`lib/components/`)
- New: `icon_square.dart` — `IconSquare` widget (AD-3).
- New: `section_label.dart` — small-caps gray label used for `EXPENSE DETECTED` / `TODAY` / `YESTERDAY` / `September Transactions` headers.
- New: `pill_chip.dart` *or* rely on themed `Chip` (decide during implementation; prefer themed `Chip` if Material 3's default supports the pill shape via `shape` override — it does).
- The `components/components.dart` barrel exports all new primitives.

### App shell chrome (`lib/screens/home/`)
- `home_screen.dart` — replace `AppBar` widget with the new design (hamburger + avatar + brand wordmark in `AppColors.primary` SemiBold + bell). All three production tabs use the same `AppBar`. Drawer is unchanged in scope but visually retuned to match the token system.
- `BottomNavigationBar` (or `NavigationBar` for Material 3) — four items wrapped: `if (kDebugMode) ... TestTab item`. Active state uses `NavigationDestination` with theme-driven `indicatorColor` (`AppColors.primaryContainer`).

### Assistant (Chat) tab (`lib/screens/home/tabs/chat_tab.dart` + `lib/components/chat_bubble.dart` + 3 more)
- `chat_tab.dart`: tab background to `colorScheme.surfaceContainerLow`; input bar restyled as a single rounded-pill `Container` with `+` icon (camera/gallery — unchanged behavior), `TextField`, circular primary send button.
- `chat_bubble.dart`: white rounded cards; assistant variant with leading lavender `IconSquare(icon: sparkle, tint: AppColors.primary)`; user variant with trailing dark avatar circle. Inline AI-parsed expense card uses `SectionLabel('EXPENSE DETECTED')` + `IconSquare` + bold amount in `AppColors.primary`.
- `suggestion_banner.dart`: in-place refactor per AD-4. Internals swap from `Card` + `FilledButton` to `Padding` with italic `Text` + two `TextButton` chips. State machine and callbacks unchanged.
- `suggested_prompts_bar.dart`: outlined gray pills horizontally scrollable, themed `ActionChip`.
- All streaming behavior (`isStreaming`, `isAnalyzing`, auto-scroll `jumpTo`) untouched — this is presentation-only.

### Records tab (`lib/screens/home/tabs/records_tab.dart` + `lib/components/records_overview.dart` + `lib/components/record_widget.dart` + `lib/components/date_divider.dart`)
- `records_overview.dart`: rewrite layout to three zones — Net Worth hero block, Income/Expense tile row, horizontal money-source card row. Balance-mask toggle unchanged. Income/expense tiles use `AppSemanticColors.incomeGreen` / `expenseRed` as background tint.
- `record_widget.dart`: leading `IconSquare` with type-derived tint (`income → incomeGreen`, `expense → expenseRed`, `transfer → transferTint`); right-aligned colored amount; trailing pencil edit.
- `date_divider.dart`: `SectionLabel(date)` styling.

### Categories tab (`lib/screens/home/tabs/categories_tab.dart` + `lib/components/category_widget.dart`)
- `categories_tab.dart`: top date-period pill (themed `Container` with `AppColors.primaryContainer` background + `Row` of `< MMM yyyy >`); `+ Add Category` filled primary pill button.
- `category_widget.dart`: parent rows use white `Card` with leading `IconSquare`, bold name + monthly total, expand chevron, pencil edit. Sub-rows render as white card with 3dp left border in `AppColors.primary` (using `Container.decoration: BoxDecoration(border: Border(left: ...))`), no `IconSquare`. Existing InkWell-absorption pattern preserved.

### Popups & dialogs (`lib/components/popups/*` × 11)
Each popup migrates independently — same checklist applied:
- Top-level container is themed `Dialog` or `showModalBottomSheet` (already correct in the theme).
- Buttons swap to `FilledButton` (primary action) + `OutlinedButton`/`TextButton` (secondary) using the global theme.
- Text fields use the themed `InputDecoration` (rounded pill).
- All save/delete/dismiss callbacks unchanged.
- `ConfirmationDialog` — primary action color follows `destructive` flag (red for delete confirmation).
- `OnboardingDialog` — re-skinned; step content/navigation logic untouched (FR-9).

### TestTab + cleanup (`lib/screens/home/tabs/test_tab.dart`)
- Refactor TestTab buttons/cards to use themed components — no new visual design.
- After all surfaces migrate, audit `lib/components/` and `lib/screens/`: any `.dart` file not imported by any other file is deleted (FR-10, NFR-6).

### Verification (last task)
- `grep -rE "Color\(0x[0-9A-Fa-f]{8}\)|Colors\.(?!transparent)|fontSize: *[0-9]|borderRadius: *BorderRadius.circular\([0-9]" lib/components lib/screens` — expect zero matches.
- `grep -r "google_fonts" lib/` — expect empty.
- `fvm flutter test` — expect zero failures; confirm `suggestion_banner_test.dart` is the only test file modified.
- `flutter run --profile` cold-start trace — compare against baseline saved before epic start.
- Manual WCAG AA check on: app bar wordmark, chat input bar, bottom nav active/inactive, transaction row edit icon, popup primary actions, category expand chevron.

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --- | --- | --- | --- |
| FR-1 Centralized theme & tokens | §Theme layer + AD-1, AD-2 | T1 | Code review (grep for literals) + token-swap test |
| FR-2 Plus Jakarta Sans wiring | §Font asset wiring | T2 | Airplane-mode render check + `grep -r google_fonts lib/` empty |
| FR-3 App bar & drawer | §App shell chrome | T4 | Manual QA on all 3 tabs + drawer-from-records widget test |
| FR-4 Bottom navigation | §App shell chrome + AD-5 | T4 | Manual QA + release-build screenshot (3 tabs) |
| FR-5 Assistant tab redesign | §Assistant tab + AD-3, AD-4 | T5 | Streaming flow manual + `suggestion_banner_test.dart` updated 2 lines |
| FR-6 Records tab redesign | §Records tab | T6 | Manual QA on 3-zone overview + record row tinting per type |
| FR-7 Categories tab redesign | §Categories tab | T7 | Manual QA on date pill, expand/collapse, sub-row accent bar |
| FR-8 Popups & dialogs (11) | §Popups & dialogs | T8 | Per-popup smoke check; save/cancel produces identical state |
| FR-9 Onboarding redesign | §Popups & dialogs (Onboarding entry) | T9 | First-launch flow on fresh install device |
| FR-10 TestTab refactor + orphan cleanup | §TestTab + cleanup | T9, T10 | Debug-mode TestTab render + import-graph audit |
| NTH-1 FAB on Records | — | Deferred | — |
| NTH-2 Per-category accent ramp | — | Deferred (ramp defined in AppSemanticColors, assignment deferred) | — |
| NFR-1 Zero hardcoded literals | §Verification | T10 | grep returns zero violations on `lib/components` + `lib/screens` |
| NFR-2 Behavioral parity | All tasks; verification consolidates | T1–T10 | `fvm flutter test` zero failures; ≤2 test-line modifications |
| NFR-3 Font locally bundled | §Font asset wiring | T2 | `grep -r google_fonts lib/` empty |
| NFR-4 Cold-start ≤ +100ms | §Verification | T10 | `flutter run --profile` trace diff vs baseline |
| NFR-5 WCAG AA + 48dp tap targets | §Verification | T10 | Manual contrast audit on 5 named surfaces + tap-target inspect |
| NFR-6 Codebase cleanliness | §TestTab + cleanup + §Verification | T9, T10 | Import-graph audit; zero unused `.dart` files |

## Implementation Strategy

### Phase 1 — Foundation (sequential then parallel)
**Includes:** T1 (theme), T2 (font), T3 (shared primitives), T4 (app shell chrome).
**Why first:** Every subsequent task depends on the theme constants and the shared `IconSquare` primitive. The app shell chrome (T4) makes the new design visible immediately on every tab — early visual signal that the system is working.
**Exit criterion:** App launches with `AppTheme.light()` applied; Plus Jakarta Sans renders in airplane mode; `IconSquare` widget exists; new `AppBar` + `BottomNavigationBar` visible on all tabs (tabs themselves still using old internal layouts — that's OK).

### Phase 2 — Tab surfaces (parallel)
**Includes:** T5 (Assistant tab), T6 (Records tab), T7 (Categories tab).
**Why parallel:** Each tab is in a separate file with no shared widgets between them (only shared *primitives* from Phase 1). Three contributors — or one contributor in three sittings — can migrate tabs independently.
**Exit criterion:** All three production tabs render in the new design; existing widget tests pass; manual smoke of chat streaming, record edit/delete, category expand/drill-down passes.

### Phase 3 — Popups, cleanup, verification (mostly sequential)
**Includes:** T8 (popups), T9 (onboarding + TestTab + orphan cleanup), T10 (verification sweep).
**Why last:** Popups depend on Phase 1 primitives but should ship after the tabs because tabs are the visible surface where users see the design first. Verification (T10) runs after everything else.
**Exit criterion:** All 11 popups + onboarding + TestTab updated; zero orphaned files; verification sweep passes; maker visual sign-off complete.

## Task Breakdown

##### T1: Theme & token foundation
- **Phase:** 1 | **Parallel:** no | **Est:** 1.5d | **Depends:** — | **Complexity:** moderate
- **What:** Create `lib/configs/app_theme.dart` defining `AppTheme.light()` returning a complete `ThemeData` plus the constant classes `AppColors`, `AppSpacing`, `AppRadius`, `AppElevation`, `AppTypography`, and the `ThemeExtension<AppSemanticColors>`. Wire `MaterialApp(theme: AppTheme.light(), ...)` in `lib/main.dart`. Component themes must cover AppBar, NavigationBar, Card, Chip, FilledButton, OutlinedButton, TextButton, InputDecoration, Dialog, BottomSheet. Token values are exactly those specified in PRD FR-1.
- **Key files:** `lib/configs/app_theme.dart` (new), `lib/configs/configs.dart` (barrel), `lib/main.dart` (theme wiring)
- **PRD requirements:** FR-1, NFR-2 (no provider/service touched)
- **Key risk:** Forgetting a component theme override causes that widget type to render with stock Material 3 defaults — silent visual drift.
- **Interface produces:** `AppTheme.light()` function + `AppColors`/`AppSpacing`/`AppRadius`/`AppElevation`/`AppTypography` constants + `AppSemanticColors` ThemeExtension consumable by all downstream tasks.

##### T2: Plus Jakarta Sans font asset
- **Phase:** 1 | **Parallel:** yes | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Drop TTFs (`Regular`, `Italic`, `Medium`, `SemiBold`, `Bold` — 5 files) into `assets/fonts/`. Replace the existing Poppins block in `pubspec.yaml > flutter > fonts` with a `PlusJakartaSans` family declaring all 5 weights. Run `fvm flutter pub get`. T1 wires `fontFamily: 'PlusJakartaSans'`. Verify airplane-mode rendering on device.
- **Key files:** `pubspec.yaml`, `assets/fonts/PlusJakartaSans-*.ttf` (5 new files)
- **PRD requirements:** FR-2, NFR-3
- **Key risk:** Font file delivery delayed (Dependencies section flags this); fallback to system font silently masks the bug.
- **Interface produces:** Font family `'PlusJakartaSans'` registered and available to T1's text theme.

##### T3: Shared UI primitives
- **Phase:** 1 | **Parallel:** yes (after T1) | **Est:** 1d | **Depends:** T1 | **Complexity:** simple
- **What:** Create `lib/components/icon_square.dart` (the `IconSquare` widget per AD-3) and `lib/components/section_label.dart` (small-caps gray label for `EXPENSE DETECTED` / `TODAY` / `September Transactions` style). Export both from `lib/components/components.dart`. Decide whether to add a `pill_chip.dart` wrapper or rely on the themed `Chip` directly — prefer themed `Chip` unless its `shape` override doesn't deliver the pill curve.
- **Key files:** `lib/components/icon_square.dart` (new), `lib/components/section_label.dart` (new), `lib/components/components.dart` (barrel)
- **PRD requirements:** FR-1 (token consumption), NFR-1 (DRY enforcer)
- **Key risk:** Primitive API too rigid → tab tasks bypass it and inline their own version → token drift.
- **Interface produces:** `IconSquare({icon, tint, size})` + `SectionLabel(text)` widgets imported by tab tasks.

##### T4: App shell chrome (AppBar + drawer + bottom nav)
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Depends:** T1, T3 | **Complexity:** moderate
- **What:** Modify `lib/screens/home/home_screen.dart` to replace the current `AppBar` with the new design (hamburger leading, avatar placeholder beside it, "Wally AI" wordmark in `AppColors.primary` SemiBold, notification bell trailing). Switch `BottomNavigationBar` to `NavigationBar` (Material 3) with `NavigationDestination` items; wrap the TestTab destination + `PageView` page in `if (kDebugMode)` blocks (AD-5) so release builds expose exactly 3 tabs. Drawer remains globally accessible — re-skin only.
- **Key files:** `lib/screens/home/home_screen.dart` (modified)
- **PRD requirements:** FR-3, FR-4, AD-5
- **Key risk:** Tab-count change between debug/release breaks the `PageController.animateToPage(index)` math if a hardcoded `if (index == 3)` lurks somewhere. Audit `PageController` callers.
- **Interface produces:** Updated `HomeScreen` shell consumed by tab tasks (they render *inside* this shell).

##### T5: Assistant (Chat) tab redesign
- **Phase:** 2 | **Parallel:** yes | **Est:** 2d | **Depends:** T1, T3 | **Complexity:** complex
- **What:** Migrate `lib/screens/home/tabs/chat_tab.dart`, `lib/components/chat_bubble.dart`, `lib/components/suggested_prompts_bar.dart`, `lib/components/suggestion_banner.dart` to the new design language. Assistant/user bubble variants with `IconSquare` sparkle chip; AI-parsed expense card using `SectionLabel('EXPENSE DETECTED')` + amount in primary; suggested-prompt chips as outlined gray pills; input bar as pill with `+` (existing camera/gallery), text field, primary circular send. `SuggestionBanner` refactored **in-place** per AD-4: keep widget class, swap `FilledButton` → `TextButton` chips internally, preserve double-tap guard state machine. Update `suggestion_banner_test.dart` lines 130 and 156 (`find.byType(FilledButton)` → `find.byType(TextButton)`) — the only allowed test change. Streaming/auto-scroll behavior untouched.
- **Key files:** `lib/screens/home/tabs/chat_tab.dart`, `lib/components/chat_bubble.dart`, `lib/components/suggested_prompts_bar.dart`, `lib/components/suggestion_banner.dart`, `test/components/suggestion_banner_test.dart` (2-line update)
- **PRD requirements:** FR-5, NFR-2 (sole permitted test-line change)
- **Key risk:** Inline italic suggestion text + chip layout breaks long-message wrap; double-tap guard state machine subtly drifts when buttons change type.
- **Interface receives from T1, T3:** Theme, `IconSquare`, `SectionLabel`.

##### T6: Records tab redesign
- **Phase:** 2 | **Parallel:** yes | **Est:** 2d | **Depends:** T1, T3 | **Complexity:** complex
- **What:** Migrate `lib/screens/home/tabs/records_tab.dart`, `lib/components/records_overview.dart`, `lib/components/record_widget.dart`, `lib/components/date_divider.dart`. `RecordsOverview` rebuilt as three zones: Net Worth hero, Income/Expense tile pair (using `AppSemanticColors.incomeGreen` / `expenseRed`), horizontal money-source card row. Balance-mask toggle preserved (Net Worth + Income mask; Expense visible). `RecordWidget` rows use `IconSquare` with type-derived tint (`income → incomeGreen`, `expense → expenseRed`, `transfer → transferTint`). `DateDivider` uses `SectionLabel`. All edit/delete/mask behaviors unchanged.
- **Key files:** `lib/screens/home/tabs/records_tab.dart`, `lib/components/records_overview.dart`, `lib/components/record_widget.dart`, `lib/components/date_divider.dart`
- **PRD requirements:** FR-6
- **Key risk:** Money-source accent rule undefined in PRD (validation warning W2) — implementer must pick: sequential `categoryAccents[idx % 6]` or default to `AppColors.primaryContainer`. Recommend sequential index for visual variety; document choice in task PR.
- **Interface receives from T1, T3:** Theme, `IconSquare`, `SectionLabel`, `AppSemanticColors`.

##### T7: Categories tab redesign
- **Phase:** 2 | **Parallel:** yes | **Est:** 1.5d | **Depends:** T1, T3 | **Complexity:** moderate
- **What:** Migrate `lib/screens/home/tabs/categories_tab.dart` and `lib/components/category_widget.dart`. Top date-period pill (`< MMM yyyy >` in `AppColors.primaryContainer` rounded pill), `+ Add Category` filled primary pill button. Parent category rows as white `Card` with leading `IconSquare` (primary tint in v1; NTH-2 deferred), bold name + total, expand chevron, pencil edit. Sub-rows: white card with 3dp left border in `AppColors.primary`, name + total + pencil edit, no `IconSquare`. Preserve InkWell absorption pattern documented in `architecture.md`. Existing add/edit/expand/drill-down flows unchanged.
- **Key files:** `lib/screens/home/tabs/categories_tab.dart`, `lib/components/category_widget.dart`
- **PRD requirements:** FR-7
- **Key risk:** Breaking InkWell absorption (where setting `onTap` to non-null absorbs taps and stops `ExpansionTile` expansion on row-body) — a subtle interaction documented in `architecture.md` line 18.
- **Interface receives from T1, T3:** Theme, `IconSquare`, `SectionLabel`.

##### T8: Popups & dialogs (11 surfaces)
- **Phase:** 3 | **Parallel:** no (file conflicts on `popups/` barrel) | **Est:** 3d | **Depends:** T1, T3 | **Complexity:** complex
- **What:** Migrate all 11 modal surfaces in `lib/components/popups/`: `EditRecordPopup`, `EditSourcePopup`, `TransferPopup`, `TransferInfoPopup`, `ConfirmationDialog`, `CurrencySelectionPopup`, `AddSourcePopup`, `CategoryFormDialog`, `AddSubCategoryDialog`, `CategoryRecordsBottomSheet`, and `OnboardingDialog` (T9 handles onboarding *content* changes; this task handles its design migration). Pattern: themed `Dialog` / `showModalBottomSheet` container, `FilledButton` primary action, `OutlinedButton`/`TextButton` secondary, themed `InputDecoration` text fields, `ConfirmationDialog` destructive variant uses error color. All save/delete/dismiss callbacks byte-equivalent.
- **Key files:** `lib/components/popups/*.dart` (all 11 files)
- **PRD requirements:** FR-8
- **Key risk:** Long tail — 11 surfaces × ~30min each underestimates the friction of context-switching. Treat each popup as a sub-checkbox in the task PR.
- **Interface receives from T1, T3:** Theme + primitives.

##### T9: Onboarding + TestTab refactor + orphan cleanup
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Depends:** T5, T6, T7, T8 | **Complexity:** moderate
- **What:** Onboarding content/flow updated to consume new component styles (steps and CTAs unchanged per FR-9). TestTab refactored to use new themed buttons/cards/tiles — no visual design work, just swap stock widgets for themed equivalents. After all migrations, audit `lib/components/` and `lib/screens/` import graph: any `.dart` file not imported by any other file is deleted. No commented-out pre-redesign blocks remain.
- **Key files:** `lib/components/popups/onboarding_dialog.dart`, `lib/screens/home/tabs/test_tab.dart`, deletion candidates TBD by audit
- **PRD requirements:** FR-9, FR-10, NFR-6
- **Key risk:** Deleting a file that's referenced only via reflection or string import (none expected in this codebase but worth a `grep` before deleting).
- **Interface receives from T1, T3, T5–T8:** All themed components.

##### T10: Verification & polish pass
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Depends:** T1–T9 | **Complexity:** moderate
- **What:** Run the verification grep for `Color(0x…)` / `Colors.*` (excluding `transparent`) / numeric font sizes / numeric border radii in `lib/components/` and `lib/screens/` — expect zero matches. Run `grep -r "google_fonts" lib/` — expect empty. Run `fvm flutter test` and confirm zero failures + ≤2 modified test-assertion lines (the `suggestion_banner_test.dart` lines from T5). Take `flutter run --profile` cold-start trace and compare against pre-epic baseline (must be within +100ms). Manual WCAG AA contrast check on 5 named surfaces. Manual sweep against the SC-5 visual-review checklist: (a) primary brand surfaces, (b) Plus Jakarta Sans everywhere, (c) active nav pill, (d) tinted icon-squares, (e) pill input bar.
- **Key files:** No code changes expected; if violations found, fix in the relevant component file from T5–T9.
- **PRD requirements:** NFR-1, NFR-2 confirmation, NFR-4, NFR-5, NFR-6, SC-1 through SC-5
- **Key risk:** Late discovery of widespread NFR-1 violations forces back-tracking through T5–T8 with merge-conflict risk on the epic branch.
- **Interface receives from T1–T9:** Everything.

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| Hardcoded literals slip through during tab/popup migration | High | High | NFR-1 fails; visual drift; redesign feels half-done | T10 verification grep at epic close; consider adding a `dart_code_metrics` or `custom_lint` rule mid-epic if first sweep finds >5 violations |
| `SuggestionBanner` in-place refactor breaks double-tap guard subtly (state preserved but timing changes with `TextButton` vs `FilledButton`) | High | Medium | Chat suggestion confirm fires twice → duplicate category creation | T5 runs `suggestion_banner_test.dart` (double-tap guard test on line 114-139) after every internal change; if test passes, behavior is preserved |
| Font assets not delivered to `assets/fonts/` before T2 starts | High | High | T2 blocked; other tasks proceed with system font; visual review surprise at end | Make T2 explicit blocker for sign-off (not for other tasks); use placeholder `fontFamily: 'PlusJakartaSans'` referencing missing assets — text falls back to system but token machinery is verified |
| 11-popup long tail (T8) blows estimate | Medium | High | Phase 3 stretches; epic merge delayed | Treat each popup as a checklist item with separate commit; allow merging popup-by-popup to epic branch; if estimate slips >30%, escalate to splitting T8 into T8a/T8b |
| Money-source accent rule still undefined (PRD warning W2) | Low | High | Inconsistent decision across tab redesigns | T6 documents the chosen rule (sequential ramp index) in PR description; recorded as an Architecture Decision amendment if it differs from default |
| `home_widget` AAR metadata fix uncommitted on `main` before epic branch | Medium | Medium | Epic branch fails to build until the fix is merged | Commit the existing `android/app/build.gradle.kts` change to `main` before creating `epic/redesign-ui` branch |
| Test tab `if (kDebugMode)` change breaks `PageController.animateToPage(index)` math (tab indices shift) | Medium | Low | Drawer navigation lands on wrong tab in release builds | T4 audits all `_pageController.animateToPage(...)` and `BottomNavigationBar` index callers; use named constants for tab indices |
| Dark-mode scope creep — implementer "just adds dark colors while here" | Medium | Low | Token layer ships with broken dark mode; merge blocked on extra QA | Explicit Out of Scope reminder in T1 PR template; reviewer rejects any dark-mode token additions |

## Dependencies

- **Plus Jakarta Sans TTF assets** (Maker, **pending**) — 5 files for `assets/fonts/`. T2 blocked on delivery; all other tasks proceed in parallel with placeholder font declaration.
- **`home_widget` AAR metadata fix committed to `main`** (Dev, **pending**) — currently uncommitted on `main`. Must be committed before `epic/redesign-ui` branch creation, otherwise builds fail.
- **Existing test suite green on `main`** (Dev, **resolved**) — baseline for NFR-2 verification.

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
| --- | --- | --- | --- |
| SC-1 Visual consistency | All UI surfaces consume `Theme.of(context)` or `AppColors`/`AppSpacing` etc.; no widget bypasses the theme | 0 surfaces using stock Material 3 defaults | Manual screen-by-screen review against mockups at epic close |
| SC-2 Zero behavior regression | `fvm flutter test` pass count | 0 failures; ≤2 modified test-assertion lines | `fvm flutter test` output; `git diff main..epic/redesign-ui -- test/` |
| SC-3 Zero hardcoded literals | grep for `Color(0x…)` / `Colors.*` (excl. `transparent`) / numeric font sizes / numeric border radii in `lib/components/` + `lib/screens/` | 0 matches | T10 grep commands |
| SC-4 Font bundled correctly | Plus Jakarta Sans renders on all text surfaces in airplane mode | All weights (400/400i/500/600/700) render from local asset | Device test with airplane mode on; inspect `pubspec.yaml` font declarations |
| SC-5 Visual sign-off (5-point checklist) | (a) primary brand on app bar wordmark, (b) Plus Jakarta Sans on all text, (c) active nav pill visible, (d) tinted `IconSquare` on at least one category, (e) pill input bar | All 5 confirmed by maker on device screenshots | Maker review of release-build screenshots |

## Migration Strategy

Single `epic/redesign-ui` branch off `main`. Big-bang rollout — no feature flag.

**Phase ordering within the branch:**
1. **T1 + T2 + T3 + T4** land on the epic branch first. After this, the chrome (app bar, nav) looks new on every tab, even though tab interiors still use old layouts — this is acceptable transient state on the epic branch.
2. **T5, T6, T7** land in parallel (each tab is in a separate file with no widget cross-talk).
3. **T8 → T9 → T10** land sequentially.
4. **Final merge to `main`** after T10 passes and maker visual sign-off completes.

No partial cherry-picks of the epic branch — all-or-nothing.

## Rollback Plan

- **Full rollback:** `git revert <epic-merge-commit>` on `main`. No data-layer changes, no provider/service/repository edits, no schema migrations to unwind.
- **Partial rollback:** Individual widget files can be reverted independently — the token layer (T1) is purely additive and no behavior moves between files. A buggy `RecordWidget` can revert to its pre-epic version without touching `ChatBubble` or popups.
- **Rollback artifact:** `main` at the commit immediately before the epic merge. Tag it `pre-redesign-ui` before merging for easy reference.

## Estimated Effort

- **Total:** ~14.5 days of focused work (10 tasks).
- **Critical path:** T1 (1.5d) → T3 (1d) → T4 (1d) → T5/T6/T7 in parallel (longest = T5 = 2d) → T8 (3d) → T9 (1d) → T10 (1d) = **10.5 days** if T5/T6/T7 truly parallelize.
- **Solo serial estimate:** ~14.5 days (sum of all task estimates).
- **Phases:** P1 = ~4 days, P2 = ~5.5 days, P3 = ~5 days.

## Deferred / Follow-up

- **NTH-1 (FAB on Records)** — deferred; quick-action target undefined. Spin up as a separate small PRD when the trigger action is decided.
- **NTH-2 (Per-category accent assignment)** — partially included: the 6-step `categoryAccents` ramp is defined in `AppSemanticColors` (T1), but assignment per category remains primary-tint default. The follow-up PRD will add a `Category.accentIndex` field + assignment UI in `CategoryFormDialog`.
- **Dark mode** — deferred to a follow-up PRD that adds `ThemeData.dark()` to `AppTheme` and a `AppSemanticColors.dark` variant. The `ThemeExtension` pattern chosen in AD-2 makes this drop-in.
- **`custom_lint` rule for NFR-1** — considered but not included; T10's grep is sufficient for v1. Worth a small follow-up if the verification sweep finds violations regularly in future PRs.
- **"Insights" tab** — out of scope; requires its own PRD for content design before UI implementation.
- **Animation / motion design** — out of scope; defer until a "polish v2" pass.
