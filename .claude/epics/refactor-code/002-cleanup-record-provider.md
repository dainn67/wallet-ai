---
name: Clean up RecordProvider — extract boilerplate, standardize error handling
status: open
created: 2026-03-28T17:50:49Z
updated: 2026-03-28T17:50:49Z
complexity: moderate
recommended_model: sonnet
phase: 1
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/138"
depends_on: [001]
parallel: false
conflicts_with: []
files:
  - lib/providers/record_provider.dart
prd_requirements:
  - FR-3
  - FR-4
  - FR-6
---

# Clean up RecordProvider — extract boilerplate, standardize error handling

## Context

RecordProvider has 9+ CRUD methods that repeat the same boilerplate pattern (loading state → try → operation → catch → finally → notifyListeners → _updateWidget). Error handling is inconsistent: Record CRUD uses `debugPrint`, Category CRUD uses `ToastService().showError()`. The `fetchData()` alias adds redundancy. Per AD-2, extracting a private helper eliminates duplication.

## Description

Extract the repetitive CRUD boilerplate into a private `_performOperation()` helper. Remove the redundant `fetchData()` alias. Standardize error handling so all methods log via `debugPrint` and optionally show user toast. Preserve the subtle behavioral differences between methods (some reload all data, some patch state locally).

## Acceptance Criteria

- [ ] **FR-3 / Happy path:** No two public methods in RecordProvider perform the same operation — `fetchData()` alias is removed
- [ ] **FR-3 / Happy path:** CRUD methods use the shared `_performOperation()` helper where applicable, reducing code duplication
- [ ] **FR-4 / Happy path:** All CRUD methods follow the consistent error handling convention: `debugPrint` for logging; `ToastService` only for category operations
- [ ] **FR-4 / Happy path:** All CRUD methods follow the same loading state pattern: `_isLoading = true` → `notifyListeners()` → operation → `_isLoading = false` → `notifyListeners()`
- [ ] **FR-6 / Behavior preservation:** `addMoneySource` still partially updates local state (adds to `_moneySources` list) and conditionally calls `loadAll()` — this behavior is preserved
- [ ] **FR-6 / Behavior preservation:** `updateMoneySource` still patches the local list instead of calling `loadAll()` — this behavior is preserved
- [ ] **FR-6 / Behavior preservation:** All other CRUD methods still call `loadAll()` after their operation
- [ ] **FR-6 / Edge case:** Category add/update/delete still show toast on error (user-facing validation errors)

## Implementation Steps

### Step 1: Document current method behaviors

Before any code changes, map each CRUD method's unique behavior:
- `addRecord`: try → repo.create → loadAll | catch → debugPrint → loadAll | finally → loading=false, notify, updateWidget
- `updateRecord`: try → repo.update → loadAll | catch → debugPrint → loadAll | finally → loading=false, notify, updateWidget
- `deleteRecord`: try → repo.delete → loadAll | catch → debugPrint → loadAll | finally → loading=false, notify, updateWidget
- `addMoneySource`: try → repo.create → add to local list → conditionally loadAll | catch → debugPrint → loadAll | finally → loading=false, notify, updateWidget
- `updateMoneySource`: try → repo.update → patch local list | catch → debugPrint → loadAll | finally → loading=false, notify, updateWidget
- `deleteMoneySource`: try → repo.delete → remove from local list → loadAll | catch → debugPrint → loadAll | finally → loading=false, notify, updateWidget
- `addCategory`: try → repo.create → loadAll | catch → debugPrint + toast | finally → loading=false, notify (NO updateWidget)
- `updateCategory`: try → repo.create → loadAll | catch → debugPrint + toast | finally → loading=false, notify (NO updateWidget)
- `deleteCategory`: try → repo.delete → loadAll | catch → debugPrint + toast | finally → loading=false, notify (NO updateWidget)

### Step 2: Create `_performOperation` private helper

- Modify `lib/providers/record_provider.dart`
- Add private method:
  ```dart
  Future<void> _performOperation(
    Future<void> Function() operation, {
    bool reloadAll = true,
    bool updateWidget = true,
    bool showToastOnError = false,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await operation();
      if (reloadAll) await loadAll();
    } catch (e) {
      debugPrint('Error in RecordProvider: $e');
      if (showToastOnError) ToastService().showError(e.toString());
      if (reloadAll) await loadAll();
    } finally {
      _isLoading = false;
      notifyListeners();
      if (updateWidget) _updateWidget();
    }
  }
  ```

### Step 3: Refactor CRUD methods to use helper

- Refactor simple methods (addRecord, updateRecord, deleteRecord) to:
  ```dart
  Future<void> addRecord(Record record) => _performOperation(
    () => _repository.createRecord(record),
  );
  ```
- For methods with special behavior (addMoneySource, updateMoneySource), keep inline with the standardized error pattern but don't force into the helper if the logic differs significantly
- For category methods, pass `showToastOnError: true, updateWidget: false`

### Step 4: Remove fetchData alias

- Delete: `Future<void> fetchData() => loadAll();` (line 177)
- Search for any callers of `fetchData()` in the codebase — if found, replace with `loadAll()`

### Step 5: Include createRecord from T1 in the pattern

- The `createRecord()` method added in T1 is lightweight (no loading state) — it stays outside the `_performOperation` pattern since it's designed for batch use

## Interface Contract

### Receives from T1:
- File: `lib/providers/record_provider.dart`
  - Method: `createRecord(Record)` — lightweight record creation
  - This method stays outside `_performOperation` pattern (batch use, no loading state)

## Technical Details

- **Approach:** Per AD-2, private helper extracts common boilerplate
- **Files to modify:** `lib/providers/record_provider.dart`
- **Patterns to follow:** Current CRUD pattern in RecordProvider — the helper formalizes it
- **Edge cases:**
  - `addMoneySource`: Conditionally calls `loadAll()` only when `source.amount > 0` — this must be preserved in refactored code. May need to stay partially inline.
  - `updateMoneySource`: Patches local list instead of reloading — pass `reloadAll: false` to helper
  - `resetAllData`: Has unique pattern (no loading=false in try, loadAll in finally) — keep inline or adapt helper

## Tests to Write

### Unit Tests
- `test/providers/record_provider_test.dart`
  - Test: `addRecord()` creates record and reloads all data → expect records list updated
  - Test: `addCategory()` with invalid data → expect toast shown AND debugPrint logged
  - Test: `updateMoneySource()` patches local list without full reload → expect moneySources list updated at index
  - Test: `fetchData()` no longer exists → expect compilation error if called (verified by `flutter analyze`)

## Verification Checklist

- [ ] `flutter analyze` passes with zero errors
- [ ] `grep -r "fetchData" lib/` returns only test files or zero results
- [ ] Manual test: Add record → appears in list
- [ ] Manual test: Edit record → changes reflected
- [ ] Manual test: Delete record → removed from list
- [ ] Manual test: Add money source with amount → record created + source visible
- [ ] Manual test: Add category → appears in categories tab
- [ ] Manual test: Add invalid category → toast error shown
- [ ] No increase in RecordProvider line count by more than 10%

## Dependencies

- **Blocked by:** T1 (need createRecord method to include)
- **Blocks:** T3 (T3 adds computed getters that depend on clean provider)
- **External:** None
