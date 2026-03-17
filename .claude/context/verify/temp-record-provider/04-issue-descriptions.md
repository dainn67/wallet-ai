<!-- Source: GitHub Issues API | Collected: 2026-03-17T07:19:03Z | Epic: record-provider -->

# Issue Descriptions

## Issue #29: Epic: record-provider


# Epic: record-provider

## Overview
We will implement a `RecordProvider` using the `ChangeNotifier` pattern to manage the reactive state of financial records and money sources. The core architectural challenge is syncing this state with the `RecordRepository` (SQLite) and ensuring that updates from the `ChatProvider` (AI parsing) are reflected immediately in the UI. We'll use `ChangeNotifierProxyProvider` to establish a dependency from `ChatProvider` to `RecordProvider`, allowing the former to trigger reloads in the latter upon successful data persistence.

## Architecture Decisions

### AD-1: ChangeNotifier with Repository Delegation
**Context:** We need a reactive layer over the existing `RecordRepository`.
**Decision:** Implement `RecordProvider` as a `ChangeNotifier` that holds in-memory lists of `Record` and `MoneySource`.
**Alternatives rejected:** Using `FutureProvider` or `StreamProvider` directly with SQLite. These are harder to manage for complex filtering and manual CRUD operations compared to a central `ChangeNotifier`.
**Trade-off:** In-memory state must be carefully synced with the database to avoid "stale" data, but it provides instant UI updates and easy filtering.
**Reversibility:** Easy - the logic remains encapsulated in the provider.

### AD-2: ProxyProvider for Cross-Provider Sync
**Context:** `ChatProvider` saves records to the database, but `RecordProvider` needs to know when this happens to refresh its state.
**Decision:** Use `ChangeNotifierProxyProvider<ChatProvider, RecordProvider>` in `main.dart`. The `update` method will be used to trigger a `loadAll()` in `RecordProvider` when `ChatProvider` indicates a change (e.g., via a simple counter or timestamp).
**Alternatives rejected:** Event bus, global static listeners, or passing `RecordProvider` into `ChatProvider` constructor (circular dependency risk).
**Trade-off:** Adds a dependency between providers in the widget tree, but is the idiomatic `provider` way to handle cross-state updates.
**Reversibility:** Moderate - requires refactoring `main.dart` provider setup.

## Technical Approach

### lib/providers/record_provider.dart
- Create `RecordProvider` class extending `ChangeNotifier`.
- State: `List<Record> _records`, `List<MoneySource> _moneySources`, `bool _isLoading`.
- Methods: `loadAll()`, `createRecord()`, `updateRecord()`, `deleteRecord()`, etc.
- Logic: All CRUD methods call `RecordRepository` first, then update local state and `notifyListeners()`.
- Filtering: Getters for `filteredRecords` based on private filter state (sourceId, type, dates).

### main.dart Integration
- Wrap `MultiProvider` with `ChangeNotifierProxyProvider`.
- Ensure `RecordProvider` is initialized and performs an initial `loadAll()`.

## Traceability Matrix
| PRD Requirement        | Epic Coverage                  | Task(s) | Verification                       |
| ---------------------- | ------------------------------ | ------- | ---------------------------------- |
| FR-1: Load & Store     | `RecordProvider.loadAll()`     | T1      | Unit test for state init           |
| FR-2: Reactive Updates | `ProxyProvider` in `main.dart` | T4      | Manual test with Chat AI           |
| FR-3: Filtering Logic  | `RecordProvider` getters       | T2      | Unit test for filter logic         |
| FR-4: CRUD Delegation  | `RecordProvider` CRUD methods  | T3      | Unit test + Manual check           |
| FR-5: Loading State    | `_isLoading` flag              | T1, T3  | UI indicator check                 |
| NFR-1: Performance     | In-memory filtering            | T2      | Performance profile (> 1k records) |
| NFR-2: Consistency     | Write-then-Update pattern      | T3      | DB vs State comparison             |

## Implementation Strategy
### Phase 1: Foundation
Implement the basic `RecordProvider` with state management and database loading.
- Exit criterion: `RecordProvider` can fetch and store data from `RecordRepository`.

### Phase 2: Core
Implement CRUD delegation, filtering logic, and `ChatProvider` integration.
- Exit criterion: `RecordProvider` updates reactively when records are added via AI or manually.

### Phase 3: Polish
Add loading states, error handling, and unit tests.
- Exit criterion: Full test coverage and smooth UI integration.

