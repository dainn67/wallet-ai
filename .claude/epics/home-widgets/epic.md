---
name: home-widgets
status: backlog
created: 2026-06-01T09:39:23Z
progress: 0%
priority: P1
prd: .claude/prds/home-widgets.md
task_count: 6
github: https://github.com/dainn67/wallet-ai/issues/218
---

# Epic: home-widgets

## Overview

Redesign the existing `AppWidget.kt` Glance composables to give every breakpoint a clear "Add a record" affordance, and add a paired write/camera icon row to medium and large layouts. The interaction model stays plain-UI (tap → deep-link → app) so we keep the existing `home_widget` package, `actionStartActivity` pattern, and `HomeScreen._handleWidgetClick` switch. The non-obvious work is on the Flutter side: we must extend the deep-link router to handle a new `homeWidget://camera` URI that triggers the existing `ChatTab` image picker, and make sure the cold-start path (app not running when widget tapped) does not drop the intent extras during Flutter engine init.

The trade-off is symmetry over depth — we don't add new data, new layouts, or new platforms in this epic. The widget gets richer affordances; everything else is left untouched.

## Architecture Decisions

### AD-1: Keep plain-UI Glance composables (no overlay Activity)
**Context:** Glance does not support real text input. The PRD considered an overlay Activity for in-place entry but explicitly chose the simpler deep-link model.
**Decision:** All widget interactions deep-link to the app via `actionStartActivity` with a `Uri`. No overlay Activity, no `RemoteInput`, no widget-side state.
**Alternatives rejected:** (a) Overlay Activity slide-up — adds a second `Activity`, manifest entries, lifecycle headaches, and a separate Flutter engine if we want to reuse providers. (b) `RemoteInput` action — works but only for typed entry (not camera) and creates a fragmented "two ways to type" UX.
**Trade-off:** Lose the "stays on home screen" feel; gain implementation simplicity (~1 day vs. ~4 days) and reuse of every existing focus/permission/camera flow.
**Reversibility:** Easy — the deep-link router can later branch to an overlay Activity without touching the widget Composables.

### AD-2: Two distinct URIs (`homeWidget://record` + `homeWidget://camera`)
**Context:** The widget needs two semantically different actions (focus text input vs. open camera) but each must land in the same `ChatTab`.
**Decision:** Use two URIs and branch in `HomeScreen._handleWidgetClick`. Add a new `homeWidget://camera` URI handler that calls the same picker entry point used by the in-app camera button.
**Alternatives rejected:** (a) One URI + query param (e.g. `homeWidget://action?type=camera`) — works but harder to grep, and Glance's `actionStartActivity` Uri API is per-clickable. (b) `Intent` extras — same idea but extras can be lost during Flutter engine cold-start handoff (see Risk).
**Trade-off:** Two strings to maintain, but they are co-located in `AppWidget.kt` and `_handleWidgetClick` — low cost.
**Reversibility:** Easy — collapsing to one URI later is a single edit on each side.

### AD-3: Reuse ChatTab camera picker via a callable method (not a global event bus)
**Context:** `HomeScreen._handleWidgetClick` must trigger the camera picker that today only fires from a button inside `ChatTab`.
**Decision:** Expose a public method on the `ChatTab` state (via a `GlobalKey` already used for the chat input focus, OR via a method on `ChatProvider`) that calls the same `image_picker` flow the camera button uses. Prefer `ChatProvider` since it survives tab rebuilds and is already a singleton-scoped provider.
**Alternatives rejected:** Global event bus / stream — adds infrastructure, harder to trace. Direct call from `HomeScreen` to a private `ChatTab` method — couples the two screens too tightly.
**Trade-off:** ChatProvider grows a UI-triggering method, which is mildly off-pattern (providers usually hold state, not trigger UI). Acceptable because the picker is already triggered by the same provider's onTap path in ChatTab.
**Reversibility:** Easy — wrapping the method behind a `ValueNotifier` or extracting to a dedicated `CameraTriggerService` is a refactor away.

## Technical Approach

### Glance composables (Android-only Kotlin)
**File:** `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt` — full rewrite of the `provideContent` body and helper composables.

- Keep `SizeMode.Responsive` with the existing 5 `DpSize` breakpoints (SMALL, TALL, WIDE, MEDIUM, LARGE).
- Replace the current branch logic (`size.height < 100.dp`, etc.) with a clean lookup that picks a single composable per breakpoint.
- New helper `ActionIconRow(write, camera)` — two `Box`-shaped tappable icons with their own `clickable(actionStartActivity<MainActivity>(context, Uri))`.
- Update `QuickRecordBar` to take an `iconOnly: Boolean` derived from `size.width <= 80.dp` (covers 1×1 SMALL and 1×2 TALL). Drop the now-redundant `isCompact` param.
- Root `Box` keeps its own `clickable` for FR-5 fallback. Order matters: apply per-element clickables before the root one so Glance's hit-test resolves the inner clickables first.

