---
name: Fix widget data pipeline — current-month filtered totals
status: open
created: 2026-03-29T05:11:10Z
updated: 2026-03-29T05:11:10Z
complexity: simple
recommended_model: sonnet
phase: 1
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/147"
depends_on: []
parallel: false
conflicts_with: []
files:
  - lib/providers/record_provider.dart
prd_requirements:
  - FR-3
  - NFR-1
---

# T1: Fix widget data pipeline — current-month filtered totals

## Context
The `_updateWidget()` method in RecordProvider manually iterates ALL records to compute income/expense totals, sending all-time aggregates to the Android home widget. The app's RecordsTab already shows monthly-filtered data via `filteredTotalIncome`/`filteredTotalExpense` getters. The widget should match.

## Description
Replace the manual loop in `_updateWidget()` with calls to existing getters (`totalBalance`, `filteredTotalIncome`, `filteredTotalExpense`) and add a new `current_month` key formatted as "March 2026" using `DateFormat` from the `intl` package. This shrinks the method from ~20 lines to ~6 lines.

Per AD-1: use `_selectedDateRange.start` for the month context (matches app's navigated month). Per AD-3: reuse existing getters instead of manual iteration.

## Acceptance Criteria
- [ ] **FR-3 / Happy path:** `total_income` and `total_spend` widget keys contain current-month filtered values (matching `filteredTotalIncome` and `filteredTotalExpense`)
- [ ] **FR-3 / Currency:** `currency` key still reads from StorageService (unchanged)
- [ ] **FR-3 / Month key:** New `current_month` key is saved with format "March 2026" (English month name + 4-digit year)
- [ ] **FR-3 / Balance:** `total_balance` still uses `totalBalance` getter (sum of all money sources — not filtered by month)
- [ ] **NFR-1 / Latency:** No new async operations added — all getters are synchronous

## Implementation Steps

### Step 1: Add intl import to record_provider.dart
- Modify `lib/providers/record_provider.dart`
- Add `import 'package:intl/intl.dart';` to the import section (follow AD-4 import ordering: dart → flutter → third-party → wallet_ai → relative)

### Step 2: Rewrite `_updateWidget()` method body
- Replace lines 201–222 of `lib/providers/record_provider.dart`
- Remove the manual `totalBalance`, `totalIncome`, `totalSpend` local variables and for-loops
- Replace with:
  ```dart
  void _updateWidget() {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedDateRange?.start ?? DateTime.now());
    HomeWidget.saveWidgetData<String>('total_balance', CurrencyHelper.format(totalBalance));
    HomeWidget.saveWidgetData<String>('total_income', CurrencyHelper.format(filteredTotalIncome));
    HomeWidget.saveWidgetData<String>('total_spend', CurrencyHelper.format(filteredTotalExpense));
    HomeWidget.saveWidgetData<String>('currency', StorageService().getString(StorageService.keyCurrency) ?? 'USD');
    HomeWidget.saveWidgetData<String>('current_month', monthLabel);
    HomeWidget.updateWidget(androidName: 'MyWidgetReceiver', iOSName: 'Quick_Chat_Widget');
  }
  ```
- `totalBalance` → getter at line 176 (sum of money sources — correct, all-time)
- `filteredTotalIncome` → getter at line 172 (filtered by `_selectedDateRange`)
- `filteredTotalExpense` → getter at line 174 (filtered by `_selectedDateRange`)

## Technical Details
- **Approach:** AD-3 — simplify `_updateWidget()` by reusing existing getters
- **Files to modify:**
  - `lib/providers/record_provider.dart` — rewrite `_updateWidget()`, add `intl` import
- **Patterns to follow:** Existing getter usage in `records_tab.dart` (uses `provider.filteredTotalIncome` etc.)
- **Edge cases:**
  - `_selectedDateRange` is null (shouldn't happen — initialized in constructor at line 31, but fallback to `DateTime.now()` in the `DateFormat` call)
  - No records for current month → `filteredTotalIncome` returns 0.0 → `CurrencyHelper.format(0.0)` → "0"

## Tests to Write

### Unit Tests
- No new test file needed — existing `test/providers/chat_provider_test.dart` and widget tests continue to pass
- Verification is manual: add a record, check widget prefs contain monthly-filtered values

### Manual Verification
- Add a record for March 2026 (income: 1,000,000 VND)
- Check widget data keys via debug logs or `HomeWidget` inspection
- Verify `total_income` shows "1.000.000" (not all-time sum)
- Verify `current_month` shows "March 2026"

## Verification Checklist
- [ ] `flutter test` — all 132 tests pass (no regressions)
- [ ] `flutter analyze` — 0 errors, 0 warnings
- [ ] `_updateWidget()` method is ≤10 lines (down from ~20)
- [ ] New `current_month` key saved via `HomeWidget.saveWidgetData`

## Dependencies
- **Blocked by:** None
- **Blocks:** T2 (AppWidget.kt needs `current_month` key)
- **External:** `intl: ^0.19.0` (already in pubspec.yaml)
