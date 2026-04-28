---
name: onboarding
status: completed
created: 2026-04-28T03:50:49Z
progress: 100%
priority: P1
prd: .claude/prds/onboarding.md
task_count: 4
github: https://github.com/dainn67/wallet-ai/issues/193
updated: 2026-04-28T05:07:27Z
completed: 2026-04-28T05:07:27Z
---

# Epic: onboarding

## Overview

Add a one-time, non-dismissible onboarding dialog shown on first app launch via a `showDialog` over `HomeScreen`, gated by a new `onboarding_complete` boolean key in the existing `StorageService` (SharedPreferences wrapper). The dialog is a self-contained `OnboardingDialog` widget using a `PageController`-driven `PageView` with `NeverScrollableScrollPhysics`, three configurable slides defined as a `const` list, `Next`/`Got it` buttons, and a `PopScope(canPop: false)` wrapper to block back-button/back-gesture dismissal on both Android and iOS. Implementation is tightly scoped — one new widget file, one storage key constant, one `HomeScreen.initState` post-frame callback, three placeholder image assets, and one `pubspec.yaml` asset declaration.

The approach favors the simplest reuse path: all infrastructure (Provider, StorageService, asset pipeline, MaterialApp/Scaffold) already exists; we only add a presentation layer. No new packages, no new services.

## Architecture Decisions

This is a SMALL-scale epic — architecture is captured inline in the Overview and per-component notes below. Two specific choices worth recording:

- **Trigger location: `HomeScreen.initState()` + `addPostFrameCallback`** — Not `main.dart`/`MyApp.build`. Reason: the dialog needs a valid `Navigator`/`Material` context, and `HomeScreen` is the first widget where both are guaranteed available. Post-frame callback ensures the first frame paints before the modal opens, avoiding visual flicker.
- **Dismissal blocking: `showDialog(barrierDismissible: false)` + `PopScope(canPop: false)`** — Not custom route. Reason: `showDialog` already blocks tap-outside via `barrierDismissible: false`; `PopScope` covers Android system back and iOS swipe-back when the dialog is on the navigation stack. No need for a full custom route.

## Technical Approach

### Widget Layer — `OnboardingDialog`
- **New file:** `lib/components/popups/onboarding_dialog.dart` (follows existing pattern from `lib/components/popups/category_records_bottom_sheet.dart`)
- Stateful widget owning a `PageController` and an `int _currentPage`.
- Body: `PopScope(canPop: false, child: Dialog(...))` containing:
  - `PageView` (physics: `NeverScrollableScrollPhysics`, `onPageChanged` updates `_currentPage`).
  - Each page: `Image.asset(slide.imageAsset)` above a `Text(slide.text)` block; sized to fit `MediaQuery` minus button row.
  - Bottom button: `ElevatedButton` labeled "Next" on slides 0–1 (advances via `_pageController.nextPage`) or "Got it" on slide 2 (calls completion handler then `Navigator.pop`).
- **Slide config (FR-3):** Private `const _slides = <_OnboardingSlide>[...]` list at the top of the file. Each `_OnboardingSlide` is a tiny data class with `imageAsset` (String) and `textKey` (String, l10n key). Reordering or extending requires only editing this list.
- **Static API:** `static Future<void> show(BuildContext context)` — convenience entry point used by `HomeScreen`.

### Storage Layer — `StorageService` extension
- **Modify:** `lib/services/storage_service.dart`
- Add: `static const String keyOnboardingComplete = 'onboarding_complete';` alongside existing keys.
- No new methods needed — generic `getBool`/`setBool` already cover the use case.
- Pre-flight: `grep -r "onboarding_complete" lib/` to confirm no collision (PRD assumption).

