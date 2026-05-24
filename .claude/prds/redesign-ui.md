---
name: redesign-ui
description: Complete visual redesign of Wally AI with a centralized design token system, Plus Jakarta Sans font, and a new design language — flows and behavior preserved.
status: complete
priority: P1
scale: large
created: 2026-05-24T07:10:32Z
updated: 2026-05-24T10:28:29Z
---

# PRD: redesign-ui

## Executive Summary

We are replacing Wally AI's ad-hoc, UX-first UI with a coherent product design system: a centralized theme layer built on color tokens (`#8B5CF6` primary violet, `#F9FAFB` surface, `#EC4899` tertiary pink, `#1F2937` neutral text), Plus Jakarta Sans as the app font (local asset), and a component vocabulary of pill shapes, tinted icon-squares, semantic color cards, and sparkle-motif AI surfaces. Every screen — three production tabs (Assistant, Records, Categories), the global drawer, bottom navigation, and all eleven modal popups — is migrated in a single big-bang epic. Core flows, business logic, and the data layer are byte-equivalent; only visual presentation changes. The redesign positions the app competitively for Play Store/App Store listings and creates a token-driven foundation that dark mode and future design iterations can build on without accruing additional visual debt. The app has reached feature maturity; this redesign addresses the compounding debt of scattered hardcoded values by centralizing every visual decision into a single token layer — making future features coherent by default.

## Problem Statement

Users opening Wally AI today encounter a functional but visually undifferentiated interface: stock Material 3 defaults, ad-hoc padding and color values scattered across widget files, and no unified component vocabulary. Every screen feels authored independently — icon styles are inconsistent, spacing is arbitrary, and the absence of brand personality makes the app indistinguishable in store screenshots or side-by-side comparisons with competitors. The experience works but lacks the polish that makes users proud to share it or confident to recommend it. Design quality is now the primary gap between where the app is and where it needs to be for confident, proud distribution.

## Target Users

**Casual budget keeper (primary)**
- Context: Opens the app multiple times per week to log transactions via chat; checks monthly totals on the Records tab.
- Primary need: An interface that feels as polished and intentional as the AI features it wraps.
- Pain level: Medium — current UI doesn't block tasks but lacks the "product feel" that drives organic sharing and retention.

**Maker / product owner (secondary)**
- Context: Shipping to Play Store, reviewing store screenshots, planning future features.
- Primary need: A design system where each new feature looks coherent without extra design-debt cleanup.
- Pain level: High — today, adding any visual-facing feature requires auditing scattered hardcoded values across multiple files.

## User Stories

**US-1: Consistent visual experience**
As a casual budget keeper, I want every screen to feel like part of the same app so that I don't notice visual seams when navigating between tabs or opening popups.

Acceptance Criteria:
- [ ] All three production tabs share the same color palette, typography scale, and spacing rhythm.
- [ ] All eleven popups use the same card, button, and input styles as the tabs they appear in.
- [ ] No widget file contains a hardcoded color hex, font size, or border radius literal.

**US-2: Brand-forward first impression**
As a maker, I want the app's visual identity to be immediately recognizable (purple brand, clean typography, rounded UI language) so that store screenshots communicate quality without explanation.

Acceptance Criteria:
- [ ] Top app bar displays "Wally AI" in `colorScheme.primary` Plus Jakarta Sans SemiBold.
- [ ] Active bottom nav tab shows its icon inside a filled primary-tinted pill, visually distinct from inactive tabs.
- [ ] Category and transaction icon-squares use semantically tinted backgrounds, not generic gray.

**US-3: Zero behavior regression**
As a casual budget keeper, I want every existing interaction — logging a transaction, editing a record, transferring between sources, viewing categories — to work exactly as before so that I don't need to re-learn anything after the update.

Acceptance Criteria:
- [ ] All existing unit and widget tests pass; the only permitted assertion changes are the two `find.byType(FilledButton)` lines in `suggestion_banner_test.dart` updated to match the replacement widget type.
- [ ] Chat streaming, auto-scroll, suggested-prompt chips, and suggestion banner all function identically.
- [ ] All popup dismiss, save, delete, and confirm flows produce identical outcomes.

**US-4: Scalable token foundation**
As a maker, I want all visual values (colors, type scale, spacing, elevation, radius) defined in one place so that future iterations — including dark mode — require changes only in the theme layer.

