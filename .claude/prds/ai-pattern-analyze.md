---
name: ai-pattern-analyze
description: Transform raw SQLite records into a structured AI context snapshot for server-side spending pattern analysis
status: backlog
priority: P1
scale: small
created: 2026-04-01T06:39:21Z
updated: 2026-04-01T06:42:37Z
---

# PRD: ai-pattern-analyze

## Executive Summary

Build `AiContextService` — a dedicated Flutter service that reads raw transaction records from SQLite and transforms them into a clean, AI-readable `Map<String, dynamic>` snapshot. This snapshot is the data contract between the Flutter app and the Python AI backend, enabling server-side spending pattern analysis without any additional parsing or mapping on the server side.

## Problem Statement

The app stores rich spending data in SQLite (records with categories, sub-categories, money sources, descriptions, timestamps) but this data is in raw relational form — IDs, epoch timestamps, normalized across 3 tables. The Python AI backend cannot derive meaningful patterns (spending habits by time-of-day, category trends, income vs expense rhythm) from raw SQL rows.

Currently there is no transformation layer. Without it, any AI analysis call would need to either: (a) query and join tables itself (not possible from the server), or (b) receive a dump of raw rows and figure out the schema — error-prone and tightly coupled to the DB structure.

**Cost of inaction:** Cannot build the server-side pattern analysis endpoint, which blocks the AI greeting feature and smart action suggestions on the home screen.

*Target user note: Primary consumer is the developer (defining the contract) and the Python AI backend (consuming the snapshot). No direct end-user interaction.*

## Requirements

### Functional Requirements (MUST)

**FR-1: AiContextService class**
Create `lib/services/ai_context_service.dart` with a singleton `AiContextService` class (matching existing service patterns in the project). The class exposes a single public async method: `buildSnapshot({bool isInitial = false}) → Future<Map<String, dynamic>>`.

Scenario: Service instantiation
- GIVEN the app has initialized `RecordRepository`
- WHEN `AiContextService()` is called
- THEN the singleton instance is returned, ready to call `buildSnapshot()`

---

**FR-2: Record transformation — names only, no IDs**
Each record in the snapshot must use human-readable names (description, category name, sub-category name, money source name) rather than database IDs. The AI must be able to read the snapshot without any schema knowledge.

Scenario: Record with sub-category
- GIVEN a record with `category_id = 9` (Dining Out, parent: Food), `money_source_id = 1` (Wallet), `description = "Phở bò"`, `amount = 45000`, `type = "expense"`, `last_updated = 1743490800000` (08:15 local)
- WHEN `buildSnapshot()` is called
- THEN the record appears in snapshot as: `{ "description": "Phở bò", "amount": 45000, "currency": "VND", "type": "expense", "category": "Dining Out", "money_source": "Wallet", "time_of_day": "Morning", "date": "2026-03-31" }` where `date` is the LOCAL date string formatted as `yyyy-MM-dd`

Scenario: Record with parent category only
- GIVEN a record whose category has `parent_id = -1` (is itself a parent, e.g. "Transport")
- WHEN `buildSnapshot()` is called
- THEN `"category"` field uses the category's own name directly: `"category": "Transport"`

---

**FR-3: Time-of-day bucketing**
Convert `last_updated` (millisecondsSinceEpoch) to a named time-of-day bucket using the device's local timezone.

Buckets (local time):
- `"Morning"` — 05:00–10:59
- `"Afternoon"` — 11:00–16:59
- `"Evening"` — 17:00–21:59
- `"Night"` — 22:00–04:59

Scenario: Midnight transaction
- GIVEN a record with local time 23:30
- WHEN transformed
- THEN `"time_of_day": "Night"`

Scenario: Boundary at 11:00
- GIVEN a record with local time exactly 11:00
- WHEN transformed
- THEN `"time_of_day": "Afternoon"`

---

**FR-4: Initial snapshot — 90-day rolling window**
When `isInitial = true`, include all records from the last 90 days using a rolling window (`DateTime.now().subtract(const Duration(days: 90))`). Summary stats cover the same window. If no records exist, `records` is an empty array and all summary totals are 0.

Scenario: Initial snapshot record range
- GIVEN now is 2026-04-01T00:00:00 and there are records from 2026-01-01 (91 days ago) and 2026-01-02 (90 days ago)
- WHEN `buildSnapshot(isInitial: true)` is called
- THEN the 2026-01-01 record is excluded, the 2026-01-02 record is included; `summary.period_days = 90`

Scenario: Empty 90-day window
- GIVEN no records exist in the last 90 days
- WHEN `buildSnapshot(isInitial: true)` is called
- THEN `records` is `[]` and `summary.total_income = 0`, `summary.total_expense = 0`

---

**FR-5: Daily snapshot — rolling 24h records + 30-day summary**
When `isInitial = false` (default), the `records` array contains only records from the last 24 hours using a rolling window (`DateTime.now().subtract(const Duration(hours: 24))`). The `summary` block covers the last 30 days for trend context. If no records exist in the window, `records` is an empty array and all summary totals are 0.

