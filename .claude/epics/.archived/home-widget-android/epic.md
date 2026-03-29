---
name: home-widget-android
status: completed
created: 2026-03-29T05:05:11Z
updated: 2026-03-29T08:43:41Z
completed: 2026-03-29T08:43:41Z
progress: 100%
priority: P1
prd: .claude/prds/home-widget-android.md
task_count: 3
github: "https://github.com/dainn67/wallet-ai/issues/146"
---

# Epic: home-widget-android

## Overview
This epic fixes the Android widget data pipeline and redesigns Glance layouts to cover 1×1 through 4×4 placements. The work is split across two files: `record_provider.dart` (Dart — data fix) and `AppWidget.kt` (Kotlin — layout redesign). The data fix must land first because the Kotlin side needs a new `current_month` preference key. The existing Glance `SizeMode.Responsive` pattern is preserved — we add more breakpoints rather than changing the approach. The `home_widget` package bridge and `MyWidgetReceiver` are untouched.

## Architecture Decisions

### AD-1: Use `_selectedDateRange` for month context (not `DateTime.now()`)
**Context:** `_updateWidget()` needs to decide which month's data to send. Two options: always use today's month, or use whatever month the user has navigated to in the app.
**Decision:** Use `_selectedDateRange.start` (the currently selected month in RecordProvider). This means `filteredTotalIncome`/`filteredTotalExpense` are already correctly scoped — no extra filtering needed.
**Alternatives rejected:** Hard-coding `DateTime.now()` — would desync the widget from the app's displayed month after user navigates.
**Trade-off:** If the user navigates to February and closes the app, the widget shows February data until the next `_updateWidget()` call. Acceptable — matches the app state.
**Reversibility:** Easy — swap to `DateTime.now()` in one line if user feedback says "always show current month."

### AD-2: Expand Glance Responsive breakpoints (keep existing pattern)
**Context:** Current `SizeMode.Responsive` defines 3 sizes (SMALL, WIDE, LARGE). Need to cover tall-narrow (1×2+) and medium (2×2) separately from large (3×2+).
**Decision:** Expand to 5 breakpoints: SMALL (80×80), TALL (80×160), WIDE (160×80), MEDIUM (160×160), LARGE (200×200). The `when` block routes based on `LocalSize.current` width/height thresholds. Reuse existing `QuickRecordBar`, `StatItem`, and color constants.
**Alternatives rejected:** Separate widget classes per size — overkill for a single Glance widget with shared data.
**Trade-off:** More complex routing logic in one file, but avoids code duplication.
**Reversibility:** Easy — breakpoints are just `DpSize` constants.

### AD-3: Simplify `_updateWidget()` by reusing existing getters
**Context:** `_updateWidget()` currently has 15 lines of manual iteration over `_moneySources` and `_records`. RecordProvider already has `totalBalance`, `filteredTotalIncome`, `filteredTotalExpense` getters.
**Decision:** Replace the manual loops with the existing getters. Add `current_month` as a new `HomeWidget.saveWidgetData` key formatted via `DateFormat('MMMM yyyy')` from the `intl` package (already a dependency).
**Alternatives rejected:** Keep manual loops for "widget isolation" — unnecessary given getters are synchronous and deterministic.
**Trade-off:** `_updateWidget()` becomes coupled to the getter implementations. Acceptable — they live in the same class.
**Reversibility:** Easy — inline the loops back if needed.

## Technical Approach

### Dart Layer — RecordProvider data fix
**File:** `lib/providers/record_provider.dart`
- Replace `_updateWidget()` body (lines 201–221) with calls to existing getters: `totalBalance`, `filteredTotalIncome`, `filteredTotalExpense`
- Add new key: `HomeWidget.saveWidgetData<String>('current_month', DateFormat('MMMM yyyy').format(_selectedDateRange?.start ?? DateTime.now()))`
- Import `package:intl/intl.dart` (already a project dependency via `intl: ^0.19.0`)
- Keep `currency` key as-is (reads from StorageService)
- The method shrinks from ~20 lines to ~6 lines

### Kotlin Layer — AppWidget.kt layout redesign
**File:** `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt`

**New breakpoints:**
```
SMALL  = DpSize(80.dp, 80.dp)    // 1×1
TALL   = DpSize(80.dp, 160.dp)   // 1×2, 1×3, 1×4
WIDE   = DpSize(160.dp, 80.dp)   // 2×1
MEDIUM = DpSize(160.dp, 160.dp)  // 2×2
LARGE  = DpSize(240.dp, 200.dp)  // 3×2+, 4×2+, 3×3+
```

