---
name: ai-pattern-analyze
status: completed
created: 2026-04-01T06:59:42Z
completed: 2026-04-01T07:58:09Z
progress: 100%
priority: P1
prd: .claude/prds/ai-pattern-analyze.md
task_count: 2
github: "https://github.com/dainn67/wallet-ai/issues/150"
---

# Epic: ai-pattern-analyze

## Overview

Create `AiContextService` — a pure Dart service that transforms raw SQLite records into a structured snapshot `Map<String, dynamic>` for server-side AI pattern analysis. The approach is deliberately minimal: one new file, zero new SQL queries. All data comes from the existing `RecordRepository.getAllRecords()` which already JOINs Category (with parent) and MoneySource names. Aggregation (category totals, time-of-day buckets, money source totals) is computed in-memory from the record list. This avoids coupling to the database schema and makes the service fully testable with mock data.

The key implementation insight: `Record.categoryName` from `getAllRecords()` returns "Parent - Sub" format (e.g., "Food - Dining Out") for sub-categories. To get the sub-category name alone (per FR-2), we split on " - " and take the last segment. For parent-only categories, the name is returned as-is.

## Technical Approach

### AiContextService (`lib/services/ai_context_service.dart`)

**Singleton pattern** matching `ChatApiService` and `StorageService`:
- Private constructor `_internal()`
- Static `_instance` + optional `_mockInstance` for testing
- Factory constructor returns `_mockInstance ?? _instance`
- `@visibleForTesting static void setMockInstance()` for test injection

**Public API:**
```dart
Future<Map<String, dynamic>> buildSnapshot({bool isInitial = false})
```

**Implementation flow:**
1. Determine time window: `isInitial` → 90 days, else → 24h (for records), 30 days (for summary)
2. Call `RecordRepository().getAllRecords()` → filter by `lastUpdated >= cutoff.millisecondsSinceEpoch`
3. For each record in window, transform to map:
   - `description`, `amount`, `currency`, `type` — direct from Record
   - `category` — extract from `categoryName`: split by " - ", take last segment
   - `money_source` — direct from `sourceName`
   - `time_of_day` — bucket from `lastUpdated` using local time (Morning 5-10, Afternoon 11-16, Evening 17-21, Night 22-4)
   - `date` — local date formatted as `yyyy-MM-dd`
4. Build `summary` block from records within summary window (90d for initial, 30d for daily):
   - `period_days`, `total_income`, `total_expense`
   - `by_category` — expense records grouped by category name → sum
   - `by_time_of_day` — expense records grouped by bucket → sum
   - `by_money_source` — expense records grouped by source name → sum
5. Build `client_metadata`:
   - `sync_type` from `isInitial`
   - `current_time` — `DateTime.now().toUtc().toIso8601String()`
   - `timezone` — `DateTime.now().timeZoneName`
   - `language` — `StorageService().getString('user_language') ?? 'en'`
   - `currency` — `StorageService().getString(StorageService.keyCurrency) ?? 'USD'`

**Note on `categoryName`:** `RecordRepository.getAllRecords()` SQL uses `COALESCE(p.name || ' - ' || c.name, c.name)`. For sub-categories this returns "Food - Dining Out", for parent categories "Transport". Extracting the sub-category name:
```dart
String _extractCategoryName(String? categoryName) {
  if (categoryName == null) return 'Uncategorized';
  final parts = categoryName.split(' - ');
  return parts.last;
}
```

**Register in barrel:** Add `export 'ai_context_service.dart';` to `lib/services/services.dart`.

### Unit Tests (`test/services/ai_context_service_test.dart`)

Follow existing test patterns (see `test/services/chat_api_service_formatting_test.dart`). Use mock `RecordRepository` via `setMockInstance()`.

Test groups:
1. **Time-of-day bucketing** — boundary tests: 04:59→Night, 05:00→Morning, 10:59→Morning, 11:00→Afternoon, 16:59→Afternoon, 17:00→Evening, 21:59→Evening, 22:00→Night
2. **Category name extraction** — "Food - Dining Out"→"Dining Out", "Transport"→"Transport", null→"Uncategorized"
3. **Initial snapshot (90-day window)** — seed records at 89, 90, 91 days ago, verify only ≤90 included; verify `summary.period_days = 90`
4. **Daily snapshot (24h + 30-day summary)** — seed records at 12h, 25h, 5d ago; verify records list has only 12h; summary covers 30d
5. **Empty dataset** — verify `records: [], summary.total_income: 0, summary.total_expense: 0`
6. **Summary aggregation** — mixed expense/income records; verify `by_category`, `by_time_of_day`, `by_money_source` only aggregate expense; verify `total_income` and `total_expense` are correct
7. **Client metadata** — verify `sync_type`, `current_time`, `timezone`, `language`, `currency` present and correct type

## Traceability Matrix