## Task Breakdown

##### T1: Scaffold RecordProvider & Initial Load
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Depends:** — | **Complexity:** simple
- **What:** Create `lib/providers/record_provider.dart`. Implement `_records`, `_moneySources`, and `loadAll()` method using `RecordRepository`. Add `isLoading` flag management.
- **Key files:** `lib/providers/record_provider.dart`, `lib/repositories/record_repository.dart`
- **PRD requirements:** FR-1, FR-5
- **Key risk:** Slow initial load if database is large (not expected for MVP).

##### T2: Filtering & Sorting Implementation
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1 | **Complexity:** simple
- **What:** Add filter state (date range, moneySourceId, type) to `RecordProvider`. Implement a `filteredRecords` getter that applies these filters in-memory.
- **Key files:** `lib/providers/record_provider.dart`
- **PRD requirements:** FR-3, NFR-1
- **Key risk:** Complex date filtering edge cases (timezones).

##### T3: CRUD Delegation & State Sync
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Implement `createRecord`, `updateRecord`, `deleteRecord`, and equivalent `MoneySource` methods. Ensure they call `RecordRepository` and then update the local list before `notifyListeners()`.
- **Key files:** `lib/providers/record_provider.dart`
- **PRD requirements:** FR-4, NFR-2
- **Key risk:** Ensuring state and DB don't desync on partial failures.

##### T4: MultiProvider & ProxyProvider Setup
- **Phase:** 2 | **Parallel:** no | **Est:** 1d | **Depends:** T3 | **Complexity:** moderate
- **What:** Update `lib/main.dart` to include `RecordProvider` in the `MultiProvider` list. Use `ChangeNotifierProxyProvider` to link `ChatProvider` and `RecordProvider`. Add a `lastUpdate` timestamp or version to `ChatProvider` to trigger the proxy refresh.
- **Key files:** `lib/main.dart`, `lib/providers/chat_provider.dart`
- **PRD requirements:** FR-2
- **Key risk:** Infinite loop if `RecordProvider` update accidentally triggers `ChatProvider`.

##### T5: Validation & Unit Testing
- **Phase:** 3 | **Parallel:** yes | **Est:** 1d | **Depends:** T4 | **Complexity:** simple
- **What:** Write unit tests in `test/providers/record_provider_test.dart` using `mocktail` to verify loading, filtering, and CRUD state transitions.
- **Key files:** `test/providers/record_provider_test.dart`
- **PRD requirements:** All MUST requirements
- **Key risk:** Mocking SQLite (RecordRepository) correctly in the provider test.

## Risks & Mitigations
| Risk                | Severity | Likelihood | Impact                  | Mitigation                                                                                             |
| ------------------- | -------- | ---------- | ----------------------- | ------------------------------------------------------------------------------------------------------ |
| Circular Dependency | High     | Medium     | App crash/infinite loop | Ensure unidirectional data flow: Chat -> DB -> RecordProvider.                                         |
| Memory Bloat        | Low      | Low        | Slow performance        | Monitor record count; implement pagination if > 2000 records.                                          |
| UI Jitter           | Medium   | Low        | Bad UX                  | Use `Selector` or `context.select` in UI to only rebuild when relevant parts of RecordProvider change. |

## Dependencies
- `RecordRepository` (lib/repositories/record_repository.dart) - Stable
- `ChatProvider` (lib/providers/chat_provider.dart) - Requires update to expose sync trigger

## Success Criteria (Technical)
| PRD Criterion       | Technical Metric  | Target        | How to Measure                              |
| ------------------- | ----------------- | ------------- | ------------------------------------------- |
| US-1: Reactive List | UI Rebuild Delay  | < 500ms       | Performance overlay / Profiler              |
| US-2: Filtering     | Logic correctness | 100%          | Unit tests with various filter combinations |
| US-3: Loading       | Flag toggle       | Boolean state | Verify `isLoading` is true during DB calls  |

## Estimated Effort
- **Total Estimate:** 5 days
- **Critical Path:** T1 -> T3 -> T4
- **Phases:** 3 (Foundation, Core, Polish)

## Deferred / Follow-up
- `NTH-1: In-Memory Search` — Deferred to keep implementation simple and focused on reactive sync.
- Pagination — Out of scope per PRD.



---

## Issue #30: Scaffold RecordProvider & Initial Load


# Task: Scaffold RecordProvider & Initial Load

