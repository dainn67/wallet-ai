---
name: home-widget-android
description: Redesign Android home widget size layouts and fix income/expense data to show current-month filtered totals.
status: complete
priority: P1
scale: medium
created: 2026-03-29T04:58:09Z
updated: 2026-03-29T08:43:41Z
---

# PRD: home-widget-android

## Executive Summary
The Android home widget already exists with a Glance-based implementation but has two problems: the 1×1 layout shows a bare add icon that gives no affordance, and the income/expense stats display all-time totals instead of current-month totals. This PRD redesigns the size breakpoints to cover 1×1 through 4×4, updates the 1×1 layout to match the existing `QuickRecordBar` style (text field + pencil icon), adds a "March 2026" month label to medium and large layouts, and fixes the data pipeline to pass current-month income/expense from `filteredTotalIncome`/`filteredTotalExpense`. iOS widget work is out of scope — later.

## Problem Statement
Android users who pin the Wally AI widget at 1×1 see only a purple square with a + icon. There is no text or affordance to indicate what tapping does, and it does not match the polished "Quick Record..." bar visible on larger sizes. Users on 2×2 who check the Income and Spent numbers have no way to tell if they are looking at this month's totals or all-time totals — they are all-time, which is misleading given that the app's Records tab shows monthly-filtered data. There is no current-month label anywhere in the widget.

## Target Users

**Daily Tracker — Casually active user**
- Pins a 1×1 widget on their home screen to quickly add a record without opening the app.
- Primary need: one-tap entry that clearly communicates "tap here to add a record."
- Pain level: medium — the icon alone is confusing on first use.

**Budget Watcher — Active monthly planner**
- Pins a 2×2 or larger widget to glance at monthly spending.
- Primary need: see this month's income vs. expense at a glance without opening the app.
- Pain level: high — all-time totals are useless for monthly budgeting.

## User Stories

**US-1: 1×1 Quick Record affordance**
As a Daily Tracker, I want the 1×1 widget to show a text-field-style button with a pencil icon so that I immediately understand I can tap it to add a record.

Acceptance Criteria:
- [ ] 1×1 widget shows the same visual style as `QuickRecordBar` (rounded pill, pencil icon, hint text)
- [ ] Tapping anywhere on the widget launches the record-entry screen
- [ ] The layout fits entirely within a 74×74dp cell without clipping

**US-2: Current-month income and expense**
As a Budget Watcher, I want the widget to show income and expense totals for the current calendar month so that I can track my monthly budget at a glance.

Acceptance Criteria:
- [ ] Income and Spent values on the widget match `filteredTotalIncome` and `filteredTotalExpense` in RecordProvider (current month filter)
- [ ] A "March 2026" style label is visible on 2×2 and larger layouts
- [ ] If I navigate to a different month in the app, the widget updates to reflect that month on the next data write

**US-3: Graceful size scaling**
As any user, I want the widget to display meaningful content at any size I choose — from 1×1 to 4×4 — without clipping or empty space.

Acceptance Criteria:
- [ ] Each size class (1×1, tall-narrow, wide-short, 2×2+, large) renders without overflow or empty columns
- [ ] Layouts are defined using Glance `SizeMode.Responsive` with breakpoints covering the full range
- [ ] On a Pixel 7 at default density, all size variants render correctly

## Requirements

### Functional Requirements (MUST)

**FR-1: Redesign 1×1 (Small) layout**
Replace the current `SmallLayout` (purple box + `ic_input_add` icon) with a square compact version of `QuickRecordBar` — a rounded surface containing the pencil icon (`ic_menu_edit`) and "Quick Record..." hint text. The layout must fit in ~74×74dp without any visible clipping. Tapping launches `homeWidget://record`.

Scenario: User places 1×1 widget
- GIVEN the widget is placed at 1×1 on the home screen
- WHEN the widget renders
- THEN it shows a rounded pill or square card with pencil icon and "Quick Record..." hint text (no bare icon)

Scenario: User taps 1×1 widget
- GIVEN the 1×1 widget is visible
- WHEN the user taps anywhere on it
- THEN the app opens to the record entry screen via `homeWidget://record`

**FR-2: Add intermediate size layouts**
Add two new Glance `DpSize` breakpoints for tall-narrow (single column, 2+ rows) and wide-short (2 columns, 1 row) forms. Tall-narrow layouts show the balance and a QuickRecord bar stacked vertically. Wide-short shows balance inline with a QuickRecord bar horizontally (similar to existing `WideLayout` but with balance text added).

Scenario: User places a 1×3 tall widget
- GIVEN the widget is placed in a single-column, 3-row slot
- WHEN the widget renders (height ≥ 150dp, width < 130dp)
- THEN it shows "Available Balance" + amount at top, and QuickRecordBar at the bottom

Scenario: User places a 2×1 wide widget
- GIVEN the widget is placed in a 2-column, 1-row slot
- WHEN the widget renders (width ≥ 130dp, height < 130dp)
- THEN it shows balance text on the left and QuickRecordBar on the right

**FR-3: Fix data pipeline — current-month income/expense**
In `RecordProvider._updateWidget()`, replace the local all-records loop that computes `totalIncome`/`totalSpend` with `filteredTotalIncome` and `filteredTotalExpense` getters (which already apply the current-month date filter). Pass an additional key `current_month` formatted as "March 2026" (use the `_currentDate` field already in RecordProvider to derive the month/year string). `total_balance` (money source sum) stays unchanged — it correctly reflects available assets across all time.

