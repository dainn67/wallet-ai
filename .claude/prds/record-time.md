---
name: record-time
description: Add an editable event-time field to Record so users can batch-log spending without losing the real time.
status: backlog
priority: P1
scale: medium
created: 2026-04-21T03:25:18Z
updated: null
---

# PRD: record-time

## Executive Summary
Today `Record.lastUpdated` is overloaded — it's used both as an audit timestamp (when the row was last written) and as the record's event time (when the spending actually happened). Users often batch-log records after the fact ("at 10pm I log breakfast from 9am"), so `lastUpdated` is silently wrong for the timeline they actually care about. This feature introduces a new editable `occurredAt` field that represents the event time, surfaces a date+time picker in `EditRecordPopup`, switches all user-facing sorting / filtering / display to `occurredAt`, and leaves `lastUpdated` as a pure audit field.

## Problem Statement
The app records spending via natural-language chat. In real life, users often type "Breakfast $10 at 9am" at 10pm when they sit down to log their day. Today, the record's time becomes 10pm (record-creation time). Consequences:
- Records are grouped under the wrong day when the user logs past-midnight.
- The dd/mm/yyyy timestamp on the record card can be off by a day.
- Sorting and the monthly date-range filter show records under the wrong month when a user back-fills a late-month session on the 1st of the next month.

Current workaround: there is none. Users either accept the wrong time or edit the description text ("yesterday's dinner") to compensate.

## Target Users
- **Batch logger (primary):** Logs several records at the end of the day or the morning after. Pain level: **high** — impacts every session.
- **Chat power user:** Sends natural-language messages that already include times ("Coffee at 8am"). Pain level: **high** — the AI's extracted time is thrown away today.
- **Occasional user:** Logs in real time. Pain level: **low** — default (now) behavior is already correct; they won't notice the change.

## User Stories

**US-1: Edit a record's event time after logging**
As a batch logger, I want to open `EditRecordPopup` on an existing record and change its event time so that the records list reflects when the spending actually happened.

Acceptance Criteria:
- [ ] `EditRecordPopup` shows a tappable date+time field pre-filled with `occurredAt`.
- [ ] Tapping it opens Flutter's `showDatePicker` then `showTimePicker`.
- [ ] Saving persists `occurredAt`; `lastUpdated` is updated to "now" as audit.
- [ ] The edited record moves to the correct position in the list and monthly bucket.

**US-2: Chat-parsed event time flows through**
As a chat power user, when I say "Breakfast at 9am $10" at 10pm, I want the record to be logged at 9am today, not 10pm, so that my morning/evening timeline stays accurate.

Acceptance Criteria:
- [ ] If the chat server returns `occurred_at` in the record JSON, it's persisted verbatim.
- [ ] If the server omits `occurred_at`, the client defaults it to `DateTime.now().millisecondsSinceEpoch`.
- [ ] The record card displays the `occurredAt` timestamp (dd/mm/yyyy), not the receive time.

**US-3: Existing records migrate cleanly**
As an existing user, after the update I want all my old records to have a sensible event time so that my history doesn't break.

Acceptance Criteria:
- [ ] All pre-existing `Record` rows get `occurred_at = last_updated` on first launch.
- [ ] No row ends up with `NULL`, `0`, or `-1` for `occurred_at`.
- [ ] The monthly bucket for every historical record is unchanged.

## Requirements

### Functional Requirements (MUST)

**FR-1: `Record.occurredAt` field**
Add a new non-nullable `int occurredAt` field (millisecondsSinceEpoch) on `Record`, persisted as SQLite column `occurred_at`. Defaults to `DateTime.now()` at creation, mirroring `lastUpdated`.

Scenario: New record via chat
- GIVEN the user sends a message and the server returns a record without `occurred_at`
- WHEN `ChatProvider` saves the record
- THEN `occurredAt == lastUpdated == DateTime.now()` at the moment of save

**FR-2: Server-provided event time is respected**
When the server's record JSON includes `occurred_at` (millis or ISO8601), `ChatProvider._handleStream` parses and persists it.

Scenario: Chat message with explicit time
- GIVEN the server returns `{"occurred_at": 1745212800000, ...}` for "Breakfast at 9am $10"
- WHEN the record is persisted
- THEN `record.occurredAt == 1745212800000`, `record.lastUpdated == now`

