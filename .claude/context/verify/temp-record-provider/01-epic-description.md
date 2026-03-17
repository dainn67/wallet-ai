<!-- Source: GitHub Issue #29 | Collected: 2026-03-17T07:19:03Z | Epic: record-provider -->

# Epic: Epic: record-provider


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