| PRD Requirement | Epic Coverage | Task(s) | Verification |
|---|---|---|---|
| FR-1: AiContextService class | §Technical Approach / AiContextService | T1 | Unit test: instantiation |
| FR-2: Record transformation (names, no IDs) | §Technical Approach / `_extractCategoryName` | T1, T2 | Unit test: category name extraction + full record transform |
| FR-3: Time-of-day bucketing | §Technical Approach / transform step 3 | T1, T2 | Unit test: boundary tests |
| FR-4: Initial snapshot (90-day) | §Technical Approach / flow step 1-2 | T1, T2 | Unit test: date filtering |
| FR-5: Daily snapshot (24h + 30d) | §Technical Approach / flow step 1-2 | T1, T2 | Unit test: date filtering |
| FR-6: Summary stats block | §Technical Approach / flow step 4 | T1, T2 | Unit test: aggregation |
| FR-7: Client metadata | §Technical Approach / flow step 5 | T1, T2 | Unit test: metadata fields |
| NTH-1: buildSnapshotJson() | Deferred — trivial to add later | — | — |
| NFR-1: Performance <500ms | Implementation uses in-memory filtering | T2 | Manual: profile with 500-record dataset |
| NFR-2: Zero UI dependency | No BuildContext/Widget imports | T1 | Compile check |
| NFR-3: Extensibility | String-key Map output | T1 | By design |

## Implementation Strategy

### Phase 1: Foundation + Core (single phase — SMALL scale)

Build `AiContextService` with all FR-1 through FR-7 in a single file, then write comprehensive tests. The service is small enough (~120-150 lines) that splitting into phases adds overhead without benefit.

**Exit criterion:** All unit tests pass, `buildSnapshot()` returns a valid `Map` that passes `jsonEncode()`, both initial and daily modes verified.

## Task Breakdown

##### T1: Create AiContextService
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** moderate
- **What:** Create `lib/services/ai_context_service.dart` with singleton pattern (matching `ChatApiService`). Implement `buildSnapshot({bool isInitial = false})` that: (1) calls `RecordRepository().getAllRecords()`, (2) filters records by time window (90d initial / 24h daily), (3) transforms each record to a name-only map with time-of-day bucket and local date, (4) builds summary block (period_days, total_income, total_expense, by_category, by_time_of_day, by_money_source — all expense-only for the three aggregation maps), (5) adds client_metadata from `StorageService`. Extract sub-category name from joined `categoryName` by splitting on " - " and taking last segment. Add export to `lib/services/services.dart`.
- **Key files:** `lib/services/ai_context_service.dart` (new), `lib/services/services.dart` (add export)
- **PRD requirements:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7
- **Key risk:** `categoryName` format depends on `getAllRecords()` SQL JOIN staying stable — if JOIN changes, " - " split breaks.
- **Interface produces:** `AiContextService` class with `buildSnapshot()` method, consumed by T2 tests and future `server-pattern-api` epic.

##### T2: Unit tests for AiContextService
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** T1 | **Complexity:** moderate
- **What:** Create `test/services/ai_context_service_test.dart`. Mock `RecordRepository` using `setMockInstance()` pattern (same as existing tests). Test all 7 groups: time-of-day boundaries (all 8 boundary values), category name extraction (sub-cat, parent, null), initial 90-day filtering, daily 24h+30d filtering, empty dataset, summary aggregation with mixed income/expense, and client metadata fields. Verify `jsonEncode()` succeeds on output.
- **Key files:** `test/services/ai_context_service_test.dart` (new)
- **PRD requirements:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7
- **Key risk:** Mocking `RecordRepository` singleton requires `setMockInstance` pattern — already established, but `getAllRecords()` returns JOINed data so mock must produce realistic `categoryName` values.
- **Interface receives from T1:** `AiContextService` class, `setMockInstance()` for test injection.

## Risks & Mitigations

| Risk | Severity | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| `categoryName` JOIN format changes | Medium | Low | Category extraction breaks — "Dining Out" becomes "Food - Dining Out" or raw name | Add focused unit test on `_extractCategoryName()` to catch format drift. If JOIN changes, update extraction logic in one place. |
| `getAllRecords()` fetches entire DB, slow for power users with 2000+ records | Low | Low | `buildSnapshot()` exceeds 500ms NFR-1 threshold | Acceptable for v1 — typical user has <500 records. If proven slow, add date-filtered query to `RecordRepository` in follow-up. |
| Server needs fields not in current snapshot (e.g., day-of-week, description frequency) | Medium | Medium | Snapshot insufficient for AI analysis | Map uses string keys — adding fields is non-breaking. `buildSnapshot()` is single place to update. |

## Dependencies

- `RecordRepository` — stable, provides `getAllRecords()` with JOINed category/source names — **resolved**
- `StorageService` — provides language/currency via SharedPreferences — **resolved**
- Python AI server endpoint — consumer of snapshot, not yet built — **pending** (does not block this epic)

## Success Criteria (Technical)

| PRD Criterion | Technical Metric | Target | How to Measure |
|---|---|---|---|
| buildSnapshot(isInitial: true) returns valid Map | `jsonEncode()` succeeds, records from ≤90 days | 0 errors | Unit test: `test_initial_snapshot` |
| buildSnapshot(isInitial: false) returns 24h records + 30d summary | records filtered to 24h, summary.period_days = 30 | Correct filtering | Unit test: `test_daily_snapshot` |
| Performance | buildSnapshot() duration | <500ms for 500 records | Manual profiling (follow-up) |

## Estimated Effort

- **Total:** 1 day (T1: 0.5d + T2: 0.5d)
- **Critical path:** T1 → T2 (sequential)
- **Files created:** 2 new, 1 modified (services.dart barrel)

## Deferred / Follow-up

- **NTH-1: buildSnapshotJson()** — Trivial convenience method (`Future<String>`), can be added when first caller needs it.
- **Date-filtered query** — If `getAllRecords()` proves slow for power users, add `getRecordsSince(DateTime cutoff)` to `RecordRepository`.
- **Server endpoint integration** — Separate epic: `server-pattern-api`.
