---
name: Extract business logic from RecordsTab and CategoriesTab
status: open
created: 2026-03-28T17:50:49Z
updated: 2026-03-28T17:50:49Z
complexity: simple
recommended_model: sonnet
phase: 2
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/139"
depends_on: [002]
parallel: true
conflicts_with: []
files:
  - lib/providers/record_provider.dart
  - lib/screens/home/tabs/records_tab.dart
  - lib/screens/home/tabs/categories_tab.dart
prd_requirements:
  - FR-2
  - FR-6
---

# Extract business logic from RecordsTab and CategoriesTab

## Context

RecordsTab computes `totalIncome`, `totalExpense`, and `totalBalance` inline in its `build()` method (lines 22-24). CategoriesTab has a `_updateMonth()` method (lines 11-18) that manipulates date ranges directly. These are business logic computations that belong in RecordProvider per FR-2.

## Description

Move the three financial aggregation computations to computed getters on RecordProvider. Move the month navigation logic to a provider method. Update the tabs to consume these getters/methods instead of computing inline.

## Acceptance Criteria

- [ ] **FR-2 / Happy path:** RecordsTab `build()` method contains no `.where()`, `.fold()`, or arithmetic on records/sources — all values come from provider getters
- [ ] **FR-2 / Happy path:** CategoriesTab no longer contains date manipulation logic — uses `provider.navigateMonth(delta)` instead
- [ ] **FR-6 / Behavior preservation:** Records tab total income displays the sum of income-type records from `filteredRecords` only
- [ ] **FR-6 / Behavior preservation:** Records tab total expense displays the sum of expense-type records from `filteredRecords` only
- [ ] **FR-6 / Behavior preservation:** Records tab total balance displays the sum of ALL money sources (not filtered)
- [ ] **FR-6 / Behavior preservation:** Categories tab month navigation changes the selected date range and triggers category total recalculation

## Implementation Steps

### Step 1: Add computed getters to RecordProvider

- Modify `lib/providers/record_provider.dart`
- Add getter `double get filteredTotalIncome` that computes:
  ```dart
  filteredRecords.where((r) => r.type == 'income').fold<double>(0, (sum, r) => sum + r.amount)
  ```
- Add getter `double get filteredTotalExpense` that computes:
  ```dart
  filteredRecords.where((r) => r.type == 'expense').fold<double>(0, (sum, r) => sum + r.amount)
  ```
- Add getter `double get totalBalance` that computes:
  ```dart
  _moneySources.fold<double>(0, (sum, s) => sum + s.amount)
  ```

### Step 2: Add `navigateMonth` method to RecordProvider

- Add method `void navigateMonth(int delta)` to RecordProvider:
  ```dart
  void navigateMonth(int delta) {
    final current = _selectedDateRange?.start ?? DateTime.now();
    final newMonth = DateTime(current.year, current.month + delta);
    selectedDateRange = DateTimeRange(
      start: newMonth,
      end: DateTime(newMonth.year, newMonth.month + 1, 0, 23, 59, 59, 999),
    );
  }
  ```
  Note: `selectedDateRange` setter already calls `_calculateCategoryTotals()` and `notifyListeners()`.

### Step 3: Update RecordsTab

- Modify `lib/screens/home/tabs/records_tab.dart`
- Replace lines 22-24:
  - `final totalIncome = records.where(...).fold(...)` → `final totalIncome = provider.filteredTotalIncome;`
  - `final totalExpense = records.where(...).fold(...)` → `final totalExpense = provider.filteredTotalExpense;`
  - `final totalBalance = provider.moneySources.fold(...)` → `final totalBalance = provider.totalBalance;`

### Step 4: Update CategoriesTab

- Modify `lib/screens/home/tabs/categories_tab.dart`
- Remove the `_updateMonth` method entirely (lines 11-18)
- Replace calls: `_updateMonth(context, -1)` → `context.read<RecordProvider>().navigateMonth(-1)`
- Replace calls: `_updateMonth(context, 1)` → `context.read<RecordProvider>().navigateMonth(1)`

## Technical Details

- **Approach:** Move business computations to provider as computed getters
- **Files to modify:**
  - `lib/providers/record_provider.dart` — add 3 getters + 1 method
  - `lib/screens/home/tabs/records_tab.dart` — replace inline computations
  - `lib/screens/home/tabs/categories_tab.dart` — replace `_updateMonth` with provider call
- **Patterns to follow:** See existing `filteredRecords` getter in record_provider.dart — same pattern
- **Edge cases:**
  - `totalBalance` is sum of ALL money sources, not just filtered ones. This is the current behavior and must be preserved.
  - `filteredTotalIncome`/`filteredTotalExpense` use `filteredRecords` which already applies date/source/type filters. This is correct.

## Tests to Write

### Unit Tests
- `test/providers/record_provider_test.dart`
  - Test: `filteredTotalIncome` returns sum of income records only → expect correct amount
  - Test: `filteredTotalExpense` returns sum of expense records only → expect correct amount
  - Test: `totalBalance` returns sum of all money source amounts → expect correct total
  - Test: `navigateMonth(1)` advances to next month → expect `selectedDateRange` updated

## Verification Checklist

- [ ] `flutter analyze` passes with zero errors
- [ ] `grep -n "\.fold\|\.where" lib/screens/home/tabs/records_tab.dart` returns empty (no inline aggregation)
- [ ] `grep -n "_updateMonth" lib/screens/home/tabs/categories_tab.dart` returns empty
- [ ] Manual test: Records tab shows correct income/expense/balance totals
- [ ] Manual test: Categories tab month navigation works (left/right arrows)

## Dependencies

- **Blocked by:** T2 (clean provider needed before adding more methods)
- **Blocks:** None
- **External:** None
