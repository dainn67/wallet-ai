---
epic: home-widgets
task: 005
status: completed
created: 2026-06-01T10:20:34Z
---
# Handoff: T005 — Cold-start camera flow + wire-up

## What shipped
- `_handleWidgetClick` now wraps dispatch in `addPostFrameCallback` with `mounted` check.
- New private helper `_dispatchWidgetUri(Uri)` holds the switch statement.
- Onboarding-incomplete gate: widget intents are silently dropped (debugPrint logged) if onboarding hasn't been completed — user can re-tap after.
- No 200 ms retry added; trust addPostFrameCallback.

## For T006 (QA)
- Cold-start test: force-stop app, tap widget icon → app launches → onboarding (if needed) → camera/input opens after addPostFrameCallback fires. Expected ≤ 1.5 s on emulator.
- Warm-resume test: background app, tap widget → resumes, dispatch fires.
- Onboarding-race test: clear app data, tap widget icon → onboarding dialog shows first, widget intent dropped silently; user must re-tap after dismissing.

## Files changed
- lib/screens/home/home_screen.dart

## Notes
- The original `_handleWidgetClick` inlined the switch; it's now split into `_handleWidgetClick` (schedules via `addPostFrameCallback`) and `_dispatchWidgetUri` (the actual switch logic).
- The onboarding gate checks `StorageService().getBool(StorageService.keyOnboardingComplete) == true`; if false, dispatch is dropped with a `debugPrint`.
- Pre-existing `use_build_context_synchronously` warning at line 347 (currency drawer) is unchanged and unrelated.
