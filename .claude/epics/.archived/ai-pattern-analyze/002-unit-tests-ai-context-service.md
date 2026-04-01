---
name: Unit tests for AiContextService
status: closed
created: 2026-04-01T07:02:07Z
updated: 2026-04-01T07:17:15Z
complexity: moderate
recommended_model: sonnet
phase: 1
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/152"
depends_on:
  - "001"
parallel: false
conflicts_with: []
files:
  - test/services/ai_context_service_test.dart
prd_requirements:
  - FR-1
  - FR-2
  - FR-3
  - FR-4
  - FR-5
  - FR-6
  - FR-7
---

# T2: Unit tests for AiContextService

## Context

`AiContextService` transforms raw records into structured AI snapshots. Tests must verify correct date filtering (90d/24h windows), record transformation (names, time-of-day buckets), summary aggregation (expense-only for by_category/by_time_of_day/by_money_source), empty-state handling, and client metadata. This ensures the data contract with the Python AI server is correct.

## Description

Create comprehensive unit tests for `AiContextService` using mock `RecordRepository` via `setMockInstance()`. The test file covers 7 groups corresponding to all 7 FR requirements. Uses `mocktail` for mocking (already in dev_dependencies). Mock data must include realistic `categoryName` values in "Parent - Sub" format to validate the extraction logic.

## Acceptance Criteria

- [ ] **FR-1 / Singleton:** Test that `AiContextService()` returns same instance; `setMockInstance()` overrides
- [ ] **FR-2 / Category extraction:** Test "Food - Dining Out"→"Dining Out", "Transport"→"Transport", null→"Uncategorized"
- [ ] **FR-3 / Time boundaries:** Test all 8 boundaries: 04:59→Night, 05:00→Morning, 10:59→Morning, 11:00→Afternoon, 16:59→Afternoon, 17:00→Evening, 21:59→Evening, 22:00→Night
- [ ] **FR-4 / 90-day window:** Records at 89d, 90d, 91d ago → only ≤90d included; `summary.period_days = 90`
- [ ] **FR-5 / 24h window:** Records at 12h, 25h, 5d ago → only 12h record in `records`; summary covers 30d
- [ ] **FR-5 / Empty window:** No records in window → `records: []`, totals = 0
- [ ] **FR-6 / Summary aggregation:** Mixed income+expense → `by_category`/`by_time_of_day`/`by_money_source` only count expense; `total_income` and `total_expense` correct
- [ ] **FR-7 / Metadata:** `sync_type`, `current_time`, `timezone`, `language`, `currency` present with correct types
- [ ] **jsonEncode:** Snapshot output passes `jsonEncode()` without error

## Interface Contract

### Receives from T1 (001-create-ai-context-service):
- File: `lib/services/ai_context_service.dart`
  - Class: `AiContextService` singleton
  - Method: `buildSnapshot({bool isInitial = false})` → `Future<Map<String, dynamic>>`
  - Test hook: `AiContextService.setMockInstance(AiContextService? instance)` — not needed for testing the service itself
- File: `lib/repositories/record_repository.dart`
  - Test hook: `RecordRepository.setMockInstance(RecordRepository? instance)` — used to inject mock data
  - Method to mock: `getAllRecords()` → `Future<List<Record>>`

## Implementation Steps

### Step 1: Create test file with mock setup

- Create `test/services/ai_context_service_test.dart`
- Import: `package:flutter_test/flutter_test.dart`, `package:mocktail/mocktail.dart`, `dart:convert` (for `jsonEncode`), service and model imports
- Create mock class: `class MockRecordRepository extends Mock implements RecordRepository {}`
- In `setUp()`: create `MockRecordRepository`, call `RecordRepository.setMockInstance(mockRepo)`
- In `tearDown()`: call `RecordRepository.setMockInstance(null)`, `AiContextService.setMockInstance(null)`

### Step 2: Helper to create test records