## Context
Create the reactive state management layer for records and money sources, enabling the UI to fetch and display data from the SQLite database.

## Description
Implement the `RecordProvider` class as a `ChangeNotifier`. This provider will hold the in-memory state of all `Record` and `MoneySource` objects fetched from the `RecordRepository`. It must handle its own loading state and provide a `loadAll()` method to refresh data from the database.

## Acceptance Criteria
- [ ] **FR-1 / Happy path:** `RecordProvider.loadAll()` successfully fetches records and money sources and stores them in `_records` and `_moneySources`.
- [ ] **FR-5 / Loading:** `isLoading` is set to `true` during the database fetch and `false` after completion, notifying listeners each time.
- [ ] **Integration:** `RecordProvider` is exported from `lib/providers/providers.dart`.

## Implementation Steps

### Step 1: Create `lib/providers/record_provider.dart`
- Define `RecordProvider` class extending `ChangeNotifier`.
- Add private fields:
  - `List<Record> _records = []`
  - `List<MoneySource> _moneySources = []`
  - `bool _isLoading = false`
- Add public getters for these fields.
- Implement `loadAll()` async method:
  - Set `_isLoading = true` and `notifyListeners()`.
  - Call `RecordRepository().getAllRecords()` and `RecordRepository().getAllMoneySources()`.
  - Update `_records` and `_moneySources`.
  - Set `_isLoading = false` and `notifyListeners()`.
- Error handling: Catch exceptions, log to debug, set `_isLoading = false`, and notify listeners.

### Step 2: Export in `lib/providers/providers.dart`
- Add `export 'record_provider.dart';` to the barrel file.

## Technical Details
- **Approach:** Follow AD-1 from the epic (ChangeNotifier with Repository Delegation).
- **Files to create/modify:**
  - `lib/providers/record_provider.dart`: New provider implementation.
  - `lib/providers/providers.dart`: Barrel file update.
- **Patterns to follow:** Reference `lib/providers/chat_provider.dart` for loading state pattern.
- **Edge cases:** Handle empty database returns gracefully (initialize with empty lists).

## Tests to Write

### Unit Tests
- `test/providers/record_provider_test.dart`
  - Test: `loadAll()` sets `isLoading` to true then false.
  - Test: `loadAll()` populates `records` and `moneySources` from repository.

## Verification Checklist
- [ ] Build succeeds with the new provider file.
- [ ] `RecordProvider` can be instantiated in a test or `main.dart`.
- [ ] `fvm flutter test test/providers/record_provider_test.dart` passes.

## Dependencies
- **Blocked by:** None
- **Blocks:** 010, 011
- **External:** `RecordRepository` (existing)

---

## Issue #31: Filtering & Sorting Implementation


# Task: Filtering & Sorting Implementation

## Context
Provide the UI with a simple API to filter and sort records in memory for high performance.

## Description
Extend `RecordProvider` with state variables for filtering criteria and implement a `filteredRecords` getter. This logic will be handled entirely in memory to ensure UI responsiveness when applying filters.

## Acceptance Criteria
- [ ] **FR-3 / Happy path:** `RecordProvider.filteredRecords` returns records matching the current `moneySourceId`, `type`, and `dateRange` filters.
- [ ] **FR-3 / Reset:** Filters can be cleared, returning all records.
- [ ] **NFR-1 / Performance:** Filtering 1,000+ records in memory should be instantaneous (< 16ms).

## Implementation Steps

### Step 1: Add Filter State to `RecordProvider`
- In `lib/providers/record_provider.dart`, add:
  - `int? _selectedSourceId`
  - `String? _selectedType` (income/expense)
  - `DateTimeRange? _selectedDateRange`
- Implement setters for these that call `notifyListeners()`.
- Add a `clearFilters()` method.

### Step 2: Implement `filteredRecords` Getter
- Add a getter `List<Record> get filteredRecords`:
  - Starts with `_records`.
  - Applies `_selectedSourceId` filter if non-null.
  - Applies `_selectedType` filter if non-null.
  - Applies `_selectedDateRange` filter if non-null (compare `record.date` or similar if exists).
  - Returns the resulting list.
- If `Record` model lacks a `date`, use `recordId` (descending) as a default sort order.

## Interface Contract

### Receives from T001:
- File: `lib/providers/record_provider.dart`
  - Base class and `_records` list.