Acceptance Criteria:
- [ ] A single `AppTheme` class defines the complete `ThemeData` for light mode.
- [ ] Changing the primary color in one place propagates correctly across all surfaces.
- [ ] No color, font size, spacing, or border radius value appears as a literal in widget files.

## Requirements

### Functional Requirements (MUST)

**FR-1: Centralized theme & token layer**
A single `AppTheme` class (e.g., `lib/configs/app_theme.dart`) defines the full Material 3 `ThemeData` for light mode, including: `ColorScheme` seeded from `#8B5CF6` with explicit overrides for primary / secondary / tertiary / neutral / surface / error; semantic extension tokens for income-green (`#22C172`), expense-red (`#EF4444`), and a six-step category-accent ramp (`#8B5CF6` violet · `#3B82F6` blue · `#F97316` orange · `#EC4899` pink · `#10B981` emerald · `#6B7280` slate); text theme mapping all Material type roles to Plus Jakarta Sans; component themes for AppBar, BottomNavigationBar, Card, ElevatedButton, OutlinedButton, TextButton, InputDecoration, Chip, Dialog, and BottomSheet; and a named constant set for spacing steps (4/8/12/16/20/24px), border radius steps, and elevation levels. All semantic token values must satisfy WCAG AA contrast against their respective backgrounds before implementation is accepted.

Scenario: Token propagation
- GIVEN the app is built in release mode
- WHEN `AppTheme.primary` is changed from `#8B5CF6` to any other hex value
- THEN every surface that renders using the primary color updates without touching any widget file

Scenario: No hardcoded visual literals
- GIVEN a code review or static analysis of `lib/components/` and `lib/screens/`
- WHEN checking for `Color(0x…)`, `Colors.*` (excluding `Colors.transparent`), numeric font sizes, and numeric border radius literals
- THEN zero violations are found

**FR-2: Plus Jakarta Sans font wiring**
Plus Jakarta Sans is registered as a local asset in `pubspec.yaml` under `assets/fonts/`. Required weights: Regular 400, Regular Italic 400i (used by FR-5 inline suggestion text), Medium 500, SemiBold 600, Bold 700. `ThemeData.fontFamily` is set to `'PlusJakartaSans'`. No `google_fonts` package import is introduced anywhere in `lib/`.

Scenario: Font renders in airplane mode
- GIVEN the device has no network connectivity
- WHEN any text widget renders (app bar title, body text, chip label, input placeholder)
- THEN Plus Jakarta Sans renders correctly from the bundled asset with no fallback to a system font

Scenario: Bold weight is not synthesized
- GIVEN a widget using `FontWeight.w700`
- WHEN rendered on a physical device
- THEN the Plus Jakarta Sans Bold TTF variant is used (not a synthesized bold stroke)

**FR-3: App bar & global drawer redesign**
The top app bar renders on all tabs with: hamburger/menu icon (leading), circular avatar placeholder (beside the menu icon), "Wally AI" wordmark in `colorScheme.primary` SemiBold (center or trailing the avatar), and a notification bell icon (trailing). Background is `colorScheme.surface` (white), zero elevation, thin bottom divider using `colorScheme.outlineVariant`. The drawer remains globally accessible from all tabs (no tab-specific drawer restriction).

Scenario: App bar is identical on all tabs
- GIVEN the user navigates between Assistant, Records, and Categories tabs
- WHEN the app bar renders on each tab
- THEN hamburger, avatar, wordmark, and bell appear identically; only the page content below changes

Scenario: Drawer accessible from Records tab
- GIVEN the user is on the Records tab
- WHEN the hamburger icon is tapped
- THEN the global navigation drawer opens identically to opening it from the Assistant tab

**FR-4: Bottom navigation redesign**
Four tabs in order: Assistant (sparkle icon), Records (receipt/list icon), Categories (tag/grid icon), Test (wrench icon). The Test tab item is wrapped in `if (kDebugMode)` so it is compiled out of release builds — only three tabs appear in production. Active state: icon inside a filled `colorScheme.primaryContainer` rounded-pill with `colorScheme.primary` icon color and primary-colored label. Inactive state: `colorScheme.onSurfaceVariant` icon and label, no background pill.

Scenario: Active pill renders on correct tab
- GIVEN the user taps the Categories tab
- WHEN the bottom nav renders
- THEN the Categories item shows its icon inside a filled primary-tinted pill; the other visible tabs show plain icons

