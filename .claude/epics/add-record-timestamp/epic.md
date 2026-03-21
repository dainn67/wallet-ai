---
name: add-record-timestamp
status: completed
created: 2026-03-21T00:00:00Z
progress: 100%
priority: P1
prd: .claude/prds/add-record-timestamp.md
task_count: 3
github: "https://github.com/dainn67/wallet-ai/issues/75"
---

# Epic: add-record-timestamp

## Overview
The `add-record-timestamp` epic focuses on improving the temporal visibility and organization of financial records in the `wallet-ai` app. We'll add formatted timestamps to individual record cards and implement month-based grouping in the records list. The technical approach involves utilizing the `intl` package for date formatting and implementing a grouping algorithm in the `RecordsTab` to efficiently insert dividers without compromising scroll performance.

## Architecture Decisions
### AD-1: Use `intl` for Date Formatting
**Context:** We need to format milliseconds since epoch into `dd/mm/yyyy` and `MMMM yyyy` strings.
**Decision:** Add the `intl` package to `pubspec.yaml`.
**Alternatives rejected:** Manual string manipulation (error-prone and lacks localization support).
**Trade-off:** Adds a small external dependency but provides robust, standard formatting.
**Reversibility:** High — can be replaced with standard Dart `DateTime` methods if needed, though less convenient.

### AD-2: Grouping Logic in UI Layer
**Context:** Records need to be grouped by month for display.
**Decision:** Implement grouping logic in the `RecordsTab` build/helper methods.
**Alternatives rejected:** Pre-grouping in `RecordProvider` (complicates the state model) or SQL grouping (less flexible for UI-specific dividers).
**Trade-off:** Simple to implement and maintain; performance is acceptable for expected list sizes.
**Reversibility:** High — can be moved to a Provider or Service if list sizes grow significantly.

## Technical Approach
### Dependency Management
- Create task T1 to add `intl: ^0.19.0` to `pubspec.yaml` and run `fvm flutter pub get`.

### UI Component: RecordWidget
- Modify `lib/components/record_widget.dart` to display the formatted date.
- Suggested placement: Bottom right corner or as part of the subtitle line.
- Use `DateFormat('dd/mm/yyyy').format(DateTime.fromMillisecondsSinceEpoch(record.createdAt))`.

### UI Component: MonthDivider (New)
- Create `lib/components/month_divider.dart` to display the month/year header (e.g., "March 2026").
- Style: Simple, centered or left-aligned text with subtle lines on either side.

### Screen: RecordsTab
- Update `lib/screens/home/tabs/records_tab.dart`.
- Implement a method `_buildGroupedList(List<Record> records)` that returns a `List<Widget>` containing both `MonthDivider` and `RecordWidget` items.
- Ensure the records are sorted by `createdAt` descending before grouping (already handled by `RecordRepository.getAllRecords()`).

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Display Timestamp | `RecordWidget` update | T2 | Manual UI verification |
| FR-2: Group Records | `RecordsTab` list logic | T3 | Manual UI verification with records from different months |
| FR-3: Verify `createdAt` | `Record` model audit | T1 | Unit test for `Record` model |
| NFR-1: Performance | Grouping algorithm optimization | T3 | Scroll performance check |

## Implementation Strategy
### Phase 1: Foundation
Verify the `Record` model's `createdAt` logic and add the necessary `intl` dependency. Ensure the environment is ready for date formatting.
### Phase 2: UI Enhancements
Implement the timestamp on the record card and the grouping dividers in the record list. This includes creating the new `MonthDivider` component and updating the list rendering logic.

## Task Breakdown

##### T1: Verify Model & Add Dependency
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Add `intl` package to `pubspec.yaml`. Audit `lib/models/record.dart` and `lib/repositories/record_repository.dart` to ensure `createdAt` is consistently handled as millisecondsSinceEpoch. Run `fvm flutter pub get`.
- **Key files:** `pubspec.yaml`, `lib/models/record.dart`, `lib/repositories/record_repository.dart`
- **PRD requirements:** FR-3
- **Key risk:** Incorrect assumption about existing `createdAt` data format in the database.

##### T2: Update Record Card UI
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1 | **Complexity:** simple
- **What:** Add `dd/mm/yyyy` formatted timestamp to `RecordWidget`. Use `intl` for formatting and position it cleanly in a corner of the card. Ensure it aligns with Poppins font and project colors.
- **Key files:** `lib/components/record_widget.dart`
- **PRD requirements:** FR-1
- **Key risk:** Cluttered UI on small screens; positioning issues with long descriptions.

##### T3: Implement Month Grouping in RecordsTab
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Create `MonthDivider` component. Update `RecordsTab` to group records by month/year and interleave dividers into the list. Implement efficient grouping logic (single pass).
- **Key files:** `lib/screens/home/tabs/records_tab.dart`, `lib/components/month_divider.dart`
- **PRD requirements:** FR-2, NFR-1
- **Key risk:** Inefficient grouping logic causing UI lag for larger lists; handling edge cases like empty lists.

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Scroll Stutter | Low | Low | Poor UX in long lists | Use a single-pass grouping algorithm and avoid complex widgets in dividers. |
| UI Clutter | Low | Medium | Information overload | Use subtle colors and small fonts for timestamps. |
| Timezone Inconsistency | Low | Low | Wrong date displayed | Ensure `DateTime.fromMillisecondsSinceEpoch` is used correctly with local time. |

## Dependencies
- `intl` package: Must be added to `pubspec.yaml`.

## Tasks Created
| #   | Task                     | Phase | Parallel | Est. | Depends On | Status | Issue |
| --- | ------------------------ | ----- | -------- | ---- | ---------- | ------ | ----- |
| 001 | Verify Model & Dependency | 1     | no       | 0.5d | —          | open   | #76   |
| 010 | Update Record Card UI     | 2     | yes      | 0.5d | 001        | open   | #77   |
| 011 | Create MonthDivider      | 2     | yes      | 0.5d | 001        | open   | #78   |
| 020 | Grouping in RecordsTab    | 3     | no       | 1d   | 011        | closed   | #79   |
| 090 | Integration verification | 3     | no       | 0.5d | 010, 020   | closed   | #80   |

### Summary
- **Total tasks:** 5
- **Parallel tasks:** 2 (Phase 2)
- **Sequential tasks:** 3 (Phase 1 + 3)
- **Estimated total effort:** 3d
- **Critical path:** T001 → T011 → T020 → T090 (~2.5d)

### Dependency Graph
```
Dependency Graph:
  T001 ──→ T010 ──→ T090
       ──→ T011 ──→ T020 ──→ T090

Critical path: T001 → T011 → T020 → T090 (~2.5d)
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: Timestamp | T010       | ✅ Covered |
| FR-2: Grouping  | T011, T020 | ✅ Covered |
| FR-3: createdAt | T001       | ✅ Covered |
| NFR-1: Performance | T020, T090 | ✅ Covered |
completed: 2026-03-21T09:48:47Z
