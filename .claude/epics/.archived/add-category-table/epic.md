---
name: add-category-table
status: completed
created: 2026-03-18T12:35:00Z
progress: 100%
priority: P1
prd: .claude/prds/add-category-table.md
task_count: 5
github: "https://github.com/dainn67/wallet-ai/issues/57"
---

# Epic: add-category-table

## Overview
This epic implements a robust categorization system for financial records. By introducing a dedicated `Category` table and linking it to the `Record` table, we provide users with a way to organize transactions beyond simple text descriptions. The implementation focuses on performance via SQL `JOIN` queries and Provider-level caching, ensuring the UI remains snappy. We will also update the `RecordsTab` to display these categories, improving the overall UX of the transaction history.

## Architecture Decisions
### AD-1: Schema Refactor vs. Migration
**Context:** The app has not yet been released, and we are still in early development.
**Decision:** Refactor the `_onCreate` method in `RecordRepository` directly instead of writing a complex migration script.
**Alternatives rejected:** SQL migration scripts (rejected for simplicity since we are okay with a fresh start).
**Trade-off:** Existing local data will be wiped upon the next fresh install/re-init.
**Reversibility:** Low (once schema is changed, it's the new baseline).

### AD-2: Combined JOIN and Cache Strategy
**Context:** We want fast lookups for category names in the UI list.
**Decision:** Use SQL `JOIN` in the repository to fetch the category name alongside the record, but also maintain a `Map<int, Category>` cache in the `RecordProvider` for quick lookups in other parts of the app.
**Alternatives rejected:** Lookup by ID for every item (slow for large lists).
**Trade-off:** Slightly more complex repository logic for significantly better performance.
**Reversibility:** High (can revert to simple lookups if JOIN becomes a bottleneck).

## Technical Approach
### Database Layer
- **Category Table**: `category_id (PK)`, `name (TEXT)`, `type (TEXT)` (though we'll start with global categories).
- **Record Table Update**: Add `category_id (INT, FK)`.
- **Seeding**: Add logic to `_onCreate` to insert "Food", "Transport", "Entertainment", "Salary", "Rent", "Health", and "Uncategorized".

### Model Layer
- **Category Model**: New `Category` class in `lib/models/category.dart`.
- **Record Model Update**: Add `int categoryId` and `String? categoryName`. Update `fromMap` and `toMap` to support JOIN results.

### Provider Layer
- **RecordProvider**: Add `List<Category> _categories` and a `Map<int, String> _categoryCache`.
- **Initialization**: Load all categories on startup.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: DB Schema Refactor | §Database Layer | T1 | `sqlite3` table check |
| FR-2: Category Seeding | §Database Layer | T1 | `SELECT * FROM Category` check |
| FR-3: Model & Repository | §Model Layer | T2, T3 | Unit tests for fromMap/JOIN |
| FR-4: Provider Caching | §Provider Layer | T4 | UI loads category names |
| FR-5: UI Integration | §RecordsTab UI | T5 | Manual UI verification |
| NFR-1: Performance | Implementation | T4, T5 | Smooth scroll verification |

## Implementation Strategy
### Phase 1: Persistence
Define the new model and refactor the repository's `_onCreate` and `_onUpgrade` (for testing) logic.
### Phase 2: Logic Integration
Update the `RecordProvider` to handle the new fields and implement caching.
### Phase 3: UI Presentation
Update the `RecordsTab` to display the new data.

## Task Breakdown

##### T1: Refactor Database & Seeding
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Update `RecordRepository._onCreate` to create the `Category` table and add the `category_id` column to the `record` table. Add seeding logic for common categories.
- **Key files:** `lib/repositories/record_repository.dart`
- **PRD requirements:** FR-1, FR-2
- **Key risk:** Data loss (accepted by user).

##### T2: Create Category Model
- **Phase:** 1 | **Parallel:** yes | **Est:** 0.3d | **Depends:** — | **Complexity:** simple
- **What:** Create `lib/models/category.dart` and export it in `lib/models/models.dart`.
- **Key files:** `lib/models/category.dart`, `lib/models/models.dart`
- **PRD requirements:** FR-3
- **Key risk:** None.

##### T3: Update Record Model & Repository Queries
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** T1, T2 | **Complexity:** moderate
- **What:** Add `categoryId` and `categoryName` to `Record` model. Update `getAllRecords` in `RecordRepository` to use a SQL JOIN with the `Category` table.
- **Key files:** `lib/models/record.dart`, `lib/repositories/record_repository.dart`
- **PRD requirements:** FR-3
- **Key risk:** Incorrect SQL JOIN syntax leading to missing records.

##### T4: Update Provider with Caching
- **Phase:** 2 | **Parallel:** no | **Est:** 0.5d | **Depends:** T3 | **Complexity:** moderate
- **What:** Update `RecordProvider` to fetch and store the list of categories. Implement a cache for fast category name lookups.
- **Key files:** `lib/providers/record_provider.dart`
- **PRD requirements:** FR-4
- **Key risk:** Cache staleness if categories are added/removed (though CRUD for categories is out of scope).

##### T5: Update RecordsTab UI
- **Phase:** 3 | **Parallel:** no | **Est:** 0.5d | **Depends:** T4 | **Complexity:** simple
- **What:** Modify the record card in `RecordsTab` to display the category name. Ensure the layout remains clean.
- **Key files:** `lib/screens/home/tabs/records_tab.dart`
- **PRD requirements:** FR-5
- **Key risk:** UI overcrowding.

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Database Versioning | Low | Low | Crash on init | Bump DB version to 5 and ensure fresh start logic works. |
| JOIN Performance | Low | Low | List lag | Use index on `category_id` and implement caching as planned. |
| UI Clutter | Medium | Medium | Bad UX | Use a small, subtle label for categories (e.g., grey text, dot separator). |

## Dependencies
- None.

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Schema Validity | Table count | 3 (MoneySource, record, Category) | `adb shell sqlite3` or equivalent |
| Data Loading | JOIN query time | < 50ms | Log execution time |
| Build Integrity | Test pass rate | 100% | `fvm flutter test` |

## Tasks Created
| #   | Task                         | Phase | Parallel | Est. | Depends On | Status |
| --- | ---------------------------- | ----- | -------- | ---- | ---------- | ------ |
| 001 | Refactor Database & Seeding  | 1     | no       | 0.5d | —          | open   |
| 002 | Create Category Model        | 1     | yes      | 0.3d | —          | open   |
| 003 | Update Model & Repo Queries  | 1     | no       | 0.5d | 001,002    | open   |
| 010 | Update Provider with Caching | 2     | no       | 0.5d | 003        | open   |
| 020 | Update RecordsTab UI         | 3     | no       | 0.5d | 010        | open   |

### Summary
- **Total tasks:** 5
- **Parallel tasks:** 1 (T002)
- **Sequential tasks:** 4
- **Estimated total effort:** 2.3d
- **Critical path:** T001 → T003 → T010 → T020 (~2.0d)

### Dependency Graph
```
  T001 ──┐
         ├─→ T003 ──→ T010 ──→ T020
  T002 ──┘
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: DB Schema | T001       | ✅ Covered |
| FR-2: Seeding   | T001       | ✅ Covered |
| FR-3: Model/Repo| T002, T003 | ✅ Covered |
| FR-4: Caching   | T010       | ✅ Covered |
| FR-5: UI        | T020       | ✅ Covered |
