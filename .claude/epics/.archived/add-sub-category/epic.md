---
name: add-sub-category
status: backlog
created: 2026-03-27T08:34:21Z
updated: 2026-03-27T08:34:21Z
progress: 100%
priority: P1
prd: .claude/prds/add-sub-category.md
task_count: 7
github: https://github.com/dainn67/wallet-ai/issues/128
---

# Epic: add-sub-category

## Overview
This epic implements a two-level hierarchical category system ("Parent - Sub") to improve financial tracking granularity. We'll add a `parent_id` field to the `Category` table, update the AI prompt to handle this hierarchy, and refactor the Categories tab to use `ExpansionTile`. The core architectural challenge is mapping existing flat categories to the new structure while ensuring the AI accurately classifies transactions into specific sub-categories. We'll leverage SQLite migrations and Provider-level caching to maintain performance.

## Architecture Decisions
### AD-1: Flat vs. Nested Model
**Context:** Need to support sub-categories while keeping the schema simple.
**Decision:** Use a single `Category` table with a `parent_id` self-reference.
**Alternatives rejected:** Creating a separate `SubCategory` table (would duplicate logic and complicate JOINs).
**Trade-off:** Requires recursive or multi-step loading in the Provider to build the tree, but simplifies the database schema.
**Reversibility:** Easy to add more fields, moderate to move to a multi-table structure later.

### AD-2: AI Classification Strategy
**Context:** AI needs to know both parent and sub-categories to provide accurate IDs.
**Decision:** Format the `category_list` in `ChatApiService` as a hierarchical string: `ID: Name (Parent: ParentName)`.
**Alternatives rejected:** Sending a JSON tree (might consume more tokens and increase parsing complexity).
**Trade-off:** Slightly longer strings in the prompt, but much higher classification accuracy.
**Reversibility:** Easy to change the formatting in `ChatApiService.formatCategories`.

## Technical Approach
### Model & Database Layer
- **File:** `lib/models/category.dart` — Add `parentId` (int) and update `fromMap`/`toMap`.
- **File:** `lib/repositories/record_repository.dart` — Update `_onCreate` schema and implement `_onUpgrade` (version 7) to add `parent_id` column and seed default hierarchy.
- **File:** `lib/repositories/record_repository.dart` — Update `getAllRecords` and `getRecordById` to JOIN with the `Category` table twice (once for sub, once for parent) to fetch the "Parent - Sub" name directly in SQL.

### Provider Layer
- **File:** `lib/providers/record_provider.dart` — Add a `Map<int, List<Category>> _subCategories` to store sub-categories keyed by their parent ID. Update `loadAll` to populate this map.
- **File:** `lib/providers/record_provider.dart` — Update `getCategoryName` to return "Parent - Sub" if `parentId != -1`.

### AI & UI Layer
- **File:** `lib/services/chat_api_service.dart` — Refactor `formatCategories` to build the "ID: Sub (Parent: Parent)" string.
- **File:** `lib/screens/home/tabs/categories_tab.dart` — Replace the flat `ListView` with a list of `ExpansionTile` widgets for parent categories, containing their sub-categories and an "Add Sub-category" action button.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: DB & Model | §Technical Approach / Model & DB | 129, 130 | Unit tests + DB inspection |
| FR-2: Seed Defaults | §Technical Approach / Model & DB | 130 | Check DB on fresh install |
| FR-3: UI Refactor | §Technical Approach / AI & UI | 132, 133 | Manual UI verification |
| FR-4: AI Prompt | §Technical Approach / AI & UI | 131 | Integration test with AI |
| FR-5: Display Logic | §Technical Approach / Provider | 130, 134 | Verify record list names |
| NFR-1: Performance | §Technical Approach / Provider | 130, 132 | Scroll testing |
| NFR-2: AI Accuracy | §Technical Approach / AI & UI | 131 | Test various chat inputs |

## Implementation Strategy
### Phase 1: Foundation
Update the `Category` model and database schema. This includes the migration logic and seeding the new default hierarchy.
- **Exit Criterion:** `Category` table has `parent_id` column and seeded data is correct.

### Phase 2: Core
Update `RecordProvider` to handle the hierarchy and `ChatApiService` to send the correct prompt format.
- **Exit Criterion:** Records show "Parent - Sub" in UI and AI classifies correctly.

### Phase 3: Polish
Implement the `ExpansionTile` UI and the "Add Sub-category" functionality.
- **Exit Criterion:** Categories tab is fully functional and nested.

## Task Breakdown

##### 129: Update Category Model
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Add `parentId` to the `Category` model, update `toMap`, `fromMap`, and `copyWith`. Update existing tests in `test/models/`.
- **Key files:** `lib/models/category.dart`, `test/models/category_test.dart`
- **PRD requirements:** FR-1
- **Key risk:** Breaking existing model deserialization if null values aren't handled correctly.