Scenario: Test tab absent in release build
- GIVEN the app is launched from a release (`--release`) build
- WHEN the bottom navigation bar renders
- THEN exactly three tabs are shown: Assistant, Records, Categories

**FR-5: Assistant (Chat) tab redesign**
Migrate `ChatTab`, `ChatBubble`, `SuggestedPromptsBar`, `SuggestionBanner`, and the AI-parsed-record card inside chat to the new design language. Required visual changes:
- Tab background: `colorScheme.surfaceVariant` (pale lavender tint)
- Assistant bubbles: white rounded cards (`borderRadius` from token), leading small lavender square chip with sparkle icon
- User bubbles: white rounded cards, right-aligned, trailing dark circular avatar
- Inline AI suggestion — **refactor `SuggestionBanner` in-place** (widget class and file preserved): change internal rendering from a card with `FilledButton` actions to inline italic body text + `TextButton`/chip-style confirm and cancel. The `SuggestionBanner` class remains instantiated by `ChatBubble`; `find.byType(SuggestionBanner)` in tests continues to work. The double-tap guard behavior (confirm fires exactly once; button disabled during processing; re-enabled after error) is preserved. Visual-structure test assertions that reference `FilledButton` by type (`suggestion_banner_test.dart` lines 130, 156) must be updated to the replacement widget type — this is the only permitted test-assertion change under NFR-2.
- Suggested-prompt chips: outlined gray pills horizontally scrollable below the chat list
- Action chips (Confirm / Edit / View): outlined pill; primary chip uses `colorScheme.primary` label color
- AI-parsed expense card in bubble: `EXPENSE DETECTED` small-caps label in `colorScheme.primary`, entity icon-square, amount in `colorScheme.primary` bold
- Input bar: single rounded-pill container with `+` (attach, existing camera/gallery feature), placeholder text, and circular primary send button (no mic icon)

All streaming behavior, auto-scroll, and bubble state (`isAnalyzing`, `isStreaming`) remain unchanged.

Scenario: Streaming assistant bubble uses new style
- GIVEN the user sends a message and the assistant begins streaming
- WHEN the assistant bubble appears with `isAnalyzing: true`
- THEN the bubble renders as a white rounded card with sparkle chip; auto-scroll to bottom fires on every chunk

Scenario: Image attach preserved, no mic
- GIVEN the user taps the `+` icon in the redesigned input bar
- WHEN the attachment bottom sheet appears
- THEN camera and gallery options are shown and functional; no microphone option is present

**FR-6: Records tab redesign**
Migrate `RecordsTab`, `RecordsOverview`, `RecordWidget`, and `DateDivider` to the new design language. Required structural changes to the overview card:
- Zone 1: "Net Worth" small label + large bold total amount (existing balance-mask toggle preserved)
- Zone 2: Income tile (green semantic tint, up-arrow icon) and Expense tile (red semantic tint, down-arrow icon) side-by-side
- Zone 3: Horizontally scrolling row of money-source cards with per-source accent color

Transaction rows: leading rounded icon-square with entity-semantic tint, bold title, gray category+time subtitle, right-aligned colored amount (income = green semantic token, expense = red semantic token), trailing pencil edit icon. Day-group dividers use small-caps gray `TODAY` / `YESTERDAY` / date string. All edit, delete, and balance-mask flows unchanged.

Scenario: Overview zones all render with data
- GIVEN the Records tab is open with at least one record, one income, one expense, and one money source
- WHEN the overview section renders
- THEN Net Worth zone, Income/Expense tiles, and money-source card row are all visible in the correct layout

Scenario: Balance mask applies correctly
- GIVEN the user taps the eye icon to mask balances
- WHEN the overview re-renders
- THEN Net Worth and Income amounts display as `*****`; Expense amount remains visible (existing behavior)

**FR-7: Categories tab redesign**
Migrate `CategoriesTab` and `CategoryWidget` to the new design language:
- Date period pill selector at top: `< Month Year >` inside a `colorScheme.primaryContainer` rounded-pill; tapping arrows changes month (existing behavior)
- "Categories" section label (left) + filled primary pill `+ Add Category` button (right)
- Parent category card: white rounded card with tinted icon-square, bold name, monthly total, expand/collapse chevron, pencil edit
- Expanded state inserts: dashed `+ Add Subcategory` ghost button, then subcategory rows as white cards with left vertical `colorScheme.primary` accent bar (3–4dp wide), name, total, pencil edit (no icon-square on sub-rows)
- All add, edit, expand/collapse, and drill-down flows unchanged

