---
name: add-source
status: backlog
created: 2026-03-22T00:00:00Z
updated: 2026-03-22T00:00:00Z
progress: 0%
priority: P1
prd: .claude/prds/add-source.md
task_count: 6
github: https://github.com/dainn67/wallet-ai/issues/84
---

# Epic: add-source

## Overview
This epic implements the UI and logic for adding new `MoneySource` entries from the Records tab. We'll add a "+" button to the `RecordsOverview` component that opens a custom popup dialog. The core challenge is ensuring that setting an initial balance also creates a corresponding "Initial Balance" record in the `record` table for accounting traceability, while maintaining the app's dark-themed UI patterns.

## Architecture Decisions
### AD-1: Initial Balance Record Generation
**Context:** When a user adds a source with an initial amount, the `MoneySource` table is updated. However, without a corresponding `record` entry, the total balance history will show an unexplained jump.
**Decision:** When creating a new source with an `amount > 0`, we will also insert an `income` record with a special `Initial Balance` category (ID: 1 or new) to ensure data integrity.
**Alternatives rejected:** Simply updating the `amount` column in `MoneySource` (rejected: lacks traceability).
**Trade-off:** Slightly more complex creation logic but results in a cleaner, more professional accounting system.
**Reversibility:** Easy - can be disabled by not calling `createRecord` during source creation.

### AD-2: Popup Directory and Pattern
**Context:** The user requested a new `popups` folder in `components` for "clean code".
**Decision:** Create `lib/components/popups/` and implement `AddSourcePopup` as a standard `showDialog` wrapper. This establishes a pattern for all future modal inputs.
**Alternatives rejected:** Inline conditional rendering in `RecordsOverview` (rejected: bloats the widget).
**Trade-off:** Better separation of concerns.
**Reversibility:** Hard - once established, moving components requires refactoring.

## Technical Approach
### UI Layer (Components)
- **Modify `lib/components/records_overview.dart`**: Wrap the "Sources" text in a `Row` and add an `IconButton` with `Icons.add_rounded`.
- **Create `lib/components/popups/add_source_popup.dart`**: A `StatefulWidget` using `Dialog` or `AlertDialog` with `TextFields` for name and amount. Use `Decoration` that matches the dark, rounded aesthetic of `RecordsOverview`.

### Repository Layer
- **Reuse `RecordRepository.createMoneySource`**: Already exists and handles basic insertion.
- **Extend `RecordRepository` (optional) or Service Layer**: Create a wrapper method `addSourceWithInitialBalance` that handles both `createMoneySource` and `createRecord` in a single transaction if possible.

### State Management
- **Provider Update**: Ensure that after the database operation, the relevant `ChangeNotifier` (likely `RecordProvider`) calls `notifyListeners()` or re-fetches the sources and records.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Add Source Button | §Technical Approach / UI Layer | 85 | Visual check in Records tab |
| FR-2: Add Source Popup | §Technical Approach / UI Layer | 86, 87 | Open popup, check validation |
| FR-3: Database Persistence | §Technical Approach / Repository | 88, 89 | Verify source & record in DB |
| NFR-1: UI Consistency | §Architecture Decisions / AD-2 | 86 | Match theme and radius |

## Implementation Strategy
### Phase 1: Foundation
Setup the directory structure and the basic popup UI without database logic.
- Exit criterion: Popup opens and displays correctly on top of the Records tab.
### Phase 2: Core
Implement the database logic, including the initial balance record generation.
- Exit criterion: Saving the popup adds a source to the database and refreshes the UI.
### Phase 3: Polish
Add input validation and error handling (e.g., empty names, non-numeric amounts).
- Exit criterion: Robust error handling for edge cases.

## Tasks Created
| #   | Task | Phase | Parallel | Est. | Depends On | Status |
| --- | ---- | ----- | -------- | ---- | ---------- | ------ |
| 85 | Add Source Button | 1 | no | 0.5d | — | open |
| 86 | Create AddSourcePopup UI | 1 | no | 1d | — | open |
| 87 | Implement Popup Validation | 2 | yes | 0.5d | 86 | open |
| 88 | Database Integration | 2 | yes | 1d | 85, 86 | open |
| 89 | Refresh UI | 2 | yes | 0.5d | 88 | open |
| 90 | Integration Verification | 3 | no | 0.5d | all | open |

### Summary
- **Total tasks:** 6
- **Parallel tasks:** 3 (Phase 2)
- **Sequential tasks:** 3 (Phase 1 + 3)
- **Estimated total effort:** 4d
- **Critical path:** 86 → 88 → 89 → 90 (~3d)

### Dependency Graph
```
  85 ──┐
        ├──→ 88 ──→ 89 ──┐
  86 ──┤                  ├──→ 90
        └──→ 87 ──────────┘
```

### PRD Coverage
| PRD Requirement | Covered By | Status |
| --------------- | ---------- | ------ |
| FR-1: Add Button | 85 | ✅ Covered |
| FR-2: Popup UI | 86, 87 | ✅ Covered |
| FR-3: Persistence | 88, 89 | ✅ Covered |
| NFR-1: Consistency | 86 | ✅ Covered |

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Database Transaction Failure | Medium | Low | Source created without initial record | Use `database.transaction` in `RecordRepository`. |
| UI Jitter on Refresh | Low | Medium | Screen flashes when re-fetching | Use `FutureBuilder` or ensure `Provider` updates are surgical. |
| Duplicate Names | Low | Medium | DB unique constraint error | Check name existence before insert in `T4`. |

## Dependencies
- `RecordRepository` — Internal — Status: Ready
- `RecordProvider` — Internal — Status: Ready

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Add new source | Source count in DB | Increase by 1 | `SELECT count(*) FROM MoneySource` |
| UI Updates | New source card visible | Immediately | Manual verification |
| Initial Balance record | Record count in DB | Increase by 1 if amount > 0 | `SELECT count(*) FROM record WHERE description = 'Initial Balance'` |

## Estimated Effort
- **Total Estimate:** 4 days
- **Critical Path:** 3 days

## Deferred / Follow-up
- Editing existing sources (not requested).
- Custom icons for sources (not requested).
