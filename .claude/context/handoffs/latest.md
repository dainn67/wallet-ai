# Handoff Notes: Task #002 - Redesign AppWidget.kt with 5 responsive layouts

## Status
COMPLETE — `flutter build apk --debug` passes.

## What Was Done
Rewrote `AppWidget.kt` to define 5 Glance `DpSize` breakpoints (SMALL/TALL/WIDE/MEDIUM/LARGE) instead of the previous 3. Redesigned SmallLayout from purple box + add icon to a compact QuickRecord-style pill with pencil icon and hint text. Added TallLayout (balance + QuickRecordBar stacked). Updated WideLayout to show balance on left, QuickRecordBar on right. Added MediumLayout with month label, balance, income/expense stats, and QuickRecordBar. Updated LargeDashboard with `current_month` label below the WALLY AI tag.

## Files Changed
- `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt`
  - Companion object: 3 breakpoints → 5 (SMALL 80x80, TALL 80x160, WIDE 160x80, MEDIUM 160x160, LARGE 240x200)
  - Routing: updated `when` block with width/height thresholds (130dp, 200dp)
  - SmallLayout: surfaceColor bg, pencil icon tinted accentColor, "Quick Record..." text at 12sp
  - TallLayout: new composable — balance top, QuickRecordBar bottom
  - WideLayout: now takes `prefs`, shows balance left + QuickRecordBar right (Row layout)
  - MediumLayout: new composable — month label + balance + income/expense + QuickRecordBar
  - LargeDashboard: reads `current_month` pref, displays below WALLY AI tag

## Decisions Made
- Breakpoint thresholds: 130dp for small/tall/wide split, 200dp for medium/large split (matches task spec)
- SmallLayout does not receive `prefs` — only needs context and colors (no balance data at 1×1)
- Reused existing `QuickRecordBar` and `StatItem` composables unchanged

## Verification Results
- `flutter build apk --debug` — SUCCESS

## Warnings for Next Task (T3)
- Manual testing needed: place widgets at each size on emulator to verify visual rendering
- `current_month` key comes from T1's `_updateWidget()` — ensure widget has been updated at least once for month label to appear
- Balance font sizes: 18sp (Tall), 16sp (Wide), 24sp (Medium), 28sp (Large) — check readability on real devices
