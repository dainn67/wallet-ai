---
name: add-source
description: Add a button to the RecordsOverview component to create new Money Sources via a popup dialog.
status: complete
priority: P1
scale: small
created: 2026-03-22T00:00:00Z
updated: 2026-03-22T12:15:00Z
---

# PRD: add-source

## Executive Summary
We are adding a mechanism for users to create new financial sources (e.g., "Cash", "Bank", "Savings") directly from the Records tab. A new "+" button will be added to the "Sources" section in the `RecordsOverview` component, which will open a popup dialog to capture the source name and an initial balance. This feature improves the onboarding experience and allows users to flexibly manage multiple accounts.

## Problem Statement
Currently, the "Sources" section in the `RecordsOverview` box only displays existing sources. There is no user-facing UI to add new sources, forcing users to rely on pre-seeded data or manual database manipulation. This limits the app's utility for users with diverse financial accounts.

## Target Users
- **New Users:** Setting up their wallet and needing to define their actual accounts.
- **Existing Users:** Adding new bank accounts or physical wallets to their tracking.

## User Stories
**US-1: Create New Source**
As a user, I want to click a button in the sources section so that I can add a new account to track.

Acceptance Criteria:
- [ ] A "+" button is visible next to the "Sources" title.
- [ ] Clicking the button opens a popup dialog.
- [ ] The dialog contains fields for "Source Name" and "Initial Amount".
- [ ] Saving the dialog persists the new source to the database and updates the UI immediately.

## Requirements

### Functional Requirements (MUST)

**FR-1: Add Source Button**
Add an `IconButton` with a `+` icon in the `RecordsOverview` component, aligned trailing to the "Sources" text.

Scenario: User sees the add button
- GIVEN the Records tab is open
- WHEN the user looks at the `RecordsOverview` box
- THEN a "+" icon should be visible in the same row as the "Sources" title.

**FR-2: Add Source Popup**
Create a new component `AddSourcePopup` in `lib/components/popups/`. It should be a styled dialog following the app's dark aesthetic.

Scenario: User opens the popup
- GIVEN the user is on the Records tab
- WHEN the user taps the "+" button
- THEN a popup dialog appears with input fields for Name and Initial Amount.

**FR-3: Database Persistence**
Utilize `RecordRepository.createMoneySource` to save the new source.

Scenario: User saves a new source
- GIVEN the popup is open and valid data is entered
- WHEN the user taps "Save"
- THEN a new record is inserted into the `MoneySource` table
- AND the `RecordsOverview` UI refreshes to show the new source.

### Non-Functional Requirements
**NFR-1: UI Consistency**
The popup must use the established dark theme (colors like `0xFF0F172A`, `0xFF1E293B`) and consistent border radiuses (28px for containers, 12px for cards/inputs).

## Success Criteria
- Users can successfully add a new source in under 15 seconds.
- Added sources correctly display their name and initial balance in the `RecordsOverview` horizontal list.

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| --- | --- | --- | --- |
| Duplicate Source Names | Low | Medium | Add a simple check or handle unique constraint error from database. |

## Constraints & Assumptions
- **Constraint:** Use the existing `RecordRepository` for all database operations.
- **Assumption:** The `RecordsOverview` component is correctly wired to a provider that will notify listeners upon data changes.

## Out of Scope
- Deleting or renaming existing sources (to be handled in a separate "Manage Sources" feature).
- Multi-currency support for individual sources (defaults to system currency).

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3]
  nice_to_have: []
  nfr: [NFR-1]
scale: small
discovery_mode: express
validation_status: warning
last_validated: 2026-03-22T00:00:00Z