Scenario: Widget shows income after adding a record this month
- GIVEN the user has 3 records this month (income: 1,000,000; expense: 500,000) and 5 records last month
- WHEN `_updateWidget()` is called
- THEN `total_income` = "1,000,000", `total_spend` = "500,000" (current month only)

Scenario: Currency is correct
- GIVEN the user has set currency to VND in app settings
- WHEN the widget renders
- THEN all amounts are formatted with VND notation (dots as thousands separators)

**FR-4: Current month label on 2×2+ layouts**
In `LargeDashboard` (and any new medium layout), replace or augment the "WALLY AI" tag in the header with a "March 2026" label read from the new `current_month` widget preference key. Both the brand tag and the month label may coexist in the header row.

Scenario: Widget header shows current month
- GIVEN the widget is 2×2 or larger
- WHEN the widget renders in March 2026
- THEN the header shows "March 2026" (or bilingual equivalent) alongside the brand tag

Scenario: Widget updates when month changes
- GIVEN the widget showed "February 2026"
- WHEN the user opens the app in March and a record write triggers `_updateWidget()`
- THEN the widget header updates to "March 2026"

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: 4×2 / 4×4 extra-large layout**
A dedicated layout for very large widget placements showing balance, income, expense, month label, and a larger QuickRecord bar with more prominent text. Deferred — the 2×2+ `LargeDashboard` already covers most use cases.

**NTH-2: Localized month label**
Show "Tháng 3 2026" when app language is Vietnamese. Deferred — requires passing locale preference through widget data; simpler English-only label ships first.

### Non-Functional Requirements

**NFR-1: Widget update latency**
Widget data must be written to `HomeWidgetGlanceState` within the same synchronous call that triggers `_updateWidget()` — no added async delay. Target: widget visually refreshes within 2 seconds of a record save on a mid-range device.

**NFR-2: Minimum text legibility**
All text in the 1×1 layout must be ≥ 12sp. Balance amount in large layout must be ≥ 24sp. No text may be clipped or overlap on any of the defined Glance responsive size breakpoints.

## Success Criteria

| Criterion | Metric | Target | How to Measure |
| --- | --- | --- | --- |
| 1×1 usability | Widget clearly communicates tap action | Pencil icon + hint text visible at 74×74dp | Visual inspection on Pixel 7 emulator |
| Data correctness | Income/expense match app's RecordsTab | Same values as `filteredTotalIncome`/`filteredTotalExpense` | Add a test record; compare widget vs. app display |
| Month label | "March 2026" visible on 2×2+ | Label present after `_updateWidget()` call | Widget inspection + `HomeWidget.saveWidgetData` log |
| No regression | Existing Large dashboard still works | Balance, income, expense, QuickRecord all render on 2×2 | Manual smoke test on 2×2 placement |

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
| --- | --- | --- | --- |
| Glance breakpoint ambiguity — Android may snap to wrong layout for borderline sizes | Med | Med | Test with actual widget placement on emulator across 1×1, 1×2, 2×1, 2×2; adjust dp thresholds empirically |
| `ic_input_add` / `ic_menu_edit` are system icons that may not render on all Android versions | Med | Low | Use bundled drawable resources instead of `android.R.drawable.*`; add fallback text if image unavailable |
| `filteredTotalIncome` reflects the last *navigated* month (not necessarily today's month) if user navigated away | High | Med | Before calling `_updateWidget()`, assert `_currentDate` is the real current month; or always reset to current month on `_updateWidget()` |
| `current_month` string formatting may not match locale; widget always shows English month name | Low | Med | Ship English-only; track as NTH-2 for localization follow-up |

## Constraints & Assumptions

**Constraints:**
- Android only — iOS widget is out of scope for this PRD.
- `home_widget` package v0.9.0 is the bridge — no package upgrades in this iteration.
- Glance API only (no XML-based RemoteViews) — consistent with existing `AppWidget.kt`.
- No new Kotlin dependencies; use existing Glance and `home_widget` imports.

**Assumptions:**
- `filteredTotalIncome` and `filteredTotalExpense` are synchronously computable from the in-memory record list at the time `_updateWidget()` is called. If wrong (they require a DB fetch), the data fix becomes async and may need a dedicated update path.
- RecordProvider's `_currentDate` field represents the currently displayed month. If wrong (it could be any navigated month), we need to read `DateTime.now()` directly in `_updateWidget()` instead.
- Android minimum SDK 21 supports all Glance APIs used. If wrong, some `cornerRadius` or `ColorFilter` APIs may need API-level guards.

## Out of Scope

- iOS widget implementation — separate PRD and native SwiftUI work required.
- Widget configuration screen (letting user choose which data to show) — not requested.
- Real-time / periodic widget refresh — stays event-driven via RecordProvider writes.
- Push-based widget updates when app is backgrounded — out of scope.
- Animated or interactive widget elements beyond tap-to-open — Glance does not support them.

## Dependencies

- `filteredTotalIncome` / `filteredTotalExpense` getters in RecordProvider — delivered by epic `refactor-code` (merged 2026-03-29). ✅ Resolved.
- `home_widget` package v0.9.0 — already in `pubspec.yaml`. ✅ Resolved.
- Glance `androidx.glance:glance-appwidget` — already in Android `build.gradle`. ✅ Resolved.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4]
  nice_to_have: [NTH-1, NTH-2]
  nfr: [NFR-1, NFR-2]
scale: medium
discovery_mode: express
validation_status: pending
last_validated: null