Scenario: Daily snapshot record scope
- GIVEN records exist from 12 hours ago and from 3 days ago
- WHEN `buildSnapshot(isInitial: false)` is called
- THEN `records` contains only the 12h-ago record; the 3-day-old record is excluded; `summary.period_days = 30`

Scenario: Empty 24h window
- GIVEN no records exist in the last 24 hours
- WHEN `buildSnapshot(isInitial: false)` is called
- THEN `records` is an empty array `[]` and `summary.total_income = 0`, `summary.total_expense = 0`

---

**FR-6: Summary stats block**
The snapshot includes a `summary` block aggregating the period's data. Summary must include: `period_days`, `total_income`, `total_expense`, `by_category` (category name → total amount, expense only), `by_time_of_day` (bucket → total expense amount), `by_money_source` (source name → total expense amount).

Scenario: Summary aggregation
- GIVEN 3 expense records: Food/50k Morning/Wallet, Food/30k Afternoon/Bank, Transport/20k Morning/Wallet
- WHEN summary is built
- THEN: `by_category = { "Food": 80000, "Transport": 20000 }`, `by_time_of_day = { "Morning": 70000, "Afternoon": 30000 }`, `by_money_source = { "Wallet": 70000, "Bank": 30000 }`

---

**FR-7: Client metadata block**
Snapshot must include a `client_metadata` block: `sync_type` ("initial" | "daily"), `current_time` (ISO 8601 UTC), `timezone` (device timezone identifier, e.g. "Asia/Ho_Chi_Minh"), `language` (locale string from `StorageService`), `currency` (active currency from `StorageService`).

Scenario: Metadata present
- GIVEN locale is "vi-VN" and currency is "VND"
- WHEN `buildSnapshot()` is called
- THEN snapshot contains `"client_metadata": { "sync_type": "daily", "current_time": "2026-04-01T06:00:00Z", "timezone": "Asia/Ho_Chi_Minh", "language": "vi-VN", "currency": "VND" }`

---

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Export to JSON string helper**
Convenience method `Future<String> buildSnapshotJson({bool isInitial = false})` that awaits `buildSnapshot()` and returns `jsonEncode(result)`. Reduces boilerplate at call sites.

Scenario: JSON output
- GIVEN `buildSnapshot()` returns a valid map
- WHEN `buildSnapshotJson()` is called
- THEN returns a valid JSON string that can be POST-ed directly

---

### Non-Functional Requirements

**NFR-1: Performance**
`buildSnapshot()` must complete in under 500ms for a dataset of up to 500 records (90-day window). Reuses existing `RecordRepository` queries — no additional DB queries beyond what's needed.

**NFR-2: Zero UI dependency**
`AiContextService` must have no Flutter widget or BuildContext dependency. It is a pure Dart service callable from any layer.

**NFR-3: Extensibility**
The returned `Map<String, dynamic>` must use string keys. Adding new fields to the map must not require changes to callers. Server must be able to ignore unknown fields.

## Success Criteria

1. `buildSnapshot(isInitial: true)` returns a valid `Map<String, dynamic>` that passes `jsonEncode()` without error, covering records from last 90 days — verified by unit test with mock repository.
2. `buildSnapshot(isInitial: false)` returns only 24h records in the `records` array and 30-day data in `summary` — verified by unit test with seeded time-based records.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| AI server requires different fields after analysis | Medium | Medium | Map uses string keys, server ignores unknown fields. Adding fields is non-breaking. `buildSnapshot()` is the single place to update. |

## Constraints & Assumptions

**Constraints:**
- All aggregation (category totals, time-of-day totals, money source totals) must be derived from the `List<Record>` returned by `RecordRepository.getAllRecords()` — no additional SQL queries. `Record` already carries `categoryName` and `sourceName` via JOIN, so no separate name-resolution query is needed.
- Must follow existing singleton service pattern (see `ChatApiService`, `StorageService`)

**Assumptions:**
- `RecordRepository` is initialized before `AiContextService.buildSnapshot()` is called. If wrong → runtime exception on first call.
- Device timezone is accessible via `DateTime.now().timeZoneName`. If wrong on some devices → time-of-day buckets may be off; mitigation: log timezone used in client_metadata.
- 90 days of data ≤ 500 records for typical user. If wrong (power user with 1000+ records) → NFR-1 may be violated; mitigation: add pagination or limit in follow-up.

## Out of Scope

- HTTP call to send snapshot to server — `server-pattern-api` PRD
- Saving/reading AI pattern response in SharedPreferences — `ai-sync-scheduler` PRD
- Trigger logic ("sync once per 24h") — `ai-sync-scheduler` PRD
- Background execution / WorkManager — optimization after pipeline works
- Server-side pattern merging / analysis — Python backend scope
- UI: greeting display, action chips on home screen — `ai-home-suggestions` PRD

## Dependencies

- `RecordRepository` — already stable, provides `getAllRecords()` and `getCategoryTotals(start, end)` — resolved
- `StorageService` — provides locale and currency values — resolved
- Python AI server endpoint (consumer of snapshot) — not yet built — pending (`server-pattern-api`)

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2, NFR-3]
scale: small
discovery_mode: express
validation_status: warning
last_validated: 2026-04-01T06:57:55Z
