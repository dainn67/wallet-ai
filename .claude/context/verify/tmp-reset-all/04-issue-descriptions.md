<!-- Source: GitHub Issues API | Collected: 2026-03-25T06:35:15Z | Epic: reset-all -->

# Issue Descriptions

## Issue #104: Epic: reset-all


# Epic: reset-all

## Overview
This epic implements a safe and efficient way for users to reset their financial data or delete specific money sources. The core architectural approach involves introducing a reusable `ConfirmationDialog` to prevent accidental data loss and updating the `RecordRepository` to handle bulk deletions and cascading record removal within atomic transactions.

## Architecture Decisions

### AD-1: Reusable Confirmation Dialog
**Context:** Multiple features (Reset All, Delete Source, and potentially others in the future) require a standard way to confirm destructive actions.
**Decision:** Create a standalone `ConfirmationDialog` in `lib/components/popups/confirmation_dialog.dart`.
**Alternatives rejected:** Using inline `showDialog` calls in every screen (leads to duplication and inconsistent UI).
**Trade-off:** Slightly more upfront setup for a reusable component, but ensures visual consistency and easier maintenance.
**Reversibility:** Easy to modify the component's style globally.

### AD-2: Atomic Reset & Cascading Deletion
**Context:** Deleting data must be all-or-nothing to prevent inconsistent states (e.g., records deleted but balances not reset).
**Decision:** Implement `resetAllData` and an updated `deleteMoneySource` using SQLite `transaction`.
**Alternatives rejected:** Deleting records and updating sources in separate calls (risks state desync if one fails).
**Trade-off:** Requires careful handling of the database connection within transactions.
**Reversibility:** Hard to reverse data loss once committed, hence the mandatory confirmation UI.

## Technical Approach

### UI Layer (Components)
- **ConfirmationDialog**: A stateless widget using `AlertDialog` with `Poppins` font. Props: `title`, `message`, `confirmLabel`, `cancelLabel`, `onConfirm`, `isDestructive` (boolean to style the confirm button).
- **Navigation Drawer**: Update `_buildAppDrawer` in `lib/screens/home/home_screen.dart` to include a "Data Management" section.
- **EditSourcePopup**: Update `lib/components/popups/edit_source_popup.dart` to add a "Delete" button.

### State & Data Layer
- **RecordRepository**:
    - Add `Future<void> resetAllData()`: `DELETE FROM Record`, `UPDATE MoneySource SET amount = 0`.
    - Update `deleteMoneySource(int id)`: `DELETE FROM Record WHERE money_source_id = ?`, then `DELETE FROM MoneySource WHERE source_id = ?`.
- **RecordProvider**:
    - Add `Future<void> resetAllData()`: Call repository and then `loadAll()`.
    - Update `deleteMoneySource(int id)`: Ensure it reloads data or updates local lists correctly.

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Dialog    | Architecture Decision AD-1 | T1 | Widget test |
| FR-2: Reset All | Technical Approach / Data Layer | T2, T4 | Integration test |
| FR-3: Delete Source | Technical Approach / Data Layer | T3, T5 | Integration test |
| FR-4: Drawer    | Technical Approach / UI Layer | T4 | Manual check |
| NFR-1: Atomic   | Architecture Decision AD-2 | T2, T3 | Unit test (transaction check) |
| NFR-2: Responsive| RecordProvider.loadAll() usage | T2, T3 | Manual check |
| NFR-3: Visual   | ConfirmationDialog styling | T1 | Manual check |

## Implementation Strategy

### Phase 1: Foundation
Implement the core UI component and the database logic.
- **Exit Criterion:** `ConfirmationDialog` is buildable, and `RecordRepository` methods pass unit tests.

### Phase 2: Core
Integrate the logic into the app's navigation and editing flows.
- **Exit Criterion:** "Reset All" and "Delete Source" are accessible in the UI and trigger the confirmation dialog.

### Phase 3: Polish
Finalize state synchronization and add comprehensive tests.
- **Exit Criterion:** All tests pass, and UI refreshes immediately after deletions.

## Task Breakdown

##### T1: Create ConfirmationDialog component
- **Phase:** 1 | **Parallel:** yes | **Est:** 1d | **Depends:** — | **Complexity:** simple
- **What:** Implement `ConfirmationDialog` in `lib/components/popups/confirmation_dialog.dart`. Use `AlertDialog` with `Poppins` font. Support an `isDestructive` flag to turn the confirm button red.
- **Key files:** `lib/components/popups/confirmation_dialog.dart`
- **PRD requirements:** FR-1, NFR-3
- **Key risk:** Ensuring the dialog matches the exact styling of other popups like `EditSourcePopup`.