Icons: edit / pencil = `android.R.drawable.ic_menu_edit` (already used); camera = `android.R.drawable.ic_menu_camera`. Both are guaranteed system drawables on API 26+.

### Deep-link routing (Flutter)
**File:** `lib/screens/home/home_screen.dart` — extend `_handleWidgetClick(Uri? uri)`.

Current code routes any `homeWidget://record` to ChatTab + focus. Add a parallel branch for `homeWidget://camera`:

```dart
if (uri?.host == 'record') {
  _switchToChatTab();
  _focusChatInput();
} else if (uri?.host == 'camera') {
  _switchToChatTab();
  context.read<ChatProvider>().pickImageFromCamera();
}
```

Cold-start path: `HomeWidget.initiallyLaunchedFromHomeWidget()` already runs in `HomeScreen.initState`. We must ensure `ChatProvider` is fully constructed before calling `pickImageFromCamera`. The existing onboarding/permission `addPostFrameCallback` proves first-frame timing is safe — same pattern applies here.

### Camera trigger bridge
**File:** `lib/providers/chat_provider.dart` — extract the camera picker call into a public method.

Today, the camera icon in `ChatTab` calls (most likely) a private handler that opens `image_picker` with `ImageSource.camera`. Move that logic into `ChatProvider.pickImageFromCamera()` so both the ChatTab button and `HomeScreen._handleWidgetClick` can call it. Permission handling (request → grant → open → cancel/deny) lives inside this method.

### Layout spec (FR-1 + design recommendation)
| Breakpoint | Size (dp) | Bar | Label | Write icon | Camera icon | Stats |
|---|---|---|---|---|---|---|
| 1×1 SMALL | 80×80 | ✓ | — (icon only) | — | — | — |
| 1×2 TALL | 80×160 | ✓ | — (icon only) | — | — | Balance |
| 2×1 WIDE | 160×80 | ✓ | ✓ | — | — | — |
| 2×2 MEDIUM | 160×160 | ✓ | ✓ | ✓ | ✓ | Balance + stats row |
| 3×2+ LARGE | 240×200 | ✓ | ✓ | ✓ | ✓ | Full dashboard |

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
|---|---|---|---|
| FR-1: "Add a record" bar on all layouts | §Glance composables, §Layout spec | T1, T2 | Manual QA on emulator @ each DpSize |
| FR-2: Write icon quick-action | §Glance composables (ActionIconRow) | T2 | Manual tap test on 2×2 and 3×2+ |
| FR-3: Camera icon quick-action | §Glance composables + §Camera trigger bridge | T2, T4 | Manual: tap camera icon → picker opens |
| FR-4: Deep-link routing | §Deep-link routing (Flutter) | T3, T5 | Cold-start + background-resume tests |
| FR-5: Root fallback tap opens app | §Glance composables (root clickable) | T2 | Manual: tap non-icon area on each layout |
| NFR-1: 800 ms tap-to-ready | §Deep-link routing | T6 | Stopwatch test on physical mid-range device |
| NFR-2: Render correctness API 26–34 | §Glance composables | T6 | Emulator inspection at API 26, 30, 34 |
| NFR-3: State freshness (existing path) | No code change; regression check only | T6 | Add record → verify widget updates in <30s |
| NTH-1: Haptic feedback | Deferred to follow-up | — | — |
| NTH-2: iOS WidgetKit widget | Cross-reference only (separate PRD) | — | — |

## Implementation Strategy

### Phase 1 — Foundation (T1)
Lock the layout spec, confirm icon drawable availability on the project's `minSdk`, and identify the existing camera picker call inside ChatTab. Output: a one-page reference doc inside the task describing what each composable does. Exit: every later task can be written against a stable spec.

### Phase 2 — Core build (T2, T3, T4 in parallel)
T2 rewrites `AppWidget.kt`. T3 extends `_handleWidgetClick` for the new URI. T4 extracts the camera trigger into `ChatProvider`. These touch three disjoint files and can be built in parallel by different developers (or sequentially by one). Exit: each task compiles, builds, runs the existing widget at parity, and is testable in isolation.

### Phase 3 — Wire-up & verification (T5, T6)
T5 connects the deep-link router (T3 output) to the camera trigger (T4 output) and tests the cold-start + warm-resume paths. T6 is the full QA pass: 5 breakpoints × API 26/30/34 + NFR-1 stopwatch + NFR-3 regression. Exit: every PRD success criterion is verified.

## Task Breakdown

