---
name: reset-all
status: backlog
created: 2026-03-25T10:15:00Z
progress: 0%
priority: P1
prd: .claude/prds/reset-all.md
task_count: 6
github: "https://github.com/dainn67/wallet-ai/issues/104"
---

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

## Tasks Created
| #   | Task                     | Phase | Parallel | Est. | Depends On | Status |
| --- | ------------------------ | ----- | -------- | ---- | ---------- | ------ |
| 105 | Create ConfirmationDialog component | 1     | yes      | 1d   | —          | open   |
| 106 | Implement resetAllData backend logic | 1     | yes      | 1d   | —          | open   |
| 107 | Update deleteMoneySource with cascading removal | 1     | yes      | 1d   | —          | open   |
| 108 | Add "Reset All Data" to HomeScreen drawer | 2     | yes      | 1d   | 105, 106   | open   |
| 109 | Add "Delete Source" to EditSourcePopup | 2     | yes      | 1d   | 105, 107   | open   |
| 110 | Write unit and integration tests | 3     | yes      | 1d   | 106, 107   | open   |
| 111 | Integration verification & cleanup | 3     | no       | 1d   | all        | open   |

### Summary
- **Total tasks:** 7
- **Parallel tasks:** 6
- **Sequential tasks:** 1
- **Estimated total effort:** 7d
- **Critical path:** T002 -> T010 -> T090 (~3d)

### Dependency Graph
```
Dependency Graph:
  T105 ──→ T108 ──→ T111
       ──→ T109 ─↗
  T106 ──→ T108 ─↗
       ──→ T110 ─↗
  T107 ──→ T109 ─↗
       ──→ T110 ─↗

Critical path: T106 → T108 → T111 (~3d)
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: Dialog    | T001       | ✅ Covered |
| FR-2: Reset All | T002, T010, T020 | ✅ Covered |
| FR-3: Delete Source | T003, T011, T020 | ✅ Covered |
| FR-4: Drawer    | T010       | ✅ Covered |
| NFR-1: Atomic   | T002, T003, T020 | ✅ Covered |
| NFR-2: Responsive| T002, T003 | ✅ Covered |
| NFR-3: Visual   | T001       | ✅ Covered |