##### T2: Implement resetAllData in repository and provider
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Depends:** — | **Complexity:** moderate
- **What:** Add `resetAllData` to `RecordRepository` using a transaction. Add a corresponding method to `RecordProvider` that triggers the reset and reloads the state.
- **Key files:** `lib/repositories/record_repository.dart`, `lib/providers/record_provider.dart`
- **PRD requirements:** FR-2, NFR-1
- **Key risk:** Transaction management if the database is busy.

##### T3: Update deleteMoneySource with cascading record removal
- **Phase:** 1 | **Parallel:** yes | **Est:** 1d | **Depends:** — | **Complexity:** moderate
- **What:** Modify `RecordRepository.deleteMoneySource` to also delete records associated with the source ID within a transaction.
- **Key files:** `lib/repositories/record_repository.dart`
- **PRD requirements:** FR-3, NFR-1
- **Key risk:** Accidental deletion of records from the wrong source if ID handling is incorrect.

##### T4: Add "Reset All Data" to HomeScreen drawer
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1, T2 | **Complexity:** simple
- **What:** Update `_buildAppDrawer` in `home_screen.dart` to add a "Reset All Data" ListTile after a divider. Wire it to open `ConfirmationDialog` and call `RecordProvider.resetAllData`.
- **Key files:** `lib/screens/home/home_screen.dart`
- **PRD requirements:** FR-2, FR-4
- **Key risk:** UI clutter in the drawer if not placed correctly.

##### T5: Add "Delete Source" to EditSourcePopup
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1, T3 | **Complexity:** simple
- **What:** Add a "Delete" text button to `EditSourcePopup`. Wire it to open `ConfirmationDialog` and call `RecordProvider.deleteMoneySource`.
- **Key files:** `lib/components/popups/edit_source_popup.dart`
- **PRD requirements:** FR-3
- **Key risk:** Button placement should be distinct from "Save" and "Cancel" to avoid accidental clicks.

##### T6: Write unit and integration tests
- **Phase:** 3 | **Parallel:** yes | **Est:** 1d | **Depends:** T2, T3 | **Complexity:** moderate
- **What:** Create tests to verify that `resetAllData` clears all records and zeros balances, and `deleteMoneySource` removes associated records.
- **Key files:** `test/repositories/record_repository_test.dart`, `test/providers/record_provider_test.dart`
- **PRD requirements:** FR-2, FR-3, NFR-1
- **Key risk:** Mocking the database correctly for transactional tests.

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Accidental Data Wipe | High | Low | Total data loss | Mandatory `ConfirmationDialog` with explicit warning message. |
| State Desync | Medium | Low | UI shows stale data | Use `RecordProvider.loadAll()` immediately after repository operations. |
| Orphaned Records | High | Low | Database bloat | Enforce cascading delete in `RecordRepository` within a transaction. |

## Dependencies
- **RecordRepository** — Core data operations.
- **RecordProvider** — State management and UI notification.

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| 100% Data Cleared | Record count | 0 | Query `Record` table after reset. |
| No Orphans | Orphan record count | 0 | Query `Record` table for deleted `source_id`. |
| Unified Dialog | Component Reuse | 2 usage points | Code audit of `home_screen.dart` and `edit_source_popup.dart`. |

## Estimated Effort
- **Total:** 6 days
- **Critical Path:** T2 -> T4
- **Phases Timeline:** Phase 1 (2 days), Phase 2 (2 days), Phase 3 (2 days).

## Deferred / Follow-up
- **NTH-1: Record Count in Warning:** Deferred until `RecordRepository` has an efficient way to count records by source ID without full fetch.



## Tasks

- [ ] #105 Create ConfirmationDialog component
- [ ] #106 Implement resetAllData backend logic
- [ ] #107 Update deleteMoneySource with cascading removal
- [ ] #108 Add "Reset All Data" to HomeScreen drawer
- [ ] #109 Add "Delete Source" to EditSourcePopup
- [ ] #110 Write unit and integration tests
- [ ] #111 Integration verification & cleanup


---

## Issue #105: Create ConfirmationDialog component


# Task: Create ConfirmationDialog component

## Context
Multiple features in the app (like Reset All Data or Delete Source) involve destructive actions that cannot be easily undone. To ensure users don't accidentally lose data, we need a reusable, standardized confirmation dialog.