Scenario: Expanded parent shows ghost button and sub-rows
- GIVEN a parent category with two subcategories is in the expanded state
- WHEN rendered
- THEN the `+ Add Subcategory` ghost button appears above the two sub-rows; each sub-row shows a left purple accent bar and no icon-square

Scenario: Date period navigation works
- GIVEN the user is on the Categories tab showing May 2026
- WHEN the left arrow `<` is tapped
- THEN the period changes to April 2026 and category totals recalculate (existing behavior unchanged)

**FR-8: Popup & dialog redesign**
Migrate all eleven modal surfaces to the new design language — rounded cards, token-driven spacing/colors/typography, Plus Jakarta Sans, primary-colored primary action buttons:
1. `EditRecordPopup` — date+time picker, amount, category, source, delete button
2. `EditSourcePopup` — source name, balance, transfer icon
3. `TransferPopup` — from/to source selector, amount, note
4. `TransferInfoPopup` — read-only transfer summary + delete
5. `ConfirmationDialog` — generic confirm/cancel
6. `CurrencySelectionPopup` — currency picker list
7. `OnboardingDialog` — multi-step first-launch flow (see FR-9)
8. `AddSourcePopup` — source name + initial balance
9. `CategoryFormDialog` — category name + type
10. `AddSubCategoryDialog` — sub-category name
11. `CategoryRecordsBottomSheet` — drill-down record list for a category

All save, delete, confirm, and dismiss behaviors are byte-equivalent to pre-redesign.

Scenario: Edit record popup opens in new style
- GIVEN the user taps the pencil icon on a transaction row
- WHEN `EditRecordPopup` opens
- THEN it renders with rounded card, token-driven colors and typography; tapping Save produces the identical record update as before the redesign

Scenario: Confirmation dialog cancels correctly
- GIVEN a delete flow opens `ConfirmationDialog`
- WHEN the user taps Cancel
- THEN the record is NOT deleted, the dialog closes, and the underlying screen is unchanged

**FR-9: Onboarding redesign**
`OnboardingDialog` is updated to the new design system (card style, typography, button treatment, color palette). The number of steps, their content, and the completion/skip behaviors are unchanged.

Scenario: First-launch onboarding completes
- GIVEN the app is freshly installed and onboarding has not been completed
- WHEN the user steps through all onboarding screens and taps the final CTA
- THEN onboarding is marked complete in storage and the main screen appears (identical to pre-redesign behavior)

**FR-10: TestTab refactor & orphan cleanup**
`TestTab` is refactored to use new shared components (buttons, cards, list tiles) where applicable — no visual design work. After the full migration, any widget file in `lib/components/` or `lib/screens/` that is no longer imported by any other file is deleted.

Scenario: TestTab renders in debug mode
- GIVEN the app is run with `flutter run` (debug mode)
- WHEN the user navigates to the 4th tab
- THEN `TestTab` renders correctly using new shared components; all test actions remain functional

Scenario: No orphaned widget files remain
- GIVEN the migration is complete and all tabs + popups are migrated
- WHEN `lib/components/` is audited for unused files
- THEN every `.dart` file in the directory is imported by at least one other file

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Floating Action Button on Records tab**
A purple circular FAB with a quick-action icon (e.g., lightning bolt or plus) pinned above the bottom nav on the Records tab. Target action is TBD — deferred because the intended flow is undefined.

Scenario: FAB is visible while scrolling
- GIVEN the Records tab is open
- WHEN the user scrolls the transaction list
- THEN the FAB remains pinned above the bottom nav at all scroll positions

**NTH-2: Per-category accent color assignment**
Each category is assigned an accent color from a defined ramp (purple, blue, peach, pink, orange, gray) that drives its icon-square tint. In v1, all icon-squares default to the primary color tint. This NTH adds the per-category mapping.

Scenario: Food category uses purple accent
- GIVEN a "Food & Dining" category
- WHEN rendered in the Categories list
- THEN its icon-square background uses the purple accent color defined in the ramp

### Non-Functional Requirements

**NFR-1: Zero hardcoded visual literals in widget files**
No `Color(0x…)`, `Colors.*` (except `Colors.transparent`), numeric font size literals, numeric border radius literals, or numeric padding literals in any file under `lib/components/` or `lib/screens/`. All values reference `Theme.of(context)`, `AppTheme` constants, or named spacing/radius tokens.

