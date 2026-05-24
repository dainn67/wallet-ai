---
epic: redesign-ui
task: 203
status: completed
created: 2026-05-24T09:15:00Z
updated: 2026-05-24T09:15:00Z
---

## What was done

Migrated `lib/screens/home/home_screen.dart` to the new design system shell:
- **AppBar**: hamburger leading (`Icons.menu`) opens drawer via `Builder` + `Scaffold.of(context).openDrawer()`; "Wally AI" wordmark in `AppColors.primary` SemiBold via `titleLarge`; notification bell trailing (placeholder `onPressed: () {}`). `elevation: AppElevation.none`, `surfaceTintColor: Colors.transparent`, `backgroundColor: colorScheme.surface`.
- **NavigationBar** (Material 3): replaced `TabBar`/`TabBarView`/`TabController` with `NavigationBar` + `PageView` + `PageController`. `selectedIndex: _currentIndex`, `onDestinationSelected` updates state + calls `_pageController.animateToPage(...)`.
- **kDebugMode compile-time gate** (AD-5): `_pages` list built once in `initState` with `if (kDebugMode)` for `TestTab`. A `_buildTabs(l10n)` method in `build()` mirrors the same gate to derive `_TabConfig` objects with live locale labels. Index math is always consistent: both lists have the same kDebugMode gate.
- **Drawer reskin**: no structural/callback changes. Colors replaced with `colorScheme.surface` (background), `AppColors.onSurface`/`AppColors.primary` (icons/text), `AppColors.error` (delete tile). `SectionLabel` used for settings header (auto-uppercases). Font sizes via `Theme.of(context).textTheme.*`.
- **No hardcoded literals**: no `Color(0x...)`, no numeric font sizes, no `BorderRadius.circular(N)`. `Colors.white` only in drawer header gradient overlay (no token alternative).

## Files changed

- `lib/screens/home/home_screen.dart` — MODIFIED: complete redesign. `TabController` → `PageController`. `TabBar`/`TabBarView` → `NavigationBar`/`PageView`. New AppBar. Drawer reskin using tokens. `kDebugMode` compile-time gate for `TestTab`.
- `test/screens/home_screen_test.dart` (in `/test/screens/`, not `/test/screens/home/`) — MODIFIED: updated `TabBar` assertion to `NavigationBar`; changed `find.text('Settings')` to `find.text('SETTINGS')` (because `SectionLabel` uppercases); added `drawer_categories` key to mock translations.
- `test/widget_test.dart` — MODIFIED: removed assertion for `find.textContaining('(dev)')` which was for the old `_buildAppBarTitle()` subtitle — new AppBar shows clean wordmark only.

## Key decisions

- **Runtime dev toggle removed**: The old 10-tap title gesture toggled `AppConfig().devMode` at runtime. The new AppBar has a static "Wally AI" title with no tap handler. The kDebugMode gate is compile-time only — runtime tab count no longer changes. If the 10-tap dev toggle behavior is needed, it must be re-added elsewhere (e.g., Settings screen in a future task).
- **`AppConfig().devMode` preserved for onboarding**: The `postFrameCallback` that shows `OnboardingDialog` still uses `AppConfig().devMode` (not `kDebugMode`) because that's a runtime UX choice for devs, not a compile-time concern.
- **Locale labels in `_buildTabs`**: Tab labels are resolved from `LocaleProvider` in `build()` via `_buildTabs(l10n)`. This supports runtime language switching. The `_pages` list in `initState` holds stable widget instances (avoids unnecessary rebuilds of tab page widgets on locale changes).
- **`Colors.white` in drawer header**: The gradient header uses `Colors.white.withValues(alpha: 0.15)` for the avatar background and `Colors.white` for text. There is no `AppColors.onPrimary`-equivalent that fits a multi-color gradient overlay context; this is acceptable as a gradient-specific pattern.

## Warnings for T5–T9

- **Shell structure**: Each tab page renders inside `PageView` > `Scaffold` > `body`. The outer `HomeScreen` Scaffold owns the `AppBar`, `Drawer`, and `NavigationBar`. Tab pages (ChatTab, RecordsTab, CategoriesTab) should NOT have their own `AppBar` — they render inside the HomeScreen shell.
- **PageView physics**: `NeverScrollableScrollPhysics` is set — users cannot swipe between tabs. Only `NavigationBar` taps trigger page changes. If T5/T6/T7 need swipe-to-navigate they must change `physics` in `home_screen.dart`.
- **TestTab (debug only)**: In release builds the TestTab does not exist. Its `NavigationDestination` is compile-out. Index 3 (debug only) must never be hardcoded anywhere — always derive from `_buildTabs` length.
- **kDebugMode vs AppConfig().devMode**: These are now independent. `kDebugMode` gates the TestTab tab. `AppConfig().devMode` gates the OnboardingDialog auto-show. Do not conflate them.
- **SectionLabel uppercases**: When displaying drawer section headers with `SectionLabel`, pass the raw lowercase string — the widget auto-uppercases. Tests that assert text in the drawer section header must match the uppercased form (e.g., `'SETTINGS'` not `'Settings'`).

## Test counts

228 pass, 14 fail — exactly matches the pre-T4 baseline. The 14 failures are all pre-existing in `edit_source_popup_test.dart` and `records_overview_test.dart` (unrelated to home screen).
