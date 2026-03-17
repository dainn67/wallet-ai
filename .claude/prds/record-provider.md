---
name: record-provider
description: Reactive state management layer for database-persisted records and money sources.
status: backlog
priority: P1
scale: medium
created: 2026-03-17T06:27:40Z
updated: null
---

# PRD: record-provider

## Executive Summary
We're implementing `RecordProvider` to bridge the gap between our SQLite storage (`RecordRepository`) and the Flutter UI. Currently, the app parses and saves data via the `ChatProvider`, but there's no reactive mechanism to notify the UI when records or money sources are updated. This provider will manage the state of all records and money sources, provide filtering/sorting logic, and use `ChangeNotifierProxyProvider` to automatically refresh when the `ChatProvider` saves new AI-generated data.

## Problem Statement
The application's data layer (SQLite via `RecordRepository`) is decoupled from the UI's reactive state. When the AI assistant saves a new record, the UI does not automatically refresh to show the updated balance or the new transaction list. Developers currently have to manually trigger reloads or poll the database, which is inefficient and leads to a poor user experience where the app feels "stale" until a screen is manually refreshed.

## Target Users
- **End-User (Persona: "The Budgeter")**
  - **Context:** Looking at their transaction list after chatting with the AI.
  - **Primary Need:** See their new records and updated money source balances immediately without manual refreshes.
  - **Pain Level:** High (stale data leads to confusion about whether a transaction was actually saved).
- **App Developer (Persona: "The UI Builder")**
  - **Context:** Building the home screen and transaction filters.
  - **Primary Need:** A simple, reactive API (`context.watch<RecordProvider>()`) to access records and money sources.
  - **Pain Level:** Medium (currently requires repetitive boilerplate to fetch data from the repository).

## User Stories
**US-1: [Reactive List]**
As a Budgeter, I want to see my transaction list update automatically after I chat with the AI so that I can confirm my expenses were recorded correctly.
- [ ] UI reflects new records within 500ms of the database save.
- [ ] Balance of affected money sources updates automatically.

**US-2: [Filtering & Sorting]**
As a Budgeter, I want to filter my records by money source or date so that I can analyze my spending in specific categories.
- [ ] User can apply filters through the provider.
- [ ] Provider notifies listeners when filter criteria change.

**US-3: [Loading State]**
As a Budgeter, I want to see a loading indicator when the app is fetching many records so that I know the app is still responsive.
- [ ] `isLoading` boolean is exposed and correctly toggled during DB operations.

## Requirements

### Functional Requirements (MUST)

**FR-1: Load and Store Records & Money Sources**
The provider must fetch all records and money sources from `RecordRepository` on initialization and store them in memory.

Scenario: [Initialization]
- GIVEN the app is starting up
- WHEN `RecordProvider.init()` or first access occurs
- THEN call `RecordRepository.getAllRecords()` and `RecordRepository.getAllMoneySources()`
- AND store them in internal lists.

**FR-2: Reactive Updates (ProxyProvider Integration)**
Use `ChangeNotifierProxyProvider` to link `RecordProvider` with `ChatProvider`. When `ChatProvider` finishes saving AI records, it should trigger a reload in `RecordProvider`.

Scenario: [AI Save Notification]
- GIVEN the AI has just returned structured data
- WHEN `ChatProvider` finishes its `onDone` stream logic and saves to the repo
- THEN `RecordProvider` should be notified to reload its local state from the database.

**FR-3: Filtering & Sorting Logic**
Expose methods to filter records by `moneySourceId`, `type` (income/expense), and date range. The logic should be handled by the provider (delegating to repo where appropriate).

Scenario: [Filtering]
- GIVEN a list of 100 records
- WHEN a user selects a specific "Wallet" money source
- THEN the `filteredRecords` getter should only return records matching that source.

**FR-4: CRUD Delegation**
Provide methods to create, update, and delete records/money sources that call `RecordRepository` and then call `notifyListeners()`.

Scenario: [Manual Deletion]
- GIVEN a user deletes a record from the UI
- WHEN `RecordProvider.deleteRecord(id)` is called
- THEN call `RecordRepository.deleteRecord(id)`
- AND remove the record from the internal list
- AND notify listeners.

**FR-5: Loading State Management**
Maintain an `isLoading` flag to track active database operations.

Scenario: [Busy State]
- GIVEN a heavy database fetch is occurring
- WHEN the fetch starts
- THEN `isLoading` is set to true and listeners notified.
- WHEN the fetch ends
- THEN `isLoading` is set to false and listeners notified.

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: In-Memory Search**
Add a search getter that filters records by title/description in real-time without re-querying the database.
- Reason: Deferred to maintain focus on core reactive sync.

### Non-Functional Requirements

**NFR-1: Performance**
Filtering and sorting of up to 1,000 records in memory should take < 16ms to avoid frame drops (60fps).

**NFR-2: Consistency**
The provider's state MUST always match the database state after any write operation initiated through the provider.

## Success Criteria
- [ ] 100% of new records saved via AI chat are reflected in the UI without manual refresh.
- [ ] UI components using `context.watch<RecordProvider>()` rebuild only when relevant data changes.
- [ ] All `RecordRepository` functions are successfully wrapped and reactive.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| **Dependency Cycle** | High | Medium | Use `ChangeNotifierProxyProvider` carefully; ensure `ChatProvider` doesn't depend back on `RecordProvider` in a circular way. |
| **State Desync** | Medium | Low | Always reload state from `RecordRepository` after complex operations to ensure the "source of truth" remains the database. |
| **Performance with Large Data** | Low | Low | While out of scope for MVP, ensure filtering logic is efficient and consider pagination if record counts exceed 1,000. |

## Constraints & Assumptions
- **Constraint:** Must use `provider` package as per project standards.
- **Constraint:** Must use `fvm` for all development and testing.
- **Assumption:** `RecordRepository` is already stable and supports all necessary CRUD operations.

## Out of Scope
- Pagination (all records loaded at once for now).
- Complex analytics or graphing logic.
- Cloud sync (local SQLite only).

## Dependencies
- `RecordRepository` — Core Data Access — Resolved
- `ChatProvider` — Trigger for AI-driven updates — Pending integration
- `sqflite` — Database engine — Resolved

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2]
scale: medium
discovery_mode: full
validation_status: pending
last_validated: null
