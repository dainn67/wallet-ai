---
name: Create AiContextService with getAiContext()
status: closed
created: 2026-04-01T07:02:07Z
updated: 2026-04-01T07:15:04Z
complexity: moderate
recommended_model: sonnet
phase: 1
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/151"
depends_on: []
parallel: false
conflicts_with: []
files:
  - lib/services/ai_context_service.dart
  - lib/services/services.dart
prd_requirements:
  - FR-1
  - FR-2
  - FR-3
  - FR-4
  - FR-5
  - FR-6
  - FR-7
---

# T1: Create AiContextService with getAiContext()

## Context

The app needs a data transformation layer that converts raw SQLite records into a structured snapshot for server-side AI pattern analysis. `RecordRepository.getAllRecords()` already JOINs Category (with parent) and MoneySource names, so no new SQL queries are needed — the service only aggregates and transforms in-memory.

## Description

Create `AiContextService` as a singleton service in `lib/services/` following the same pattern as `ChatApiService`. The single public method `buildSnapshot({bool isInitial = false})` fetches all records, filters by time window, transforms each to a name-only map with time-of-day buckets, builds aggregated summary stats, and adds client metadata. Returns `Future<Map<String, dynamic>>` ready for `jsonEncode()`.

## Acceptance Criteria

- [ ] **FR-1 / Singleton:** `AiContextService()` returns same instance; `setMockInstance()` available for testing
- [ ] **FR-2 / Names only:** Records in snapshot use `description`, `category` (sub-category name), `money_source` (source name) — no database IDs
- [ ] **FR-2 / Sub-category extraction:** Record with `categoryName = "Food - Dining Out"` → `"category": "Dining Out"`; record with `categoryName = "Transport"` → `"category": "Transport"`; null categoryName → `"Uncategorized"`
- [ ] **FR-4 / Initial 90d:** `getAiContext(isInitial: true)` returns records from last 90 days by default; `summary.period_days = 90`
- [ ] **FR-5 / Daily 24h+30d:** `getAiContext()` returns records from last 24h (1 day) by default; summary covers 30 days; `summary.period_days = 30`
- [ ] **FR-5 / On-demand window:** `getAiContext(days: 7)` returns records from last 7 days; `summary` covers at least the record window or 30 days
- [ ] **FR-5 / Empty window:** If no records in window → `records: []`, `summary.total_income: 0`, `summary.total_expense: 0`
- [ ] **FR-6 / Summary:** `by_category`, `by_money_source` aggregate expense records only; `total_income` and `total_expense` computed correctly
- [ ] **FR-7 / Metadata:** `client_metadata` includes `sync_type`, `current_time` (UTC ISO 8601), `timezone`, `language`, `currency`
- [ ] **NFR-2 / No UI:** No `BuildContext`, `Widget`, or Flutter UI imports in the service

## Implementation Steps

### Step 1: Create `lib/services/ai_context_service.dart`

- Create singleton class matching `ChatApiService` pattern:
  ```dart
  class AiContextService {
    static final AiContextService _instance = AiContextService._internal();
    static AiContextService? _mockInstance;

    factory AiContextService() => _mockInstance ?? _instance;
    AiContextService._internal();

    @visibleForTesting
    static void setMockInstance(AiContextService? instance) {
      _mockInstance = instance;
    }
  }
  ```

- Add private helper `_extractCategoryName(String? categoryName)`:
  - If null → return "Uncategorized"
  - Split on " - ", return `parts.last`

- Add private helper `_recordToMap(Record record)`:
  - Returns `Map<String, dynamic>` with: `description`, `amount` (combined with currency, e.g. "15000VND"), `type`, `category` (via `_extractCategoryName`), `money_source` (from `sourceName ?? 'Unknown'`), `datetime` (local date `HH:mm d MMM yyyy` using `intl` package `DateFormat`)

- Add private helper `_buildSummary(List<Record> records, int periodDays)`:
  - Compute `total_income` (sum where type == 'income')
  - Compute `total_expense` (sum where type == 'expense')
  - Build `by_category`: filter expense records, group by `_extractCategoryName(record.categoryName)`, sum amounts
  - Build `by_money_source`: filter expense records, group by `record.sourceName ?? 'Unknown'`, sum amounts
  - Return map with all fields

- Implement `buildSnapshot({bool isInitial = false})`:
  1. Get `now = DateTime.now()`
  2. Compute `recordCutoff = isInitial ? now.subtract(Duration(days: 90)) : now.subtract(Duration(hours: 24))`
  3. Compute `summaryCutoff = isInitial ? recordCutoff : now.subtract(Duration(days: 30))`
  4. Call `RecordRepository().getAllRecords()` → `allRecords`
  5. Filter: `windowRecords = allRecords.where((r) => r.lastUpdated >= recordCutoff.millisecondsSinceEpoch).toList()`
  6. Filter: `summaryRecords = allRecords.where((r) => r.lastUpdated >= summaryCutoff.millisecondsSinceEpoch).toList()`
  7. Transform: `records = windowRecords.map(_recordToMap).toList()`
  8. Build: `summary = _buildSummary(summaryRecords, isInitial ? 90 : 30)`
  9. Build `client_metadata`:
     - `sync_type: isInitial ? "initial" : "daily"`
     - `current_time: DateFormat('HH:mm d MMM yyyy').format(now)`
     - `timezone: now.timeZoneName`
     - `language: StorageService().getString('user_language') ?? 'en'`
     - `currency: StorageService().getString(StorageService.keyCurrency) ?? 'USD'`
  10. Return `{ "client_metadata": ..., "records": ..., "summary": ... }`

### Step 2: Register in barrel export

- Modify `lib/services/services.dart`: add `export 'ai_context_service.dart';`

## Technical Details

- **Approach:** In-memory filtering and aggregation from `getAllRecords()` result. No new SQL queries.
- **Patterns to follow:** See `lib/services/chat_api_service.dart` for singleton + mock pattern, `@visibleForTesting` annotation.
- **Edge cases:**
  - `categoryName` is null → use "Uncategorized"
  - `sourceName` is null → use "Unknown"
  - Empty record list → all summary values are 0, aggregation maps are empty `{}`

## Tests to Write

Tests are covered in T2 (002-unit-tests-ai-context-service.md). This task focuses on implementation only.

## Verification Checklist

- [ ] `lib/services/ai_context_service.dart` compiles without errors: `cd /Users/nguyendai/StudioProjects/wallet-ai && flutter analyze lib/services/ai_context_service.dart`
- [ ] No Flutter UI imports in the file (no `package:flutter/material.dart`, no `BuildContext`)
- [ ] `lib/services/services.dart` exports the new file
- [ ] Manual: calling `AiContextService().getAiContext()` in debug returns a valid Map

## Dependencies

- **Blocked by:** None
- **Blocks:** T2 (unit tests)
- **External:** None — uses existing `RecordRepository`, `StorageService`, `intl` package (already in pubspec)