**FR-3: Edit event time in `EditRecordPopup`**
Add a date+time picker row to `EditRecordPopup` that lets the user change `occurredAt`. Uses Flutter's native `showDatePicker` + `showTimePicker`.

Scenario: User backdates a record
- GIVEN an existing record with `occurredAt = now`
- WHEN user opens the edit popup, taps the date+time row, picks yesterday 08:30, and saves
- THEN `record.occurredAt` is set to yesterday 08:30 local time
- AND `record.lastUpdated` is set to `DateTime.now()` (audit update)

**FR-4: Sorting, filtering, and display use `occurredAt`**
Replace every user-facing use of `lastUpdated` with `occurredAt`: record list ordering, cross-tab date-range filter, category totals, record card dd/mm/yyyy display, records-tab date-group dividers, home-widget monthly totals.

Scenario: Backdated record appears in prior month
- GIVEN the user backdates a record to the previous month
- WHEN the user opens `RecordsTab` with the default "current month" filter
- THEN the record disappears (it belongs to the previous month)
- WHEN the user switches filter to the previous month
- THEN the record appears in the correct month-bucket

**FR-5: Data migration (schema version 8)**
Create a separated migration service (`lib/services/record_migration_service.dart`) that adds the `occurred_at` column and backfills every existing row with its `last_updated` value, inside the existing `_onUpgrade` flow of `RecordRepository`.

Scenario: First launch after upgrade
- GIVEN an existing SQLite DB at schema version 7 with N records
- WHEN the app opens at schema version 8
- THEN `occurred_at` column exists on `Record`
- AND every existing row has `occurred_at = last_updated` (no `NULL`, `0`, or `-1`)
- AND a `idx_record_occurred_at` index is created

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Server spec handoff doc**
Emit `docs/server/record-time-server-spec.md` describing the JSON contract, parsing rules, and default behavior so the server team can implement AI time-extraction later.

### Non-Functional Requirements

**NFR-1: Migration performance**
Migration must complete in <500ms for a database with 5,000 records (typical range for a heavy single user).

**NFR-2: Backward compatibility**
No existing code path that doesn't know about `occurredAt` should break. `Record.fromMap` must tolerate legacy rows where the column is NULL (fall back to `last_updated`) as a belt-and-braces safety net, in case migration fails mid-run.

## Success Criteria
- [ ] 100% of existing records have a non-null `occurred_at` after first launch (spot-check via DB inspection).
- [ ] Batch-logged "yesterday's dinner" lands in yesterday's bucket, verified end-to-end in the running app.
- [ ] `fvm flutter analyze lib/` is clean after the change.
- [ ] All existing record-related tests still pass; the migration path has a unit test.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Migration leaves rows with NULL/0 `occurred_at` if `ALTER TABLE` succeeds but `UPDATE` is interrupted | High | Low | Wrap migration in a transaction; on next launch, re-run the backfill idempotently (`WHERE occurred_at IS NULL`). |
| Filter semantics confuse users who expect records to appear when they're logged | Medium | Medium | Use the event time exclusively, per explicit product decision. Covered by user stories. |
| Server continues to not send `occurred_at`, so chat messages with times still misreport | Medium | High (initially) | Client-side default to `now` keeps parity with today's behavior. Server spec doc hands the follow-up work off explicitly. |
| Existing tests that rely on `lastUpdated`-based sorting break silently | Low | Medium | Run full test suite after the change; fix any test that asserts old behavior. |

## Constraints & Assumptions
- **Constraint:** SQLite `ALTER TABLE ADD COLUMN` only accepts constant defaults, not expressions referencing other columns — so backfill must be a separate `UPDATE` statement.
- **Constraint:** Device-local time only. No timezone handling beyond what `DateTime` already does.
- **Assumption:** Existing `last_updated` values are correct-enough stand-ins for historical event times. If wrong, users can edit individual records.
- **Assumption:** The chat server will eventually add `occurred_at` to its record JSON; until then, client defaults to `now`.

## Out of Scope
- Server-side AI prompt changes to extract event time — captured in `docs/server/record-time-server-spec.md` as a separate hand-off.
- Timezone support (storing UTC + zone).
- Bulk "edit time for many records" UI.
- Undo for the date-time picker.

## Dependencies
- `intl` package — already present, used for formatting.
- No new packages needed (Flutter's `showDatePicker` and `showTimePicker` are built in).

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2]
scale: medium
discovery_mode: express
validation_status: pending
last_validated: null