**Layout mapping:**
| Size class | Routing condition | Content |
| --- | --- | --- |
| Small (1×1) | width < 130 && height < 130 | Compact QuickRecord: rounded pill, pencil icon + "Quick Record..." text, vertical stack to fit square |
| Tall (1×2+) | width < 130 && height ≥ 130 | Balance amount + currency at top, QuickRecordBar at bottom |
| Wide (2×1) | width ≥ 130 && height < 130 | Balance on left, QuickRecordBar on right (existing pattern, add balance) |
| Medium (2×2) | width ≥ 130 && height ≥ 130 && height < 200 | Month label header + balance + income/expense row + QuickRecordBar |
| Large (3×2+) | height ≥ 200 | Full dashboard: WALLY AI tag + month label + balance + income/expense + QuickRecordBar (current LargeDashboard with month added) |

**SmallLayout redesign:** Replace the 56dp purple box + `ic_input_add` with a rounded-pill Column containing the pencil icon and "Quick Record..." text stacked vertically. The text should be ≥12sp. Background uses `surfaceColor` (matching QuickRecordBar), not `accentColor`.

**Month label:** Read `prefs.getString("current_month", "")` and display as a header text (`11sp`, gray, bold) in Medium and Large layouts. Position: below the WALLY AI tag row (Large) or as the first row (Medium).

### XML metadata
**File:** `android/app/src/main/res/xml/my_widget_info.xml`
- No changes needed. Already allows `minWidth/minHeight=40dp`, `resizeMode=horizontal|vertical`, `maxResizeWidth=400dp`, `maxResizeHeight=800dp`. Covers all intended sizes.

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --- | --- | --- | --- |
| FR-1: Redesign 1×1 layout | §Kotlin Layer / SmallLayout redesign | T2 | Manual: place 1×1 on emulator, verify pencil icon + hint text |
| FR-2: Add intermediate size layouts | §Kotlin Layer / New breakpoints + Tall/Wide layouts | T2 | Manual: place 1×2, 2×1 widgets on emulator |
| FR-3: Fix data pipeline — current-month totals | §Dart Layer / RecordProvider data fix | T1 | Unit test: mock records across months, verify filtered values sent |
| FR-4: Current month label on 2×2+ | §Kotlin Layer / Month label | T2 | Manual: place 2×2 widget, verify "March 2026" label |
| NFR-1: Widget update latency | §Dart Layer / synchronous getter calls | T1 | Observe via debug logs |
| NFR-2: Minimum text legibility | §Kotlin Layer / font size constraints | T2 | Visual inspection at each breakpoint |
| NTH-1: 4×2/4×4 extra-large layout | Deferred | — | — |
| NTH-2: Localized month label | Deferred | — | — |

## Implementation Strategy

### Phase 1: Data Foundation
**What:** Fix `_updateWidget()` in RecordProvider to pass filtered monthly totals and `current_month` string.
**Why:** Kotlin layouts need the `current_month` key to display the month label. Data correctness must be confirmed before visual work.
**Exit criterion:** `_updateWidget()` calls `filteredTotalIncome`, `filteredTotalExpense`, `totalBalance` getters and saves `current_month` key. Existing tests pass.

### Phase 2: Layout Redesign
**What:** Rewrite `AppWidget.kt` with 5 breakpoints and 5 layout composables. Redesign SmallLayout, add TallLayout, update WideLayout, create MediumLayout, update LargeDashboard with month label.
**Why:** All 4 visual FRs land here. Depends on Phase 1 for `current_month` key.
**Exit criterion:** Widget renders correctly at 1×1, 1×2, 2×1, 2×2, and 3×2+ sizes on emulator. No clipping or overflow.

### Phase 3: Verification
**What:** Run existing Flutter tests, manually verify all widget sizes, confirm data correctness.
**Why:** Widget rendering is not unit-testable (Glance). Manual verification is the primary check.
**Exit criterion:** All existing tests pass. All 5 widget sizes render correctly. Income/expense match app's RecordsTab values.

## Task Breakdown

##### T1: Fix widget data pipeline in RecordProvider
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Replace the manual loop in `_updateWidget()` (lines 201–221) with calls to `totalBalance`, `filteredTotalIncome`, `filteredTotalExpense` getters. Add `DateFormat('MMMM yyyy').format(_selectedDateRange?.start ?? DateTime.now())` as `current_month` key. Add `import 'package:intl/intl.dart'` to the imports. The method body shrinks from ~20 lines to ~6 lines of `HomeWidget.saveWidgetData` calls.
- **Key files:** `lib/providers/record_provider.dart`
- **PRD requirements:** FR-3, NFR-1
- **Key risk:** `filteredTotalIncome`/`filteredTotalExpense` depend on `filteredRecords` which depends on `_selectedDateRange` — must ensure `_selectedDateRange` is initialized before `_updateWidget()` is called (it is: set in constructor at line 31).
- **Interface produces:** New `current_month` key in HomeWidget preferences consumed by T2's Kotlin layouts.