## Technical Details
- **Approach:** Perform all filtering in memory using Dart's `List.where()` and `toList()`.
- **Files to modify:** `lib/providers/record_provider.dart`.
- **Patterns to follow:** Functional programming style with `.where()` chain.
- **Edge cases:** Handle records with null/missing dates if they occur. Ensure case-insensitive matching for types.

## Tests to Write

### Unit Tests
- `test/providers/record_provider_test.dart`
  - Test: Filtering by moneySourceId returns correct records.
  - Test: Filtering by type (income/expense) returns correct records.
  - Test: Clearing filters returns all records.

## Verification Checklist
- [ ] Unit tests for filtering pass.
- [ ] UI can successfully apply and remove filters via the provider.

## Dependencies
- **Blocked by:** 001
- **Blocks:** 090
- **External:** None

---

## Issue #32: CRUD Delegation & State Sync


# Task: CRUD Delegation & State Sync

## Context
Expose reactive methods for modifying records and money sources, ensuring changes are persisted to the database and correctly reflected in the UI.

## Description
Implement wrapper methods in `RecordProvider` for `RecordRepository`'s CRUD operations. Each method will first perform the database operation, then update the provider's in-memory list and notify listeners to ensure a reactive UI.

## Acceptance Criteria
- [ ] **FR-4 / Create:** `createRecord(record)` saves to SQLite and adds to `_records`.
- [ ] **FR-4 / Update:** `updateRecord(record)` updates SQLite and modifies the corresponding item in `_records`.
- [ ] **FR-4 / Delete:** `deleteRecord(id)` deletes from SQLite and removes from `_records`.
- [ ] **NFR-2 / Consistency:** The provider's `_records` and `_moneySources` lists accurately reflect the database content after any modification.

## Implementation Steps

### Step 1: Implement Record CRUD Methods
- In `lib/providers/record_provider.dart`, add:
  - `Future<void> addRecord(Record record)`: Calls `repo.createRecord`, gets new ID, adds `record.copyWith(recordId: id)` to `_records`, and calls `notifyListeners()`.
  - `Future<void> updateRecord(Record record)`: Calls `repo.updateRecord`, replaces record in `_records`, and calls `notifyListeners()`.
  - `Future<void> deleteRecord(int id)`: Calls `repo.deleteRecord`, removes record from `_records` by ID, and calls `notifyListeners()`.
- Error handling: Ensure methods set `isLoading = true` then `false`, and log errors. Consider reloading all data from DB on complex update failures to ensure consistency.

### Step 2: Implement MoneySource CRUD Methods
- Implement equivalent `addMoneySource`, `updateMoneySource`, and `deleteMoneySource` methods.

## Interface Contract

### Receives from T001:
- File: `lib/providers/record_provider.dart`
  - Base class and state lists.

### Produces for T020:
- File: `lib/providers/record_provider.dart`
  - Methods to modify and refresh the state.

## Technical Details
- **Approach:** Write-to-DB then Update-State pattern (AD-1).
- **Files to modify:** `lib/providers/record_provider.dart`.
- **Patterns to follow:** Reference `lib/providers/chat_provider.dart` for async method patterns.
- **Edge cases:** Handle foreign key constraint violations during deletion (e.g., deleting a money source with existing records).

## Tests to Write

### Unit Tests
- `test/providers/record_provider_test.dart`
  - Test: `addRecord` adds to the internal list and calls repository.
  - Test: `deleteRecord` removes from the internal list and calls repository.
  - Test: `updateRecord` updates the internal list item.

## Verification Checklist
- [ ] CRUD operations correctly modify the in-memory state.
- [ ] SQLite database shows corresponding changes after each provider call.

## Dependencies
- **Blocked by:** 001
- **Blocks:** 020, 090
- **External:** None

---

## Issue #33: MultiProvider & ProxyProvider Setup


# Task: MultiProvider & ProxyProvider Setup

## Context
Link `ChatProvider` and `RecordProvider` so the UI automatically updates when the AI assistant parses and saves new records to the database.

## Description
Modify `lib/main.dart` to include `RecordProvider` in the `MultiProvider` list. Use `ChangeNotifierProxyProvider` to allow `RecordProvider` to react to state changes in `ChatProvider`. We will add a sync trigger (e.g., a simple counter or last update timestamp) to `ChatProvider` that `RecordProvider` can watch to know when to perform a `loadAll()`.