## Description
Implement a `ConfirmationDialog` component that uses Material 3 `AlertDialog` styling but with our custom `Poppins` font. It needs to support custom titles, messages, button labels, and a visual indicator (like a red button) for destructive actions.

## Acceptance Criteria
- [ ] **FR-1 / Happy path:** Calling the widget displays a dialog with the provided title, content, and buttons.
- [ ] **FR-1 / Action:** Clicking "Confirm" executes the `onConfirm` callback and closes the dialog.
- [ ] **FR-1 / Cancel:** Clicking "Cancel" simply closes the dialog without executing `onConfirm`.
- [ ] **NFR-3 / Styling:** Dialog uses the `Poppins` font. If `isDestructive` is true, the confirm button has a red text/background color to indicate danger.

## Implementation Steps
1. Create `lib/components/popups/confirmation_dialog.dart`.
2. Define a stateless widget `ConfirmationDialog`.
3. Add properties: `String title`, `String content`, `String confirmLabel`, `String cancelLabel`, `VoidCallback onConfirm`, `bool isDestructive`.
4. Build the UI using `AlertDialog`:
   - Set `backgroundColor: Colors.white`, `surfaceTintColor: Colors.transparent`.
   - Title text uses `Poppins`, size 20, bold.
   - Content text uses `Poppins`, size 14, regular.
   - Cancel button uses `TextButton` with grey text.
   - Confirm button uses `ElevatedButton`. If `isDestructive` is true, use a red background (e.g., `Colors.red.shade600`). Otherwise, use the primary theme color.
5. In the button callbacks, ensure `Navigator.of(context).pop()` is called before or after `onConfirm`.
6. Export the new popup in `lib/components/components.dart` if such an export file exists, or ensure it's accessible.

## Tests to Write
- Widget Test: `test/components/popups/confirmation_dialog_test.dart`
  - Render `ConfirmationDialog`, verify title and content text are present.
  - Tap "Cancel", verify dialog closes and callback is not fired.
  - Tap "Confirm", verify dialog closes and callback is fired.
  - Render with `isDestructive: true`, verify confirm button color is red.

## Verification Checklist
1. Create a temporary button somewhere in the app to show this dialog.
2. Verify visual appearance matches other popups (rounded corners, font).
3. Verify button click handlers work.


---

## Issue #106: Implement resetAllData backend logic


# Task: Implement resetAllData backend logic

## Context
Users need a way to start fresh by wiping all transaction history and zeroing out balances. This requires atomic database operations to ensure data integrity.

## Description
Add a `resetAllData` method to `RecordRepository` that deletes all records and resets all money source balances to zero within a single database transaction. Then, expose this functionality through `RecordProvider` so the UI can trigger it and update automatically.

## Acceptance Criteria
- [ ] **FR-2 / Happy path:** Calling `RecordRepository.resetAllData()` deletes all rows in `Record` and updates `amount = 0` for all rows in `MoneySource`.
- [ ] **NFR-1 / Atomicity:** The database operation is wrapped in a `transaction`. If an error occurs midway, no data is changed.
- [ ] **FR-2 / State Update:** Calling `RecordProvider.resetAllData()` triggers the repository method and then successfully calls `loadAll()` to refresh the app state.

## Implementation Steps
1. **RecordRepository**: Open `lib/repositories/record_repository.dart`.
   - Add method: `Future<void> resetAllData() async`.
   - Inside, use `await database.transaction((txn) async { ... })`.
   - Execute: `await txn.delete('Record');`
   - Execute: `await txn.rawUpdate('UPDATE MoneySource SET amount = 0');`
2. **RecordProvider**: Open `lib/providers/record_provider.dart`.
   - Add method: `Future<void> resetAllData() async`.
   - Set `_isLoading = true; notifyListeners();`.
   - `try { await _repository.resetAllData(); }`
   - `catch (e) { debugPrint(...); }`
   - `finally { await loadAll(); }`

## Tests to Write
- Unit/Integration Test: Add cases to existing `record_repository_test.dart` or create a new test.
  - Insert dummy records and sources.
  - Call `resetAllData()`.
  - Fetch all records -> expect empty list.
  - Fetch all sources -> expect all amounts to be 0.

## Verification Checklist
1. Inspect code to ensure `txn.delete` and `txn.rawUpdate` are used inside the transaction block.
2. Verify `RecordProvider` correctly manages `_isLoading` state during the operation.


---

