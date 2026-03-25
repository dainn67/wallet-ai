---
name: reset-all
description: Implement global data reset and money source deletion with a reusable confirmation dialog.
status: completed
priority: P1
scale: medium
created: 2026-03-25T10:00:00Z
updated: 2026-03-25T06:59:43Z
---

# PRD: reset-all

## Executive Summary
Wally AI currently lacks a mechanism for users to wipe their financial history or remove specific money sources once they are no longer needed. This feature introduces a "Reset All" option in the navigation drawer to clear all records and zero out balances, as well as a "Delete Source" option within the source editing interface. To ensure these destructive actions are intentional, a reusable, modern confirmation dialog component will be implemented and used across both flows, providing clear warnings about data loss.

## Problem Statement
Users who make significant data entry errors or wish to start over with a fresh financial state have no way to bulk-delete records or reset their wallet. Currently, they must manually delete every record one-by-one, which is tedious and error-prone. Additionally, deleting a money source is not supported, leading to cluttered interfaces when sources are no longer relevant. Without a confirmation step for these destructive actions, users risk losing data accidentally.

## Target Users
- **The "Fresh Starter":** A user who has experimented with the app and now wants to clear their "test" data to begin tracking real finances. (Pain: High - blocking them from using the app "for real")
- **The "Mistake Corrector":** A user who accidentally imported or created a large batch of incorrect records and needs to wipe the slate clean. (Pain: Medium - annoying to fix manually)
- **The "Streamliner":** A user who closed a bank account or stopped using a specific cash wallet and wants to remove that source from their view. (Pain: Low - UI clutter)

## User Stories
**US-1: Global Reset**
As a "Fresh Starter", I want to reset all my financial data from the navigation drawer so that I can start tracking my expenses from zero without manually deleting individual items.
- [ ] Reset button is visible in a dedicated "Settings" section of the drawer.
- [ ] Clicking the button opens a confirmation dialog.
- [ ] Confirming the reset deletes all records and sets all money source balances to 0.

**US-2: Delete Money Source**
As a "Streamliner", I want to delete a specific money source from the edit screen so that it no longer appears in my list of available accounts.
- [ ] Delete button is available in the "Edit Source" interface.
- [ ] Clicking delete opens a confirmation dialog with a specific warning about associated records.
- [ ] Confirming the deletion removes the source and all its associated records from the database.

**US-3: Reusable Confirmation Dialog**
As a developer, I want a standardized, modern confirmation dialog component so that I can easily add safety checks to any destructive or critical action in the app.
- [ ] Dialog accepts title, message, and callback for confirmed action.
- [ ] Dialog follows Material 3 design principles for "Alert Dialog".
- [ ] Dialog is easily styled to match the app's Poppins-based typography.

## Requirements

### Functional Requirements (MUST)

**FR-1: Reusable Confirmation Dialog Component**
Implement a generic UI component for confirmation prompts.
- Scenario: Generic Use
  - GIVEN a feature needs user confirmation
  - WHEN the component is called with `title`, `content`, and `onConfirm`
  - THEN it displays a modal with "Cancel" and "Confirm" buttons.

**FR-2: Global Data Reset Action**
Provide an option to wipe all transaction history and reset balances.
- Scenario: Reset All Data
  - GIVEN the user is in the Navigation Drawer
  - WHEN they click "Reset All Data" and confirm the prompt
  - THEN all `Record` entries are deleted, all `MoneySource` balances are updated to 0, and the UI refreshes.

**FR-3: Money Source Deletion with Cascading Cleanup**
Allow users to remove a specific money source and its history.
- Scenario: Delete Source with Records
  - GIVEN a user is editing an existing `MoneySource`
  - WHEN they click "Delete" and confirm the warning that "this will also delete X associated records"
  - THEN the source and all records linked to its ID are deleted.

**FR-4: Drawer Navigation Update**
Add a dedicated section for data management in the drawer.
- Scenario: Drawer Layout
  - GIVEN the navigation drawer is open
  - WHEN the user looks at the bottom section
  - THEN they see a Divider followed by a "Reset All Data" option.

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Record Count in Warning**
Show the actual number of records that will be deleted in the confirmation message.
- Reason: Provides better context for the scale of data loss.

### Non-Functional Requirements

**NFR-1: Atomic Deletion**
All deletions must be executed within a database transaction. If any part of the reset/deletion fails, the data state must remain unchanged.

**NFR-2: UI Responsiveness**
The UI must update immediately after the database operation completes, without requiring a manual pull-to-refresh.

**NFR-3: Visual Consistency**
The confirmation dialog must use the local Poppins font and adhere to the Material 3 color scheme defined in `main.dart`.

## Success Criteria
- 100% of data is successfully cleared upon "Reset All" confirmation.
- No "orphan" records remain in the database after a money source is deleted.
- The confirmation dialog is used for at least two different actions (Reset All and Delete Source).

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| Accidental Data Loss | High | Low | Use a red "Confirm" button and very clear warning text in the dialog. |
| Database Lock during Bulk Delete | Low | Low | Perform deletions in a background transaction to avoid blocking the UI thread. |
| State Desync | Medium | Low | Ensure `RecordProvider` is notified to reload all data after the transaction completes. |

## Constraints & Assumptions
- **Constraint:** Must use `RecordRepository` for all database interactions and `RecordProvider` for state management.
- **Assumption:** Categories should not be deleted during a "Reset All" as they are structural/configuration data rather than transaction data.
- **Assumption:** The app is primarily offline; no cloud-sync cleanup is required for this iteration.

## Out of Scope
- Undo/Redo functionality for deletions.
- Partial reset (e.g., reset only last 30 days).
- Exporting data before reset (should be a separate feature).

## Dependencies
- **RecordRepository** — Needs update to support bulk delete and source deletion.
- **RecordProvider** — Needs update to expose deletion methods to the UI.

## _Metadata
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2, NFR-3]
scale: medium
discovery_mode: full
validation_status: pending
last_validated: null