##### T1: Layout spec + icon asset audit
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Build the per-breakpoint layout matrix as a small markdown reference, decide between system drawable (`ic_menu_camera`) vs. bundled vector for the camera icon by checking minSdk and OEM-skin compatibility, and locate the existing ChatTab camera picker call site for T4 to refactor. Update `docs/features/home-widget.md` (if exists) with the new layout matrix.
- **Key files:** `docs/features/home-widget.md`, `lib/screens/home/tabs/chat_tab.dart` (read only — locate camera handler), `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt` (read only)
- **PRD requirements:** FR-1 (spec), FR-3 (drawable choice)
- **Key risk:** OEM-skinned launchers may strip `android.R.drawable.ic_menu_camera` — if found, bundle a vector asset instead. Decided here, not in T2.
- **Interface produces:** Layout matrix (markdown), camera icon decision (system drawable name or bundled vector path), file/line reference to the ChatTab camera picker call.

##### T2: Rewrite AppWidget.kt composables
- **Phase:** 2 | **Parallel:** yes | **Est:** 2d | **Depends:** T1 | **Complexity:** complex
- **What:** Replace `provideContent` body with a clean per-breakpoint dispatch. Update `QuickRecordBar` to derive `iconOnly` from `size.width <= 80.dp`. Add new `ActionIconRow` composable rendering write + camera icons with their own `clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://record" | "homeWidget://camera")))`. Apply root `clickable` last so inner clickables win the hit test (FR-5 fallback without stealing icon taps).
- **Key files:** `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt`
- **PRD requirements:** FR-1, FR-2, FR-3, FR-5
- **Key risk:** Glance `clickable` ordering — if root captures before inner clickables, the icons become dead. Mitigation: visually verify at every breakpoint as part of this task, not deferred to T6.
- **Interface receives from T1:** Layout matrix + camera icon source.
- **Interface produces:** Working widget with both URIs firing correctly when tapped (verified by Logcat on emulator).

##### T3: Deep-link routing for homeWidget://camera
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1 | **Complexity:** simple
- **What:** Extend `HomeScreen._handleWidgetClick(Uri?)` with a branch for `homeWidget://camera`. The branch switches to ChatTab and calls (yet-to-exist) `ChatProvider.pickImageFromCamera()`. Leave a TODO comment if T4 hasn't landed yet — the method signature is enough to compile against once T4 is merged.
- **Key files:** `lib/screens/home/home_screen.dart`
- **PRD requirements:** FR-4
- **Key risk:** Cold-start path drops intent extras during Flutter engine init. Mitigation handled in T5; T3 only adds the routing branch.
- **Interface receives from T4:** `ChatProvider.pickImageFromCamera()` method (signature).
- **Interface produces:** Deep-link router that dispatches `homeWidget://camera` to camera trigger.

##### T4: Extract camera trigger to ChatProvider
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Move the camera picker logic currently embedded in `ChatTab` into a new public method `ChatProvider.pickImageFromCamera()`. The method handles: permission check (reuse existing permission flow), `image_picker` invocation with `ImageSource.camera`, and dispatching the resulting `XFile` to the existing chat-image upload path. The in-app camera button now calls this same method — no behaviour change visible to the user.
- **Key files:** `lib/providers/chat_provider.dart`, `lib/screens/home/tabs/chat_tab.dart`
- **PRD requirements:** FR-3, FR-4
- **Key risk:** The current camera-button handler may be intertwined with ChatTab `BuildContext` (e.g. for showing permission denial dialogs). Mitigation: the method takes an optional `BuildContext?` for dialogs and works headlessly if `null` (just returns silently on denial — widget tap path falls back to system permission prompt only).
- **Interface produces:** `ChatProvider.pickImageFromCamera({BuildContext? context})` — Future<void>.

##### T5: Cold-start camera flow + wire-up
- **Phase:** 3 | **Parallel:** no | **Est:** 0.5d | **Depends:** T3, T4 | **Complexity:** moderate
- **What:** Connect T3's deep-link branch to T4's `pickImageFromCamera`. Critically, verify the cold-start path: when the app is not running and the user taps the camera icon, `HomeWidget.initiallyLaunchedFromHomeWidget()` must surface the `homeWidget://camera` URI, AND `ChatProvider` must be fully constructed before we call its method. Use `addPostFrameCallback` (already used for onboarding and notifications) to guarantee frame-ready state.
- **Key files:** `lib/screens/home/home_screen.dart`
- **PRD requirements:** FR-4
- **Key risk:** Provider construction race — `_handleWidgetClick` fires before `ChatProvider` is ready. Mitigation: `addPostFrameCallback` + a `mounted` check inside the callback. If the race still happens, fall back to a 200 ms `Future.delayed` retry once.
- **Interface receives from T3, T4:** Deep-link branch + provider method.