Threshold: 0 violations — verified by PR review checklist on every widget file touched.

**NFR-2: Behavioral parity**
`fvm flutter test` returns zero failures on the epic branch. Provider, repository, service, and model files are untouched except for compile-error fixes caused by renamed shared components. Behavior-linked test assertions must not change (e.g., confirm fires once, cancel fires once, double-tap guard prevents re-entry, balance-mask toggles correctly). The sole permitted visual-structure test change is updating `find.byType(FilledButton)` in `suggestion_banner_test.dart` lines 130 and 156 to match the replacement widget type introduced by FR-5's in-place refactor.

Threshold: 0 test failures. ≤ 2 test-assertion lines modified (the two `FilledButton` type-finders in `suggestion_banner_test.dart`).

**NFR-3: Font locally bundled**
Zero `google_fonts` package imports in `lib/`. All font weights used by the app are declared in `pubspec.yaml` and present as TTF files in `assets/fonts/`.

Threshold: `grep -r "google_fonts" lib/` returns empty. `pubspec.yaml` lists all used weights.

**NFR-4: Cold-start performance budget**
The redesigned app cold-starts within the pre-redesign baseline + 100ms on a mid-range Android device (Pixel 4a class or equivalent), measured via `flutter run --profile` timeline trace.

Threshold: ≤ baseline + 100ms cold-start time.

**NFR-5: Accessibility — contrast & tap targets**
All text/background color pairs on primary user paths meet WCAG AA (≥4.5:1 body text, ≥3:1 large text). All interactive elements have a minimum tap target of 48×48dp.

Threshold: 0 violations on: chat input bar, bottom nav tabs, transaction row edit icon, popup primary actions, category expand chevron.

**NFR-6: Codebase cleanliness**
After migration: no orphaned widget files, no commented-out pre-redesign code blocks, no `// TODO: old style` stubs, no dead constants from the pre-redesign style layer.

Threshold: Zero unused files in `lib/components/` and `lib/screens/` (verified by import analysis or manual audit at epic close).

## Success Criteria

1. **Visual consistency** — A screen-by-screen review of all three production tabs + drawer + all eleven popups confirms zero surfaces still using pre-redesign stock Material 3 defaults. Verified by maker sign-off before merge.
2. **Zero behavior regression** — `fvm flutter test` passes 100% on the epic branch with no test-assertion changes. Measured on every PR in the epic.
3. **Zero hardcoded literals** — PR review checklist confirms no `Color(0x…)`, `Colors.*` (except transparent), or numeric visual literals in widget files. Verified at each PR review.
4. **Font bundled correctly** — App runs in airplane mode and renders Plus Jakarta Sans on all text surfaces. Verified by manual QA on a physical device.
5. **Visual sign-off** — A screen-by-screen review against the reference mockups confirms: (a) correct primary color on all brand surfaces, (b) Plus Jakarta Sans renders on all text, (c) active bottom-nav pill state visible, (d) at least one category icon-square with tinted background, (e) input bar is pill-shaped. All five points pass with zero open discrepancies before epic close. Verified by maker review of device screenshots.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| Hardcoded values slip through — tokens defined but widgets bypass them | High | High | NFR-1 checklist item on every widget PR; consider a custom `custom_lint` rule to flag `Color(0x…)` in `lib/components/` and `lib/screens/` |
| Popup long tail — 11 popups is more work than the tab surfaces | Medium | High | Each popup is a separate task in the epic; track independently; merge tab phases first to prove the system before touching popups |
| Chat behavior regression — streaming, auto-scroll, bubble state | High | Medium | `ChatProvider` and `ChatApiService` are completely untouched; changes are widget-only; manually exercise chat streaming flow after every Chat tab PR |
| Font weight gap — Plus Jakarta Sans weights not bundled or synthesized | Medium | Medium | Verify all declared weights render correctly (not synthesized bold) on a physical device before closing FR-2; block the epic on FR-2 completion |
| Font assets not delivered before implementation | High | High | FR-2 is a hard dependency for FR-5–FR-9 typography; all tasks can use a placeholder font declaration and swap to the real asset once delivered |
| Dark mode scope creep — "add dark mode while we're in here" | Medium | Low | Dark mode is explicit Out of Scope; any dark-mode token work is deferred to a follow-up PRD; added as an assumption in the epic kickoff |

## Constraints & Assumptions

