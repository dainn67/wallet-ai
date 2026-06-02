# Smoke Test Checklist — Epic: home-widgets

These tests **cannot be automated** in this codebase: Glance widgets run in a separate OS-level rendering context, the Flutter test harness has no access to it, and the cold-start path involves the platform `MainActivity` boot which Dart tests cannot exercise. T006 (#224) is open for exactly this reason.

Run this checklist on a real Android emulator (or device) before merging the epic. Mark each box. If anything fails, file the bug, fix it, then re-run the failing line.

## Pre-flight (automatable)

- [ ] `fvm flutter analyze` — 0 new warnings in any file under `lib/screens/home/`, `lib/providers/`
- [ ] `cd android && ./gradlew :app:assembleDebug` — BUILD SUCCESSFUL
- [ ] `fvm flutter test tests/integration/epic_home-widgets/` — all pass
- [ ] `fvm flutter test tests/e2e/epic_home-widgets/` — all pass

## FR-1 — bar visible at every breakpoint

Place the widget at each size and confirm the entry bar is rendered:

- [ ] **1×1 SMALL** — icon-only edit button visible (no "Add a record" label)
- [ ] **1×2 TALL** — icon-only edit button visible above the balance text
- [ ] **2×1 WIDE** — full bar with "Add a record" label + edit icon
- [ ] **2×2 MEDIUM** — full bar with label, plus ActionIconRow above
- [ ] **3×2+ LARGE** — full dashboard, ActionIconRow, bar at bottom

## FR-2 / FR-3 — write + camera icons on medium and large

- [ ] **2×2 MEDIUM** — write (pencil) icon on left, camera on right of ActionIconRow
- [ ] **3×2+ LARGE** — same as above

## FR-4 — deep-link routing (cold start + warm resume)

Use `adb shell am start -a android.intent.action.VIEW -d <URI>` or place widget and tap.

**Cold start** (`adb shell am force-stop com.leslie.wallyai` first):
- [ ] Tap bar on 2×2 → app launches → ChatTab → text input focused (≤1.5s)
- [ ] Tap write icon on 2×2 → same as above
- [ ] Tap camera icon on 2×2 → app launches → ChatTab → camera picker visible (≤1.5s)

**Warm resume** (home button first, app still in background):
- [ ] Tap bar → ChatTab + input focused (≤800ms target for NFR-1)
- [ ] Tap write icon → same as above
- [ ] Tap camera icon → camera picker visible (≤800ms target for NFR-1)

**Fallback (FR-5):**
- [ ] Tap balance text area on 3×2+ — app opens (no crash, no dead tap)
- [ ] Tap stats row on 2×2 — app opens

**Logcat verification:**
- [ ] `adb logcat | grep -i homeWidget` shows the correct URI per tap:
  - Bar/write → `homeWidget://record`
  - Camera → `homeWidget://camera`
  - Non-icon area → `homeWidget://open`

## FR-5 — root clickable doesn't capture icon taps (Glance priority risk)

This is the **highest-risk** verification in the epic — the entire ActionIconRow design depends on Glance resolving inner clickables before the root fallback.

- [ ] On 2×2, tap the write icon exactly (not the surrounding background) — only `homeWidget://record` fires, NOT `homeWidget://open`.
- [ ] On 2×2, tap the camera icon exactly — only `homeWidget://camera` fires.
- [ ] If either tap also fires `homeWidget://open` (double-fire), **STOP** and restructure modifier ordering in `AppWidget.kt`.

## NFR-1 — latency budget ≤800ms

Use `adb shell screenrecord` to capture; frame-count at 30fps (33ms/frame).

- [ ] Cold-start camera tap: ≤1.5s (cold-start budget includes engine init)
- [ ] Warm-resume camera tap: ≤800ms
- [ ] Warm-resume text-input tap: ≤800ms

Record p50 and p95 across 5 trials per path.

## NFR-2 — render correctness API 26 / 30 / 34

- [ ] Emulator API 26 — all 5 breakpoints render with no overflow, no clipping, no missing icons
- [ ] Emulator API 30 — same
- [ ] Emulator API 34 — same

## NFR-3 — state freshness regression

- [ ] Place 2×2 widget; note balance / income / spent values.
- [ ] Open app, create a new expense via chat.
- [ ] Press home, view widget within 30s — balance / spent updated.
- [ ] Edit the record — widget reflects new value within 30s.
- [ ] Delete the record — widget reverts within 30s.

## Onboarding-incomplete behavior (Gap #3 in Phase A report)

- [ ] `adb shell pm clear com.leslie.wallyai` — clears all app data
- [ ] Tap widget icon — onboarding dialog appears
- [ ] Complete onboarding — widget intent is dropped (silent drop is current design per T005)
- [ ] Tap widget icon again after dismissing onboarding — works correctly

(Note: silent drop is a known UX gap; intent-queueing follow-up may improve this later.)

## Documentation findings

After running the checklist, paste the results table into `docs/features/home-widget.md` under a new "QA Results" section. If any NFR fails, file a follow-up issue and link from the QA section.