## Issue #107: Update deleteMoneySource with cascading removal


# Task: Update deleteMoneySource with cascading removal

## Context
Currently, deleting a money source (if supported) or adding the feature requires ensuring that no "orphan" records are left in the database pointing to a non-existent source.

## Description
Modify the existing `deleteMoneySource` method in `RecordRepository` so that it first deletes all `Record` entries associated with that `source_id` before deleting the `MoneySource` itself. This must happen inside an atomic transaction.

## Acceptance Criteria
- [ ] **FR-3 / Cascading Delete:** When a money source is deleted, all records with `money_source_id == id` are also deleted from the database.
- [ ] **NFR-1 / Atomicity:** The deletion of records and the source are wrapped in a single database transaction.

## Implementation Steps
1. **RecordRepository**: Open `lib/repositories/record_repository.dart`.
2. Locate `Future<int> deleteMoneySource(int id) async`.
3. Change implementation to use `database.transaction`:
   ```dart
   return await database.transaction((txn) async {
     // 1. Delete associated records
     await txn.delete('Record', where: 'money_source_id = ?', whereArgs: [id]);
     // 2. Delete the source
     return await txn.delete('MoneySource', where: 'source_id = ?', whereArgs: [id]);
   });
   ```
4. Verify `RecordProvider` calls this method and handles state updates correctly (it should already remove the source from `_moneySources`, but make sure it also calls `loadAll()` to refresh the records list since records were deleted).
   - In `RecordProvider.deleteMoneySource`, ensure `await loadAll();` is called in the `finally` block or right after successful deletion.

## Tests to Write
- Unit/Integration Test: Add case to `record_repository_test.dart`.
  - Create a source. Create 2 records linked to it.
  - Delete the source.
  - Query source -> expect null.
  - Query records -> expect the 2 linked records are gone.

## Verification Checklist
1. Review `deleteMoneySource` in repository for transaction usage.
2. Review `deleteMoneySource` in provider to ensure `loadAll()` is invoked to resync state.


---

## Issue #108: Add "Reset All Data" to HomeScreen drawer


# Task: Add "Reset All Data" to HomeScreen drawer

## Context
Users need a UI access point to trigger the global reset. The navigation drawer is the appropriate place for destructive global settings.

## Description
Update the drawer in `HomeScreen` to include a "Data Management" section with a "Reset All Data" option. Clicking it should open the `ConfirmationDialog`. Upon confirmation, call `RecordProvider.resetAllData`.

## Interface Contract
- **Requires**: `ConfirmationDialog` (T001), `RecordProvider.resetAllData` (T002).

## Acceptance Criteria
- [ ] **FR-4 / Layout:** The drawer has a "Data Management" header or a divider separating it from other settings.
- [ ] **FR-2 / Action:** Clicking "Reset All Data" shows the destructive `ConfirmationDialog`.
- [ ] **FR-2 / Execution:** Confirming the dialog calls `context.read<RecordProvider>().resetAllData()` and closes the drawer/dialog.

## Implementation Steps
1. Open `lib/screens/home/home_screen.dart`.
2. In `_buildAppDrawer`, locate the bottom section (after the Currency tile).
3. Add a `Divider()`.
4. Add a "Data Management" label similar to the "Settings" label.
5. Add a `ListTile` with:
   - `leading: Icon(Icons.delete_forever, color: Colors.red)`
   - `title: Text('Reset All Data', style: TextStyle(color: Colors.red))`
   - `onTap:` callback.
6. In `onTap`, show the `ConfirmationDialog` using `showDialog`.
   - Title: "Reset All Data"
   - Message: "Are you sure you want to delete all records and reset all balances to zero? This action cannot be undone."
   - `isDestructive: true`
   - `confirmLabel: 'Reset'`
   - `cancelLabel: 'Cancel'`
   - `onConfirm`: Call `context.read<RecordProvider>().resetAllData(); Navigator.of(context).pop();` (make sure to also close the drawer if needed).

## Tests to Write
- Widget test in `home_screen_test.dart` to verify the drawer contains the new tile and tapping it opens a dialog.

## Verification Checklist
1. Open app, open drawer.
2. Tap "Reset All Data".
3. Verify dialog appears.
4. Tap Cancel -> nothing happens.
5. Tap Reset -> data clears, UI updates.


---

## Issue #109: Add "Delete Source" to EditSourcePopup


# Task: Add "Delete Source" to EditSourcePopup

## Context
Users need a way to delete a money source they no longer use. The existing edit popup is the logical place to add a delete action.

