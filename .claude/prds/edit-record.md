---
name: edit-record
description: Add functionality to edit existing financial records, including UI updates and database refactoring.
status: complete
priority: P1
scale: medium
created: 2026-03-22T00:00:00Z
updated: 2026-03-22T12:20:00Z
---

# PRD: edit-record

## Executive Summary
This feature allows users to correct mistakes in their transaction history. We will add an "Edit" button to each record in the Records tab, which opens a popup to update details like amount, type (income/expense), money source, and description. This also includes a database refactor to rename the `record` table to `Record` and replace the `created_at` column with `last_updated`.

## Problem Statement
Users currently cannot edit transactions once they are saved. If a mistake is made during entry, the only way to fix it is to delete the record and create a new one, which is friction-heavy and prone to further errors.

## Target Users
- All users who track their daily finances and occasionally make data entry errors.

## User Stories
**US-1: Trigger Edit Flow**
As a user, I want to see an "Edit" button on each record in the Records tab so that I can easily start correcting a transaction.

**US-2: Update Record Details**
As a user, I want to modify the amount, type, source, and description of a record in a popup so that I can ensure my data is accurate.

**US-3: Atomic Update**
As a user, I want the balances of my money sources to be automatically adjusted if I change the amount or source of a record.

## Requirements

### Functional Requirements (MUST)

**FR-1: Conditional Edit Button**
Add an `IconButton` with `Icons.edit_rounded` to `RecordWidget`.
- Use a boolean flag `isEditable` (default `false`) to control visibility.
- Enable `isEditable` only within the Records tab list.

**FR-2: Edit Record Popup**
Create `EditRecordPopup` in `lib/components/popups/`.
- Initial values must match the current record.
- Fields: Amount (Input), Type (Income/Expense Toggle), Money Source (Selector), Category (Selector), Description (Input).
- Validate that amount is positive and name is not empty.

**FR-3: Database Refactor**
- Rename table `record` to `Record`.
- Rename/Replace column `created_at` to `last_updated` (integer timestamp).
- Update `Record` model and `RecordRepository` queries.
- Increment DB version to trigger a fresh start (`_onCreate`).

**FR-4: Data Integrity**
Ensure `RecordRepository.updateRecord` correctly handles balance deltas for both the source and the total.

### Non-Functional Requirements
**NFR-1: UI Consistency**
Match the established dark theme and border radius patterns (28px for popup, 12px for inputs).

## Success Criteria
- Users can successfully edit a record in under 20 seconds.
- Database correctly reflects changes in both the `Record` table and the `MoneySource` balances.

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| --- | --- | --- | --- |
| Balance Drift | High | Low | Use atomic database transactions for updates. |
| Breaking Existing Data | Medium | N/A | User explicitly requested a "fresh start" (no migration). |

## Constraints & Assumptions
- **Constraint:** Use `fvm` for all commands.
- **Assumption:** No migration is needed as per user request.

## Out of Scope
- Editing records from the Chat tab.
- Bulk editing of records.
- Deleting records from the Edit popup (already handled via long-press or separate flow).

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4]
  nice_to_have: []
  nfr: [NFR-1]
scale: medium
discovery_mode: express
validation_status: pending
last_validated: null
