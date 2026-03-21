---
name: add-record-timestamp
description: Add dd/mm/yyyy timestamp to record cards and group records by month in the list.
status: complete
priority: P1
scale: small
created: 2026-03-21T00:00:00Z
updated: 2026-03-21T09:50:09Z
---

# PRD: add-record-timestamp

## Executive Summary
This feature enhances the `RecordsTab` by displaying a `dd/mm/yyyy` timestamp on each record card and grouping the record list by month using visual dividers. This provides better temporal context and improves navigability for users reviewing their financial history.

## Problem Statement
Currently, users cannot see when a specific expense or income record was created within the `RecordWidget`. Additionally, the list of records in the `RecordsTab` is a continuous stream without any temporal grouping, making it difficult to find records from a specific month or understand the timeline of transactions at a glance.

## Target Users
*Note: Scale is SMALL; Target Users section skipped per rules/prd-quality.md.*

## User Stories
*Note: Scale is SMALL; User Stories section skipped per rules/prd-quality.md (Acceptance Criteria included in Requirements).*

## Requirements

### Functional Requirements (MUST)

**FR-1: Display Timestamp on Record Card**
Show the record's creation date in `dd/mm/yyyy` format at the corner of the `RecordWidget`.

Scenario: Happy Path
- GIVEN a record with a `createdAt` value (millisecondsSinceEpoch)
- WHEN the `RecordWidget` is rendered
- THEN the date is displayed in `dd/mm/yyyy` format (e.g., "21/03/2026") in a clean, subtle font at the bottom or top corner.

**FR-2: Group Records by Month in List**
Insert month/year dividers (e.g., "March 2026") between groups of records in the `RecordsTab`.

Scenario: Multiple Months
- GIVEN a list of records spanning multiple months (e.g., March and February)
- WHEN the `RecordsTab` is viewed
- THEN a divider with "March 2026" appears before March records, and "February 2026" appears before February records.

**FR-3: Verify `createdAt` Logic**
Ensure the `createdAt` field in the `Record` model is correctly populated during creation (from AI chat or manual entry) and persisted in SQLite.

Scenario: New Record Creation
- GIVEN a new record is created via `ChatProvider` or `RecordRepository`
- WHEN the record is saved
- THEN the `created_at` field in the database is set to the current time in milliseconds.

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Relative Dates for "Today" and "Yesterday"**
Display "Today" or "Yesterday" instead of the full date for very recent records in the grouping dividers.

### Non-Functional Requirements

**NFR-1: Performance**
Grouping logic in `RecordsTab` must not cause noticeable lag (scroll stutter) for lists up to 500 records.

## Success Criteria
- [ ] Record cards display a clearly legible date in `dd/mm/yyyy` format.
- [ ] The record list is visually segmented by month/year headers.
- [ ] All records show accurate dates based on their creation time.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| UI Clutter | Low | Medium | Use a small font size and subtle color for the timestamp; align it to a corner (e.g., bottom right). |

## Constraints & Assumptions
- **Assumption:** The `createdAt` field in the database currently stores milliseconds since epoch as intended.
- **Constraint:** Use existing `GoogleFonts.poppins` and established color palette.

## Out of Scope
- Displaying hours/minutes on the record card.
- User-configurable date formats.
- Filtering or searching records by date range (separate feature).

## Dependencies
- `intl` package (already in `pubspec.yaml` or to be added if needed for formatting).

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3]
  nice_to_have: [NTH-1]
  nfr: [NFR-1]
scale: small
discovery_mode: full
validation_status: pending
last_validated: null
completed: 2026-03-21T09:50:09Z