##### T6: QA sweep (5 breakpoints × 3 APIs + NFR-1 + NFR-3)
- **Phase:** 3 | **Parallel:** no | **Est:** 1d | **Depends:** T2, T5 | **Complexity:** moderate
- **What:** Manual QA on Android emulators at API 26, 30, 34. For each: place widget at each of 5 breakpoints (1×1, 1×2, 2×1, 2×2, 3×2+), verify rendering, tap every interactive element, stopwatch tap-to-ready time (NFR-1 target: ≤ 800 ms on a mid-range emulator profile). Run NFR-3 regression: create/edit/delete a record in-app and verify widget updates within 30 s. Document any visual issues with screenshots in the task results file.
- **Key files:** Manual QA — no code changes unless regressions found.
- **PRD requirements:** NFR-1, NFR-2, NFR-3 + verification of FR-1–5 success criteria.
- **Key risk:** Visual overflow on 2×2 with stats + ActionIconRow (PRD Assumption 3 may fail). Mitigation: if overflow occurs, move stats row to 3×2+ only and surface the change back to PRD as an acknowledged scope adjustment.

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| Cold-start widget tap loses intent extras during Flutter engine init | High | Medium | Camera flow silently breaks on first launch; user sees only ChatTab open | Use `HomeWidget.initiallyLaunchedFromHomeWidget()` (existing API, already proven for onboarding) wrapped in `addPostFrameCallback`; verified explicitly in T5 + T6 |
| Glance `clickable` overlap — root captures icon taps | High | Low | Write/camera icons become dead taps; widget regresses to current behaviour | Apply per-element clickables before the root `Box.clickable`; T2 includes hit-test verification at every breakpoint |
| `ChatProvider.pickImageFromCamera` requires `BuildContext` for permission dialogs but widget path has no context | Medium | Medium | Permission denial → silent failure on widget path | Method accepts optional context; without it, falls through to system permission prompt only — user-facing dialog deferred to next chat interaction |
| OEM-skinned launchers strip `android.R.drawable.ic_menu_camera` | Medium | Low | Camera icon renders as default placeholder on some devices | T1 verifies; if compromised, bundle a vector asset instead — decided before T2 starts |
| 2×2 layout overflows when adding ActionIconRow above stats | Medium | Medium | Visual clipping → fails NFR-2 | T6 catches it; fallback plan: move stats row to 3×2+ only, document in epic addendum |
| Reusing ChatTab camera handler couples a UI provider to a UI action | Low | Medium | Mild architectural smell; harder to test the provider in isolation | Acknowledged trade-off (AD-3); revisit only if a second consumer (e.g. iOS shortcut) needs the same trigger |

## Dependencies

- `home_widget` Flutter package (v0.9.x) — already in pubspec.yaml — status: resolved
- `androidx.glance:glance-appwidget` (1.1.x) — already in build.gradle.kts — status: resolved
- `image_picker` Flutter package — already in pubspec.yaml (used by ChatTab camera button) — status: resolved
- Existing `_handleWidgetClick` in `HomeScreen` — status: resolved (extending, not creating)
- Existing camera picker call site in `ChatTab` — status: resolved (T1 audits, T4 refactors)
- Camera runtime permission flow — status: resolved (reused as-is from ChatTab)

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
|---|---|---|---|
| SC-1: One-tap to log | Tap bar/write icon → ChatTab + input focused | ≤ 800 ms end-to-end | Stopwatch on Pixel 6a equivalent emulator, 5 trials per layout |
| SC-2: One-tap to camera | Tap camera icon → image picker visible | ≤ 800 ms end-to-end | Stopwatch on same emulator, 5 trials per layout |
| SC-3: Zero dead taps | Every tap region triggers app open | 0/50 no-ops | Tap 10 distinct non-icon areas across all 5 layouts |
| SC-4: Layout completeness | Render with no overflow on API 26 / 30 / 34 | All 5 layouts pass | Emulator visual inspection — screenshots attached to T6 results |

## Estimated Effort

- **Total:** 5.5 person-days
- **Critical path:** T1 → T4 → T5 → T6 = 3 days
- **Parallelizable:** T2 (2d) can run alongside T3+T4 (1.5d combined)
- **Single developer realistic estimate:** 5–6 working days end-to-end
- **Phase durations:** Phase 1 (0.5d), Phase 2 (max 2d parallel), Phase 3 (1.5d)

## Deferred / Follow-up

- **NTH-1: Haptic feedback** — Deferred. Requires API 31+ branching in Glance and adds complexity for marginal UX gain. Reconsider after we have user telemetry on widget tap rates.
- **NTH-2: iOS WidgetKit widget** — Cross-reference only; tracked in `home-widget.md` PRD. No work in this epic.
- **Overlay Activity for in-place entry** — Future iteration if telemetry shows users abandoning between widget tap and submit because the app context switch is too jarring.
- **Stats row movement to 3×2+ only** — Conditional follow-up; only if T6 surfaces 2×2 overflow.
