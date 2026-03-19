---
name: add-category-table
description: Implement a structured categorization system for financial records by adding a Category table and updating the Record model and UI.
status: complete
priority: P1
scale: medium
created: 2026-03-18T12:30:00Z
updated: null
---

# PRD: add-category-table

## Executive Summary
This epic introduces a dedicated `Category` table to the SQLite database, allowing users to organize their income and expense records more effectively. We will refactor the existing `Record` model and database schema to include a `categoryId` foreign key, seed the database with common categories (e.g., Food, Transport, Salary), and update the `RecordProvider` to fetch and cache these categories for optimal performance. The `RecordsTab` UI will also be updated to display category information alongside the existing record details.

## Problem Statement
The current application handles financial records without any formal categorization. Users can only rely on the `description` field to track the nature of their transactions, which makes it impossible to aggregate spending patterns or provide detailed financial summaries. A structured category system is a foundational requirement for any personal finance application.

## Target Users
| Role | Context | Primary Need | Pain Level |
| ---- | ------- | ------------ | ---------- |
| End-User | Viewing transaction history | To quickly see what each expense was for (e.g., "Was this 50k for lunch or coffee?"). | High |
| Developer | Extending data insights | A structured schema to build future features like "Spending by Category" charts. | Medium |

## User Stories
**US-1: Structured Categorization**
As a user, I want my financial records to be linked to specific categories so that I can organize my spending and income more logically.

Acceptance Criteria:
- [ ] A new `Category` table exists in SQLite.
- [ ] The `Record` table includes a `categoryId` field.
- [ ] The database is seeded with "Food", "Transport", "Entertainment", "Salary", "Rent", "Health", and "Uncategorized".

**US-2: Performant Data Access**
As a developer, I want category data to be joined in queries and cached in the provider so that the UI remains fast and responsive.

Acceptance Criteria:
- [ ] `RecordRepository.getAllRecords()` uses a SQL `JOIN` to fetch category names.
- [ ] `RecordProvider` maintains a cache of categories for fast lookups.

**US-3: Visual Clarity**
As a user, I want to see the category name on each record in the transaction list so that I can understand my spending at a glance.

Acceptance Criteria:
- [ ] `RecordsTab` displays the category name on each transaction card.
- [ ] The UI remains clean and uncluttered even with the additional information.

## Requirements
### Functional Requirements (MUST)

**FR-1: Database Schema Refactor**
Create the `Category` table and update the `record` table to include `categoryId` as a foreign key. Since no release has occurred, a fresh `_onCreate` refactor is acceptable.

**FR-2: Category Seeding**
Implement a seeding script within the database initialization logic to add standard categories, ensuring "Uncategorized" is the default.

**FR-3: Model & Repository Updates**
Update the `Record` model to include `categoryId` and `categoryName` (optional/nullable for JOIN support). Update `RecordRepository` to support the new schema.

**FR-4: Provider Caching & Join Logic**
Modify `RecordProvider` to fetch records using a SQL JOIN. Implement a `Map<int, Category>` cache in the provider to store category metadata.

**FR-5: UI Integration**
Update the `RecordsTab` transaction list to display the category name on each record item.

### Functional Requirements (NICE-TO-HAVE)
- N/A for this foundational refactor.

### Non-Functional Requirements
**NFR-1: Performance**
JOIN queries and provider-level caching must ensure that scrolling through the records list remains smooth (60fps).

**NFR-2: Data Integrity**
Foreign key constraints must be enforced to prevent records from pointing to non-existent categories.

## Success Criteria
- [ ] Fresh database initialization creates both `MoneySource` and `Category` tables.
- [ ] `RecordsTab` successfully displays seeded category names for all records.
- [ ] `fvm flutter test` passes for modified repositories and providers.

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| ---- | -------- | ---------- | ---------- |
| Database Lock/Crash | Low | Low | Perform all schema changes within a fresh `_onCreate` context as requested. |
| UI Overcrowding | Medium | Medium | Use a clean, compact layout for category/source display (e.g., "Category • Source"). |

## Constraints & Assumptions
- **Constraints:** Must use SQL `JOIN` for fetching and Provider for caching.
- **Assumptions:** Users are okay with a fresh start (data wipe) for this refactor.

## Out of Scope
- Building a UI for users to add/edit/delete categories.
- Implementing AI auto-categorization based on descriptions.

## Dependencies
- None.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: []
  nfr: [NFR-1, NFR-2]
scale: medium
discovery_mode: full
validation_status: pending
last_validated: null