### Integration — `HomeScreen.initState()`
- **Modify:** `lib/screens/home/home_screen.dart` (~line 31, existing `initState`)
- Add post-frame callback after `_tabController` setup:
  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (StorageService().getBool(StorageService.keyOnboardingComplete) != true) {
      OnboardingDialog.show(context);
    }
  });
  ```
- Inside `OnboardingDialog._handleGotIt`: `await StorageService().setBool(keyOnboardingComplete, true);` then `Navigator.of(context).pop()`.

### Localization — `LocaleProvider` keys
- **Modify:** `lib/configs/l10n_config.dart` (or wherever the locale string maps live)
- Add 6 keys (3 EN + 3 VN if app supports both): `onboarding_slide_1_text`, `onboarding_slide_2_text`, `onboarding_slide_3_text`, plus `onboarding_next` ("Next") and `onboarding_got_it` ("Got it"). Pattern matches existing `drawer_chat`, `no_records`, etc.

### Assets
- **New directory:** `assets/onboarding/`
- **New files:** `slide_1.png`, `slide_2.png`, `slide_3.png` — committed as solid-colour 360×640 PNG placeholders (see Risk #1 mitigation). Designer swaps before release.
- **Modify:** `pubspec.yaml` → add `- assets/onboarding/` under `flutter.assets`.

### Tests
- **Smoke (widget):** `tests/e2e/epic_onboarding/onboarding_dialog_smoke_test.dart`
  - Mounts `OnboardingDialog` directly with `SharedPreferences.setMockInitialValues({})`.
  - Asserts: 3 slides exist, "Next" advances, "Got it" appears only on slide 3, swipe gesture does not advance, back button does not dismiss, completion writes the flag.
- **Integration:** `tests/integration/epic_onboarding/first_launch_gate_test.dart`
  - Mounts `HomeScreen` with mock prefs (a) empty → dialog shown, (b) `onboarding_complete = true` → dialog NOT shown.
- Follows existing pattern from `tests/e2e/epic_category-filter/` and `tests/integration/epic_category-filter/`.

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: First-launch gate | §Integration / `HomeScreen.initState` post-frame check | T3 | Integration test (first_launch_gate_test) |
| FR-2: Sequential 3-slide navigation | §Widget Layer / `PageController` + `NeverScrollableScrollPhysics` + `PopScope` | T2 | Smoke test (3 scenarios: advance, blocked dismissal, swipe blocked) |
| FR-3: Configurable slide content | §Widget Layer / `const _slides` list + l10n keys | T2 | Smoke test (slide content displayed) + manual asset swap drill |
| FR-4: Completion flag | §Widget Layer / `_handleGotIt` → `StorageService.setBool` | T2, T3 | Smoke test (flag written) + Integration test (returning launch) |
| NFR-1: No external dependencies | §Assets bundled, no new packages | T1, T2 | `pubspec.yaml` review — no new deps added |
| NFR-2: Back-button lock | §Widget Layer / `PopScope(canPop: false)` | T2 | Smoke test (back button does not dismiss) |

All 4 MUST + 2 NFR mapped. Zero NICE-TO-HAVE items in the PRD.

## Implementation Strategy

This is a SMALL epic — single phase, sequential dependency chain.

**Phase 1 (sole phase):** T1 → T2 → T3
- T1 lands first because T2 depends on the storage key constant and the asset paths.
- T2 builds the dialog widget in isolation (testable on its own).
- T3 wires T2 into `HomeScreen` and adds the integration test.

**Exit criterion:** First-launch test passes on a clean install (mock prefs empty); second-launch test passes (mock prefs has `onboarding_complete=true`); all 3 smoke scenarios pass.

## Task Breakdown

##### T1: Foundation — storage key, l10n strings, and slide assets
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Add `keyOnboardingComplete = 'onboarding_complete'` constant to `StorageService` (alongside `keyCurrency`, `keyUserPattern`). Add 5 l10n string keys (`onboarding_slide_{1,2,3}_text`, `onboarding_next`, `onboarding_got_it`) in `lib/configs/l10n_config.dart` for both supported languages. Create `assets/onboarding/` directory with three solid-colour 360×640 PNG placeholders (`slide_1.png`, `slide_2.png`, `slide_3.png`). Declare the directory under `flutter.assets` in `pubspec.yaml`. Run `fvm flutter pub get` to verify.
- **Key files:** `lib/services/storage_service.dart`, `lib/configs/l10n_config.dart`, `pubspec.yaml`, `assets/onboarding/slide_1.png`, `assets/onboarding/slide_2.png`, `assets/onboarding/slide_3.png`
- **PRD requirements:** FR-3, FR-4, NFR-1
- **Key risk:** Asset filename mismatch between PRD/widget code and committed PNGs — verify all three names exact.
- **Interface produces:** `StorageService.keyOnboardingComplete` constant; 5 l10n keys; 3 asset paths under `assets/onboarding/`.

##### T2: Build `OnboardingDialog` widget
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Create `lib/components/popups/onboarding_dialog.dart` (mirroring the existing `category_records_bottom_sheet.dart` style). Stateful widget owning a `PageController` and `int _currentPage`. Body: `PopScope(canPop: false, child: Dialog(...))` containing a `PageView` with `physics: NeverScrollableScrollPhysics()`, three pages each rendering `Image.asset` above a localized `Text`, and a bottom `ElevatedButton` whose label/callback flips at `_currentPage == 2` (Next → Got it). On "Got it", call `StorageService().setBool(StorageService.keyOnboardingComplete, true)` then `Navigator.of(context).pop()`. Define a private `const _slides` list of `_OnboardingSlide` records (image asset path + l10n key) at the top of the file. Add static `show(BuildContext context)` helper that wraps `showDialog(barrierDismissible: false, useSafeArea: true, ...)`. Export from `lib/components/components.dart`.
- **Key files:** `lib/components/popups/onboarding_dialog.dart`, `lib/components/components.dart`, `tests/e2e/epic_onboarding/onboarding_dialog_smoke_test.dart`
- **PRD requirements:** FR-2, FR-3, FR-4, NFR-2
- **Key risk:** `PopScope` API differs slightly across Flutter versions — confirm against pinned `.fvmrc` Flutter version (3.35.7); fall back to `WillPopScope` if needed.
- **Interface receives from T1:** `StorageService.keyOnboardingComplete`, `assets/onboarding/slide_*.png`, l10n keys.
- **Interface produces:** `OnboardingDialog.show(BuildContext)` static method.

##### T3: Wire into `HomeScreen` + integration test
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** T2 | **Complexity:** simple
- **What:** In `lib/screens/home/home_screen.dart` `initState()`, add `WidgetsBinding.instance.addPostFrameCallback` that reads `StorageService().getBool(StorageService.keyOnboardingComplete)`; if not `true`, calls `OnboardingDialog.show(context)`. Guard with `if (!mounted) return;`. Write `tests/integration/epic_onboarding/first_launch_gate_test.dart` covering both branches (empty prefs → dialog shown, prefs `onboarding_complete=true` → no dialog). Verify no regression by running full test suite (`fvm flutter test`).
- **Key files:** `lib/screens/home/home_screen.dart`, `tests/integration/epic_onboarding/first_launch_gate_test.dart`
- **PRD requirements:** FR-1, FR-4
- **Key risk:** Other `initState` work (TabController, HomeWidget listener) may conflict with timing — keep the post-frame callback at the END of `initState` to ensure all earlier setup completes first.
- **Interface receives from T2:** `OnboardingDialog.show(BuildContext)`.

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Placeholder PNGs missing at build time → blank/broken slides | Med | Med | Visual regression on first launch | Ship solid-colour 360×640 placeholders in T1; verify via `fvm flutter run` before merging T2 |
| `PopScope` vs `WillPopScope` API drift across Flutter versions | Low | Med | Compile error or back-button leak | Confirm Flutter version pinned via `.fvmrc`; use the API that ships with that version. Fall-back path documented in T2 risk. |
| Dialog opens before `MaterialApp`/`Navigator` ready → `Navigator operation requested with a context that does not include a Navigator.` | Low | Low | Crash on first launch | Trigger via `addPostFrameCallback` inside `HomeScreen.initState` (not in `main()` or `MyApp.build`) — guarantees Navigator is mounted. |
| `onboarding_complete` key collision with future feature | Low | Low | Onboarding may be skipped or re-triggered unexpectedly | `grep -r "onboarding_complete" lib/` before T1; if collision found, namespace as `onboarding_v1_complete`. |
| `SharedPreferences.setMockInitialValues` not invoked in tests → null-channel error | Low | Med | Test failures, not production | Document in test file header; add to test setup. Pattern already used elsewhere in the codebase. |

## Dependencies

- **Designer (external):** Final 3 onboarding screenshot PNGs — pending — placeholders ship with T1, swap is a follow-up PR before release.
- **Internal:** `StorageService.init()` already runs in `main()` before `runApp` — no new init order required.

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Dialog shown on first launch | First-launch gate test | 100% pass | `fvm flutter test tests/integration/epic_onboarding/first_launch_gate_test.dart` |
| Dialog not shown on second launch | Returning-launch gate test | 100% pass | Same test file, second case |
| User must reach slide 3 to dismiss | Smoke test — blocked dismissal + swipe scenarios | 100% pass | `fvm flutter test tests/e2e/epic_onboarding/onboarding_dialog_smoke_test.dart` |
| Image swap requires no code change | Manual drill: replace `assets/onboarding/slide_1.png` with a new file of the same name, run app | New image renders without rebuild of widget code | Manual QA on local device |

## Estimated Effort

- **Total:** 2 days (single dev, sequential)
- **Critical path:** T1 (0.5d) → T2 (1d) → T3 (0.5d)
- **Parallel opportunities:** None — task chain is strictly sequential because each step depends on the prior one's interface.

## Deferred / Follow-up

The PRD has zero NICE-TO-HAVE items, so nothing is deferred from the in-scope work. Two recommendations from the validation report (slide indicator dots, distinct "Got it" button styling on slide 3) are explicitly Out of Scope per the PRD and remain so. If the designer's final mockups reintroduce them, file a follow-up PRD.

## Tasks Created

| #   | Task                                            | Phase | Parallel | Est.  | Depends On    | Status |
| --- | ----------------------------------------------- | ----- | -------- | ----- | ------------- | ------ |
| 001 | Foundation — storage key, l10n strings, assets  | 1     | no       | 0.5d  | —             | open   |
| 002 | Build OnboardingDialog widget                   | 1     | no       | 1d    | 001           | open   |
| 003 | Wire into HomeScreen + integration test         | 1     | no       | 0.5d  | 001, 002      | open   |
| 090 | Integration verification & cleanup              | 1     | no       | 0.5d  | 001, 002, 003 | open   |

### Summary
- **Total tasks:** 4
- **Parallel tasks:** 0
- **Sequential tasks:** 4
- **Estimated total effort:** ~2.5d
- **Critical path:** 001 → 002 → 003 → 090 (~2.5d)

### Dependency Graph
```
001 ──→ 002 ──→ 003 ──→ 090
 └──────────────────────↗
```
Critical path: 001 → 002 → 003 → 090 (~2.5d)

### PRD Coverage
| PRD Requirement    | Covered By    | Status     |
| ------------------ | ------------- | ---------- |
| FR-1: First-launch gate        | 003, 090 | ✅ Covered |
| FR-2: Sequential navigation    | 002, 090 | ✅ Covered |
| FR-3: Configurable slide content | 001, 002, 090 | ✅ Covered |
| FR-4: Completion flag          | 001, 002, 003, 090 | ✅ Covered |
| NFR-1: No external dependencies | 001, 090 | ✅ Covered |
| NFR-2: Back-button lock        | 002, 090 | ✅ Covered |