**Constraints:**
- Flutter/Dart SDK pinned by FVM (`.fvmrc`) — no Flutter upgrade in this PRD.
- AGP 8.9.1, compileSdk 36 — Android toolchain frozen.
- `google_fonts` package is prohibited — all fonts must be local assets.
- Providers, repositories, services, models, and API layer are read-only in this PRD — no behavior changes.
- Light mode only. Dark mode is explicitly deferred.

**Assumptions:**
- Plus Jakarta Sans TTF files (400/500/600/700) will be delivered to `assets/fonts/` before FR-2 begins. If wrong: all other FRs proceed using a system-font placeholder; FR-2 unblocks when assets arrive.
- Material 3 `ThemeData` is sufficient as the base — no custom design-system framework needed. If wrong: a lightweight `BuildContext` extension for semantic tokens adds approximately one extra task.
- The 11 popup surfaces listed in FR-8 are exhaustive. If wrong: any discovered additional popup is added to FR-8's task scope without requiring a PRD amendment.
- `kDebugMode` is an acceptable gate for hiding the TestTab in release builds. If wrong: a build-flavor or compile-time `const bool` approach is substituted.
- Existing widget and unit tests are sufficient to catch behavior regressions. If wrong: additional widget tests for chat streaming and popup save/delete flows are written before the migration begins.

## Out of Scope

- **Dark mode** — explicit decision; deferred to a follow-up PRD building on the token layer created here.
- **"Insights" tab** — not yet built; not in this PRD.
- **Animation / motion design** — beyond Material 3 defaults (no custom transitions, micro-interactions, or Lottie assets).
- **Voice input / mic affordance** — input bar retains existing image upload (`+` icon); no mic icon added.
- **Floating Action Button on Records** — NTH-1; deferred unless explicitly added to scope.
- **Per-category accent color ramp** — NTH-2; all icon-squares default to primary tint in v1.
- **TestTab visual redesign** — FR-10 is refactor-only; TestTab is a developer tool and receives no new design.
- **Any change to providers, repositories, services, models, or API layer.**
- **Any change to business logic, data flow, or user-facing behavior.**

## Dependencies

- **Plus Jakarta Sans font assets** — Maker — Status: **pending** (TTF files 400/500/600/700 must be placed in `assets/fonts/` before FR-2 task begins; all other tasks proceed in parallel with a placeholder font declaration).
- **Existing test suite green on `main`** — Dev — Status: **resolved** (confirmed passing).
- **`home_widget` AAR metadata fix** — Dev — Status: **pending commit** (fix applied locally; must be committed before epic branch creation to avoid merge conflicts).

## Migration Strategy

**Rollout approach:** Big-bang on a single `epic/redesign-ui` branch. No feature flag, no parallel UI.

**Phase 1 — Foundation** (blocks Phases 2 and 3):
- FR-1: `AppTheme` class with full `ColorScheme`, text theme, component themes, spacing/radius/elevation constants.
- FR-2: Plus Jakarta Sans local asset wiring.
- FR-3 + FR-4: App bar, drawer, bottom nav chrome — visible immediately on all tabs once merged.

**Phase 2 — Tab surfaces** (parallelizable after Phase 1):
- FR-5: Assistant tab, chat bubbles, suggested prompts, inline suggestion, expense card, input bar.
- FR-6: Records tab, overview zones, record rows, date dividers.
- FR-7: Categories tab, category cards, sub-row accent bars, date period pill.

**Phase 3 — Popups & cleanup** (after Phase 2 tabs are stable):
- FR-8: All eleven popup/dialog surfaces.
- FR-9: Onboarding.
- FR-10: TestTab refactor + orphan file deletion.

Final merge to `main` after maker visual sign-off and `fvm flutter test` green on the epic branch.

## Rollback Plan

This PRD covers UI-only changes with no data-layer, provider, or API contract modifications.

- **Full rollback:** Revert the epic branch merge commit on `main`. No database migration, provider change, or API contract change to undo.
- **Partial rollback:** Individual widget files can be reverted independently since the token layer is purely additive and no behavior logic moves between files.
- **Pre-merge rollback artifact:** The `main` branch at the commit immediately before the epic merge is the canonical rollback state.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7, FR-8, FR-9, FR-10]
  nice_to_have: [NTH-1, NTH-2]
  nfr: [NFR-1, NFR-2, NFR-3, NFR-4, NFR-5, NFR-6]
scale: large
discovery_mode: full
validation_status: warning
last_validated: 2026-05-24T07:22:15Z