##### 130: Database Schema & Migration
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Depends:** 129 | **Complexity:** moderate
- **What:** Update `RecordRepository` schema version to 7. Implement `_onUpgrade` to add `parent_id` column. Update `_seedDatabase` with the new hierarchical defaults. Update `getAllRecords` JOIN logic to fetch parent category names.
- **Key files:** `lib/repositories/record_repository.dart`
- **PRD requirements:** FR-1, FR-2, FR-5
- **Key risk:** Complex SQL JOINs for parent-sub hierarchy might impact query performance if not optimized.

##### 131: AI Prompt Hierarchical Formatting
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** 130 | **Complexity:** simple
- **What:** Update `ChatApiService.formatCategories` to produce the `ID: Sub (Parent: ParentName)` string format.
- **Key files:** `lib/services/chat_api_service.dart`
- **PRD requirements:** FR-4
- **Key risk:** If the string format is too verbose, it may hit token limits or confuse the AI.

##### 132: Provider Hierarchy Logic
- **Phase:** 2 | **Parallel:** no | **Est:** 1d | **Depends:** 130 | **Complexity:** moderate
- **What:** Update `RecordProvider` to group categories by `parentId`. Implement helper methods to get sub-categories for a given parent and update `getCategoryName` for hierarchical display.
- **Key files:** `lib/providers/record_provider.dart`
- **PRD requirements:** FR-5
- **Key risk:** Ensuring the cache stays in sync when sub-categories are added/deleted.

##### 133: Categories Tab UI Refactor
- **Phase:** 3 | **Parallel:** no | **Est:** 1.5d | **Depends:** 132 | **Complexity:** moderate
- **What:** Refactor the Categories tab to use `ExpansionTile` for parent categories. Implement the sub-category list within each tile and the "Add Sub-category" button.
- **Key files:** `lib/screens/home/tabs/categories_tab.dart`
- **PRD requirements:** FR-3
- **Key risk:** UI overflow or nested scroll issues within the `ExpansionTile`.

##### 134: Record List & UI Name Display
- **Phase:** 3 | **Parallel:** yes | **Est:** 0.5d | **Depends:** 132 | **Complexity:** simple
- **What:** Ensure all UI components that display a category name (Transaction cards, Record edit screen) show the "Parent - Sub" format correctly.
- **Key files:** `lib/components/record_widget.dart`, `lib/components/popups/edit_record_popup.dart`
- **PRD requirements:** FR-5
- **Key risk:** String length issues in small UI components.

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| AI ID Confusion | Medium | Medium | Wrong category assigned | Use very explicit formatting in the prompt: `ID: [SubName] (Category: [ParentName])`. |
| Migration Failure | High | Low | Data loss or app crash | Thoroughly test the migration from v6 to v7 on real device data. |
| UI Jitter | Low | Medium | Poor user experience | Use `const` widgets and optimize `RecordProvider` notifications. |

## Dependencies
- **RecordRepository**: Needs schema update (v7).
- **ChatApiService**: Needs prompt string refinement.

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Sub-category creation | Successful DB Insert | 100% | Unit test on `createCategory` with `parentId` |
| Hierarchical Display | "Parent - Sub" string presence | 100% | Integration test on `RecordProvider.getCategoryName` |
| AI Classification | Correct Sub-ID returned | >90% | Manual chat tests with known sub-category keywords |

## Estimated Effort
- **Total Estimate:** 5 days
- **Critical Path:** 129 → 130 → 132 → 133
- **Phases Timeline:** 1.5d (Foundation), 1.5d (Core), 2d (UI/Polish)

## Tasks Created
| #   | Task                     | Phase | Parallel | Est. | Depends On | Status |
| --- | ------------------------ | ----- | -------- | ---- | ---------- | ------ |
| 129 | Update Category Model    | 1     | no       | 0.5d | —          | open   |
| 130 | DB Schema & Migration    | 1     | no       | 1d   | 129        | open   |
| 131 | AI Prompt Formatting     | 2     | yes      | 0.5d | 130        | open   |
| 132 | Provider Hierarchy Logic | 2     | yes      | 1d   | 130        | open   |
| 133 | Categories Tab UI        | 3     | no       | 1.5d | 132        | open   |
| 134 | UI Name Display          | 3     | yes      | 0.5d | 132        | open   |
| 135 | Integration Verification | 3     | no       | 0.5d | all        | open   |

### Summary
- **Total tasks:** 7
- **Parallel tasks:** 3 (Phase 2 & 3)
- **Sequential tasks:** 4 (Phase 1, 2, 3)
- **Estimated total effort:** 5.5d
- **Critical path:** 129 → 130 → 132 → 133 → 135 (~3.5d)

### Dependency Graph
```
  129 ──→ 130 ──→ 131 (parallel) ─→ 135
              ──→ 132 ────────────→ 133 ──→ 135
                                   ──→ 134 (parallel) ──→ 135
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: DB & Model | 129, 130 | ✅ Covered |
| FR-2: Seed Defaults | 130       | ✅ Covered |
| FR-3: UI Refactor | 133       | ✅ Covered |
| FR-4: AI Prompt | 131       | ✅ Covered |
| FR-5: Display Logic | 130, 132, 134 | ✅ Covered |
| NFR-1: Performance | 130, 132 | ✅ Covered |
| NFR-2: AI Accuracy | 131       | ✅ Covered |