## Acceptance Criteria
- [ ] **FR-2 / Happy path:** When `ChatProvider` completes its AI parsing and saves records, `RecordProvider.loadAll()` is automatically triggered.
- [ ] **FR-2 / Initial Load:** `RecordProvider` loads initial data from the database on app startup.
- [ ] **Performance:** Rebuilds are efficient and do not cause infinite loops.

## Implementation Steps

### Step 1: Add Sync Trigger to `ChatProvider`
- In `lib/providers/chat_provider.dart`, add:
  - `int _dbUpdateVersion = 0`
  - `int get dbUpdateVersion => _dbUpdateVersion`
- Increment `_dbUpdateVersion` and call `notifyListeners()` in the `onDone` block of `sendMessage` after the AI records are successfully saved to the repository.

### Step 2: Update `lib/main.dart` with `ProxyProvider`
- Modify the `MultiProvider` in `MyApp.build`:
  - Keep `ChatProvider` as a `ChangeNotifierProvider`.
  - Add `ChangeNotifierProxyProvider<ChatProvider, RecordProvider>` for `RecordProvider`.
  - In the `create` method, initialize `RecordProvider` and call its initial `loadAll()`.
  - In the `update` method, track the `dbUpdateVersion` from the received `ChatProvider`. If it has changed, call `recordProvider.loadAll()`.

## Interface Contract

### Receives from T011:
- File: `lib/providers/record_provider.dart`
  - `RecordProvider` class and `loadAll()` method.

### Produces for T090:
- File: `lib/main.dart`
  - Integrated provider tree.

## Technical Details
- **Approach:** AD-2 (ProxyProvider for Cross-Provider Sync).
- **Files to modify:** `lib/main.dart`, `lib/providers/chat_provider.dart`.
- **Patterns to follow:** Standard `ProxyProvider` pattern. See AD-2 in the epic.
- **Edge cases:** Ensure `RecordProvider` correctly handles multiple rapid updates from `ChatProvider` without redundant/overlapping DB queries.

## Tests to Write

### Integration Tests
- `test/providers/provider_integration_test.dart`
  - Test: Incrementing `ChatProvider.dbUpdateVersion` triggers `RecordProvider.loadAll()` (verify using a mock `RecordRepository`).

## Verification Checklist
- [ ] App starts and loads records correctly.
- [ ] After an AI chat adds records, the record list (if observed) updates without a manual refresh.
- [ ] No infinite build loops occur in the provider tree.

## Dependencies
- **Blocked by:** 011
- **Blocks:** 090
- **External:** None

---

## Issue #34: Integration verification & cleanup


# Task: Integration verification & cleanup

## Context
Final quality gate before epic completion. Ensures all tasks integrate correctly and all PRD requirements for `record-provider` are met.

## Description
Perform a comprehensive verification of the new reactive record management system. This includes running all unit and integration tests, performing manual end-to-end tests with the AI assistant, and ensuring that no performance regressions or circular dependencies were introduced.

## Acceptance Criteria
- [ ] All tasks in the `record-provider` epic are status: done.
- [ ] **FR-1, FR-5:** Initial load and loading states work correctly.
- [ ] **FR-3, NFR-1:** Filtering is fast and accurate.
- [ ] **FR-4, NFR-2:** Manual CRUD operations are correctly persisted and reactive.
- [ ] **FR-2:** AI-generated records trigger automatic reloads in `RecordProvider`.
- [ ] **Regressions:** No existing app functionality (chat, storage, etc.) is broken.

## Implementation Steps

### Step 1: Run Full Test Suite
- Execute `fvm flutter test` and ensure all tests pass (existing + new).

### Step 2: Manual Verification with AI
- Use the chat screen to add records via natural language.
- Verify that the `RecordProvider`'s state (which would be used by a UI list or balance widget) is updated automatically without manual refresh.
- Test CRUD operations manually (if possible via UI or a temporary debug widget).

### Step 3: Cleanup
- Remove any temporary debug logs or widgets created during development.
- Final code review for consistency with project architecture.

## Technical Details
- **Verification strategy:** Combine automated unit tests with manual end-to-end flows.
- **Key risks to verify:** Circular dependencies in the provider tree, infinite rebuild loops, and database sync issues.

## Verification Checklist
- [ ] `fvm flutter test` results are clean.
- [ ] AI-generated record sync is verified manually.
- [ ] UI performance is smooth with 60fps scrolling (if applicable).
- [ ] Provider tree is correctly configured and efficient.

## Dependencies
- **Blocked by:** 010, 011, 020
- **Blocks:** None
- **External:** None

---