- Create helper function `Record makeRecord({...})` with defaults:
  ```dart
  Record makeRecord({
    int recordId = 1,
    int? lastUpdated,
    int moneySourceId = 1,
    int categoryId = 2,
    String? categoryName = 'Food - Dining Out',
    String? sourceName = 'Wallet',
    double amount = 50000,
    String currency = 'VND',
    String description = 'Test record',
    String type = 'expense',
  })
  ```
- `lastUpdated` defaults to `DateTime.now().millisecondsSinceEpoch`

### Step 3: Write test groups

**Group 1: Singleton (FR-1)**
- Test: `AiContextService()` returns same instance (identical check)

**Group 2: Category name extraction (FR-2)**
- Mock `getAllRecords()` → 3 records with categoryName: "Food - Dining Out", "Transport", null
- Call `buildSnapshot()`, verify category values: "Dining Out", "Transport", "Uncategorized"

**Group 3: Time-of-day bucketing (FR-3)**
- Create 8 records at boundary times: 04:59, 05:00, 10:59, 11:00, 16:59, 17:00, 21:59, 22:00
- Call `buildSnapshot()`, verify each record's `time_of_day` field
- To create records at specific times: use `DateTime(2026, 4, 1, hour, minute).millisecondsSinceEpoch`

**Group 4: Initial 90-day window (FR-4)**
- Create records at: 89 days ago, 90 days ago, 91 days ago
- Call `buildSnapshot(isInitial: true)`
- Verify: 89d and 90d records in `records`, 91d excluded
- Verify: `summary['period_days'] == 90`

**Group 5: Daily 24h + 30d summary (FR-5)**
- Create records at: 12 hours ago, 25 hours ago, 5 days ago
- Call `buildSnapshot(isInitial: false)`
- Verify: only 12h record in `records` list
- Verify: `summary['period_days'] == 30`
- Verify: summary totals include 12h + 5d records (both within 30d)

**Group 6: Empty dataset (FR-5 edge)**
- Mock `getAllRecords()` → empty list
- Call `buildSnapshot()` for both initial and daily
- Verify: `records` is empty list, `summary['total_income'] == 0`, `summary['total_expense'] == 0`

**Group 7: Summary aggregation (FR-6)**
- Create 4 records: 2 expense (Food/50k + Transport/20k), 1 income (Salary/500k), 1 expense (Food/30k different source)
- Call `buildSnapshot()`
- Verify: `total_income == 500000`, `total_expense == 100000`
- Verify: `by_category == {'Dining Out': 80000, 'Transport': 20000}` (expense only, sub-cat names)
- Verify: `by_money_source` sums expense only
- Verify: `by_time_of_day` sums expense only

**Group 8: Client metadata (FR-7)**
- Mock StorageService to return specific language/currency
- Call `buildSnapshot()` and `buildSnapshot(isInitial: true)`
- Verify: `sync_type == "daily"` / `"initial"`
- Verify: `current_time` is valid ISO 8601 string
- Verify: `timezone`, `language`, `currency` present

**Group 9: jsonEncode validation**
- Call `buildSnapshot()`, pass to `jsonEncode()` → no throw

## Technical Details

- **Approach:** Mock `RecordRepository` at singleton level using `setMockInstance()` — same pattern as `ChatApiService` tests
- **Patterns to follow:** See `test/providers/record_provider_test.dart` for mock setup examples; see `test/services/chat_api_service_formatting_test.dart` for service test structure
- **Edge cases:**
  - Records at exact boundary timestamps (90d, 24h cutoff) — test inclusive behavior
  - Mixed income/expense in same category — income should NOT appear in `by_category`
  - `sourceName = null` in record → should map to "Unknown" in snapshot

## Verification Checklist

- [ ] All tests pass: `cd /Users/nguyendai/StudioProjects/wallet-ai && flutter test test/services/ai_context_service_test.dart`
- [ ] No regressions: `flutter test`
- [ ] Test coverage: every FR acceptance criterion has ≥1 corresponding test

## Dependencies

- **Blocked by:** T1 (001-create-ai-context-service)
- **Blocks:** None
- **External:** `mocktail` package (already in dev_dependencies)