## Description
Add a "Delete" button to the `EditSourcePopup`. Clicking it should show the `ConfirmationDialog` warning the user that associated records will also be deleted. Confirming executes the deletion via `RecordProvider`.

## Interface Contract
- **Requires**: `ConfirmationDialog` (T001), cascading `deleteMoneySource` in backend (T003).

## Acceptance Criteria
- [ ] **FR-3 / UI:** A distinct "Delete" button (icon or text) is visible in the edit popup.
- [ ] **FR-3 / Warning:** Clicking delete shows the `ConfirmationDialog` explicitly warning about associated records.
- [ ] **FR-3 / Execution:** Confirming calls `context.read<RecordProvider>().deleteMoneySource(sourceId)` and closes both popups.

## Implementation Steps
1. Open `lib/components/popups/edit_source_popup.dart`.
2. Add a delete icon button to the top right of the popup, OR add a text button below the Save/Cancel row. A top-right trash icon (`IconButton(icon: Icon(Icons.delete_outline, color: Colors.red))`) next to the title might be cleanest.
3. In the `onPressed` handler, use `showDialog` to show `ConfirmationDialog`.
   - Title: "Delete Source"
   - Message: "Are you sure you want to delete '${widget.source.sourceName}'? This will also delete all transaction records associated with this source. This cannot be undone."
   - `isDestructive: true`
   - `confirmLabel: 'Delete'`
4. In `onConfirm`:
   - Ensure you capture the `BuildContext` correctly.
   - Call `context.read<RecordProvider>().deleteMoneySource(widget.source.sourceId!)`.
   - Close the dialog.
   - Close the edit popup by popping `null` or a specific result so the caller knows it was deleted.

## Tests to Write
- Widget test: Render `EditSourcePopup`, tap delete icon, verify dialog shows.

## Verification Checklist
1. Open edit source popup.
2. Tap delete icon.
3. Verify warning text mentions associated records.
4. Confirm deletion.
5. Verify source disappears from lists and associated records are removed.


---

## Issue #110: Write unit and integration tests


# Task: Write unit and integration tests

## Context
We need automated verification that the destructive operations work correctly and handle edge cases safely.

## Description
Create or update tests for `RecordRepository` and `RecordProvider` to cover the new `resetAllData` and updated `deleteMoneySource` logic.

## Acceptance Criteria
- [ ] **FR-2 / Test:** `resetAllData` is tested to clear `Record` table and zero `MoneySource` amounts.
- [ ] **FR-3 / Test:** `deleteMoneySource` is tested to delete the source and its related `Record` entries.
- [ ] **NFR-1 / Test:** State updates in `RecordProvider` are verified after these actions.

## Implementation Steps
1. **Repository Tests (`test/repositories/record_repository_test.dart`)**:
   - Ensure an in-memory SQLite database is used for testing.
   - Setup: Seed sources and records.
   - Test `deleteMoneySource`: Verify records count drops, target source disappears.
   - Test `resetAllData`: Verify records count is 0, all source amounts are 0.
2. **Provider Tests (`test/providers/record_provider_test.dart`)**:
   - Mock `RecordRepository`.
   - Test `deleteMoneySource`: Verify `_repository.deleteMoneySource` is called, and `loadAll` is called.
   - Test `resetAllData`: Verify `_repository.resetAllData` is called, and `loadAll` is called.

## Tests to Write
- Full integration tests on the SQLite layer.
- Unit tests on the Provider layer with mocking.

## Verification Checklist
1. Run `fvm flutter test test/repositories/record_repository_test.dart`.
2. Run `fvm flutter test test/providers/record_provider_test.dart`.
3. Ensure all tests pass.


---

## Issue #111: Integration verification & cleanup


# Task: Integration verification & cleanup

## Context
Final quality gate before epic completion. Ensures all tasks integrate correctly and all PRD requirements are met.

## Acceptance Criteria
- [ ] All other tasks in this epic are status: done
- [ ] Full build succeeds with no errors
- [ ] All existing tests pass (no regressions)
- [ ] New tests for this epic all pass
- [ ] 100% Data Cleared metric is met (0 records after reset).
- [ ] No Orphans metric is met (0 records left for deleted source).

## Verification
1. Build the app: `fvm flutter build apk` or run on simulator.
2. Run all tests: `fvm flutter test`
3. Manually test the "Reset All Data" flow in the app.
4. Manually test the "Delete Source" flow in the app.


---

