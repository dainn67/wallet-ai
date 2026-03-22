---
name: edit-record
status: backlog
created: 2026-03-22T00:00:00Z
updated: 2026-03-22T00:00:00Z
progress: 0%
priority: P1
prd: .claude/prds/edit-record.md
task_count: 6
github: https://github.com/dainn67/wallet-ai/issues/91
---

# Epic: edit-record

## Overview
This epic implements the functionality to edit existing financial records and performs a significant database refactor. We'll add an edit entry point to the `RecordWidget`, implement a comprehensive `EditRecordPopup`, and modernize the database schema by renaming the `record` table to `Record` and the `created_at` column to `last_updated`. 

## Architecture Decisions
### AD-1: Schema Modernization (Breaking Change)
**Context:** The current table name `record` is lowercase and the column `created_at` doesn't accurately reflect edited states.
**Decision:** Rename table `record` → `Record`. Rename column `created_at` → `last_updated`. Increment DB version to 6.
**Rationale:** As per user request, a "fresh start" is preferred over complex migration. This aligns table naming with the Dart model class.
**Reversibility:** Hard (requires data migration to revert).

### AD-2: Transactional Update Logic
**Context:** Editing a record's amount or source requires reversing the old impact on balances and applying the new one.
**Decision:** Implement `updateRecord` using a `database.transaction`. It must:
1. Fetch the old record.
2. Reverse the old balance impact on the old source.
3. Apply the new balance impact on the new source.
4. Update the record data.
**Rationale:** Prevents balance drift if any part of the multi-step update fails.

### AD-3: UI Component Versatility
**Context:** Records are displayed in both the Chat tab and the Records tab, but editing should only be allowed in the Records tab.
**Decision:** Add an `isEditable` boolean to `RecordWidget`.
**Rationale:** Keeps the component reusable while strictly controlling the edit entry point.

## Technical Approach
### Model Layer
- Update `lib/models/record.dart`:
    - Replace `createdAt` with `lastUpdated`.
    - Update `toMap`, `fromMap`, `copyWith`.

### Repository Layer
- Update `lib/repositories/record_repository.dart`:
    - Increment `_dbVersion` to 6.
    - Update `_onCreate` to use `Record` table name and `last_updated` column.
    - Refactor `updateRecord` with atomic delta logic (AD-2).
    - Update all queries (`getAllRecords`, `getRecordById`, `deleteRecord`) to use the new identifiers.

### UI Layer
- **Component**: Update `RecordWidget` to show a trailing `IconButton` (edit) if `isEditable` is true.
- **Popup**: Create `lib/components/popups/edit_record_popup.dart`.
    - Use `ToggleButtons` or a custom `Switch` for Income/Expense.
    - Fetch and display `MoneySource` and `Category` lists for selection.
- **Integration**: Update `RecordsTab` (or the relevant screen) to set `isEditable: true`.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Edit Button | §UI Layer | 96 | Visual check in Records tab |
| FR-2: Edit Popup | §UI Layer | 93, 94 | Open popup, check initial values |
| FR-3: DB Refactor | §Repository Layer | 92, 95 | Verify table name & version 6 |
| FR-4: Data Integrity | §Repository Layer | 95 | Test balance updates on source change |
| NFR-1: Consistency | §UI Layer | 93 | Theme & radius matching |

## Implementation Strategy
### Phase 1: Data Foundation
Refactor the model and repository. This is a breaking change that requires immediate update of all referencing code.
- Exit criterion: App builds and initializes a fresh DB (v6).
### Phase 2: Popup Development
Build the standalone `EditRecordPopup` with validation.
- Exit criterion: Popup can be triggered manually and returns a modified `Record`.
### Phase 3: Integration
Connect the `RecordWidget` to the popup and the repository update flow.
- Exit criterion: Full end-to-end edit flow works in the Records tab.

## Tasks Created
| #   | Task | Phase | Parallel | Est. | Depends On | Status |
| --- | ---- | ----- | -------- | ---- | ---------- | ------ |
| 92 | Update Record Model | 1 | no | 0.5d | — | open |
| 93 | Create EditRecordPopup UI | 2 | no | 1d | — | open |
| 94 | Implement Popup Validation | 2 | yes | 0.5d | 93 | open |
| 95 | Database Refactor | 1 | no | 1.5d | — | open |
| 96 | Update RecordWidget | 3 | no | 0.5d | 92, 93, 95 | open |
| 97 | Verification and Cleanup | 3 | no | 0.5d | all | open |

### Summary
- **Total tasks:** 6
- **Parallel tasks:** 1
- **Sequential tasks:** 5
- **Estimated total effort:** 4.5d
- **Critical path:** 95 → 92 → 93 → 96 → 97 (~4d)

### Dependency Graph
```
  95 ──→ 92 ──┐
                ├──→ 96 ──→ 97
  93 ──┬─────→ ┘
        └──→ 94
```

### PRD Coverage
| PRD Requirement | Covered By | Status |
| --------------- | ---------- | ------ |
| FR-1: Edit Button | 96 | ✅ Covered |
| FR-2: Edit Popup | 93, 94 | ✅ Covered |
| FR-3: DB Refactor | 92, 95 | ✅ Covered |
| FR-4: Data Integrity | 95 | ✅ Covered |
| NFR-1: Consistency | 93 | ✅ Covered |

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Balance Drift | High | Low | Incorrect wallet totals | Rigorous unit tests for `updateRecord` delta logic. |
| DB Init Failure | Medium | Low | App crash on startup | Ensure `_onUpgrade` correctly handles the jump to v6. |

## Success Criteria (Technical)
- `Record` table exists in DB v6.
- `last_updated` column is populated on creation and update.
- Changing a record from Source A ($100) to Source B ($100) results in Source A's balance decreasing by the amount and Source B's increasing.

## Estimated Effort
- **Total Estimate:** 4.5 days
- **Critical Path:** 4 days

## Deferred / Follow-up
- Editing existing sources (not requested).
- Custom icons for sources (not requested).