##### T2: Redesign AppWidget.kt with 5 responsive layouts
- **Phase:** 2 | **Parallel:** no | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Rewrite `AppWidget.kt`: (1) Replace 3 breakpoints with 5 (SMALL/TALL/WIDE/MEDIUM/LARGE). (2) Redesign `SmallLayout` — swap purple box + add icon for a compact rounded-pill QuickRecord with pencil icon and "Quick Record..." text stacked vertically. (3) Add `TallLayout` — balance + currency at top, QuickRecordBar at bottom. (4) Update `WideLayout` — add balance text on the left. (5) Add `MediumLayout` — month label + balance + income/expense + QuickRecordBar. (6) Update `LargeDashboard` — add month label from `current_month` pref below the WALLY AI tag. Reuse existing `QuickRecordBar` and `StatItem` composables. Keep existing color constants.
- **Key files:** `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt`
- **PRD requirements:** FR-1, FR-2, FR-4, NFR-2
- **Key risk:** Glance breakpoint selection can be unpredictable at boundary sizes — need empirical testing on emulator to tune dp thresholds.
- **Interface receives from T1:** `current_month` string key in HomeWidget preferences.

##### T3: Verify all widget sizes and run tests
- **Phase:** 3 | **Parallel:** no | **Est:** 0.5d | **Depends:** T2 | **Complexity:** simple
- **What:** Run `flutter test` to confirm no regressions in existing Dart tests. Run `flutter analyze` to confirm zero errors. Build and deploy to Android emulator. Place widgets at all 5 size classes (1×1, 1×2, 2×1, 2×2, 3×2). Verify: (1) 1×1 shows pencil icon + hint text, not add icon. (2) Tall layout shows balance + QuickRecord. (3) 2×2+ shows month label. (4) Income/expense values match app's RecordsTab for the current month. (5) Currency formatting is correct (VND dots, USD commas).
- **Key files:** All files from T1 and T2
- **PRD requirements:** FR-1, FR-2, FR-3, FR-4, NFR-1, NFR-2
- **Key risk:** Cannot automate Glance rendering tests — verification is manual, may miss edge cases on non-Pixel devices.

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| Glance breakpoint mismatch at boundary sizes | Med | Med | Wrong layout renders for a given widget placement | Test on emulator at each cell size; adjust dp thresholds empirically; add 10dp buffer between breakpoints |
| `filteredTotalIncome` reflects navigated month, not current calendar month | High | Med | Widget shows stale month data if user navigated away and closed app | Document behavior in UI (month label shows which month is displayed); consider resetting to current month on app launch in future |
| System icons (`ic_menu_edit`) may not render on all Android versions | Med | Low | Blank icon on older devices | Test on API 21 emulator; if fails, bundle a custom pencil drawable |
| `DateFormat('MMMM yyyy')` always produces English month names | Low | High | Vietnamese users see English month on widget | Accept for now — tracked as NTH-2; `intl` can be configured with locale in follow-up |

## Dependencies

- `filteredTotalIncome` / `filteredTotalExpense` / `totalBalance` getters — delivered in `refactor-code` epic. ✅ Merged.
- `home_widget: ^0.9.0` — in `pubspec.yaml`. ✅ Available.
- `intl: ^0.19.0` — in `pubspec.yaml`. ✅ Available.
- Glance `androidx.glance:glance-appwidget` — in Android build.gradle. ✅ Available.

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
| --- | --- | --- | --- |
| 1×1 usability | Pencil icon + hint text visible | No clipping at 74×74dp | Visual inspection on Pixel 7 emulator |
| Data correctness | `total_income` / `total_spend` match filtered getters | Values identical to RecordsTab | Add test record; compare widget prefs vs app UI |
| Month label | `current_month` key written and displayed | "March 2026" visible on 2×2 | Check `HomeWidget.saveWidgetData` log + visual |
| No regression | All existing Flutter tests pass | 132/132 pass | `flutter test` |

## Estimated Effort
- **Total:** ~2 days
- **Critical path:** T1 (0.5d) → T2 (1d) → T3 (0.5d) = 2 days sequential
- No parallelizable tasks (T2 depends on T1's `current_month` key, T3 depends on T2)

## Deferred / Follow-up
- **NTH-1:** 4×2 / 4×4 extra-large layout — the LARGE breakpoint already covers these sizes; dedicated layout only if user requests it
- **NTH-2:** Localized month label ("Tháng 3 2026") — requires passing locale through widget data; ship English-only first
