---
name: category-filter
description: Tap a category on the Categories tab to open a popup listing that category's records for the month; plus a Records-tab sort fix (occur time instead of last-update).
status: backlog
priority: P1
scale: medium
created: 2026-04-24T17:08:07Z
updated: null
---

# PRD: category-filter

## Executive Summary

The Categories tab already groups monthly totals by category and sub-category, but users have no way to see which individual records make up each total — the drill-down is missing. This feature makes every category and sub-category row on the Categories tab tappable: tapping opens a simple popup that lists the records in that scope for the currently-selected month, grouped visually per sub-category and sorted newest-first by occurrence time. Each record row reuses the existing edit affordance from the Records tab, so no new interaction models are introduced. A small bundled fix switches the Records tab's own sort key from last-update to occurrence time so both surfaces behave consistently.

## Problem Statement

The Categories tab is the natural place for a user to do a monthly review — "how much did I spend on Food in March?" — because it already summarizes spending by category. But once the user sees a suspicious total they have no way to audit it inside the tab. They have to leave the Categories tab, go to the Records tab (which shows every record, mixed across all categories), and either scroll or eyeball for matches. Because sub-categories are already dropdown-grouped under their parent on the Categories tab, the drill-down expectation is even stronger: the UI implies interactivity that isn't wired up.

Compounding the issue: the Records tab sorts records by last-update timestamp, not by occurrence time. This means editing an old record jumps it to the top, hiding chronological intent. Users have complained that a list they thought of as "my transactions in order" doesn't actually behave that way.

Cost of inaction: every monthly review today costs the user extra taps and cognitive load that the existing data model could answer instantly.

## Target Users

| Role | Context | Primary Need | Pain Level |
| ---- | ------- | ------------ | ---------- |
| Specialist / Power User | Monthly budget review on the Categories tab | Audit which records make up a category's total without leaving the tab | High |
| Organizer | Glancing at category totals to check for odd numbers | Drill into a suspicious total with one tap, verify, move on | Medium |
| Returning User | Cross-checking last month's spend after editing an old record | Records ordered by when things happened, not when they were last touched | Medium |

## User Stories

**US-1: Drill from a category total to its records**
As a Specialist user, I want to tap a category row on the Categories tab and see the actual records behind that total so I can audit my spending without switching tabs.

Acceptance Criteria:
- [ ] Tapping any parent-category row opens a popup listing records for that category in the currently-selected month.
- [ ] Records in the popup are sorted newest-first by occurrence time.
- [ ] Each record row shows the same information as on the Records tab (amount, description, date, category name).
- [ ] Each record row exposes the same edit action users already know from the Records tab.

**US-2: Drill into a specific sub-category**
As an Organizer user, I want to tap a sub-category row and see only its records so I can check whether a sub-category's total is correct.

Acceptance Criteria:
- [ ] Tapping a sub-category row opens the popup scoped to that sub-category only (no parent or sibling records).
- [ ] Empty-state message is shown when the scope has zero records for the month.

**US-3: Parent tap shows union**
As a Specialist user, I want tapping the parent category (even when sub-categories exist) to show everything under it — the parent's direct records plus every sub-category's records — so I can see the full picture of that category.

Acceptance Criteria:
- [ ] Popup opened from a parent row includes records directly assigned to the parent AND records assigned to any of its sub-categories.
- [ ] Records are visually grouped by sub-category, with a border around each sub-category group; parent-direct records form their own group.
- [ ] Group order is stable across opens (e.g., parent-direct first, then sub-categories in their tab order).

**US-4: Consistent chronological sort on Records tab**
As a Returning user, I want the Records tab sorted by when transactions actually happened, not by when I last edited them, so editing an old record doesn't reshuffle my list.

Acceptance Criteria:
- [ ] Records tab sorts newest-first by the record's occurrence time (not last-update timestamp).
- [ ] Editing an existing record does not change its position in the list (unless the occurrence time itself is edited).

## Requirements

### Functional Requirements (MUST)

**FR-1: Tappable category/sub-category rows on the Categories tab**
Every parent-category row and every sub-category row on the Categories tab accepts a tap gesture and opens the Category Records popup scoped to that row.

Scenario: Happy path — tap a parent category
- GIVEN the Categories tab is on month "March 2026" and shows a parent category "Food" with total 1,200,000đ
- WHEN the user taps the "Food" row
- THEN the Category Records popup opens, scoped to "Food" (union of parent + subs) for March 2026

Scenario: Happy path — tap a sub-category
- GIVEN the parent category "Food" is expanded and sub-category "Groceries" is visible
- WHEN the user taps the "Groceries" row
- THEN the Category Records popup opens, scoped to "Groceries" only for the current month

**FR-2: Parent tap shows union with visual grouping**
When the popup is opened from a parent row, it contains records from the parent and all its sub-categories. Records are visually grouped by sub-category (bordered group), with parent-direct records in their own group.

Scenario: Parent with sub-categories
- GIVEN parent "Food" has 2 parent-direct records, sub "Groceries" has 3 records, sub "Dining" has 1 record (all in the current month)
- WHEN the user opens the popup from the "Food" row
- THEN the popup shows 3 bordered groups: parent-direct (2 records), Groceries (3 records), Dining (1 record), in that order

Scenario: Parent with no sub-categories
- GIVEN parent "Salary" has 0 sub-categories and 1 record in the current month
- WHEN the user opens the popup from the "Salary" row
- THEN the popup shows a single group (no border needed or a single bordered group — implementation choice) with that 1 record

**FR-3: Popup record rows reuse the existing edit action**
Each record row in the popup presents the same edit affordance (button) that exists on the Records tab, invoking the same edit flow.

Scenario: Edit from popup
- GIVEN the popup is open with at least 1 record
- WHEN the user taps the edit button on a record row
- THEN the existing edit record flow opens (same screen/sheet as the Records tab)
- AND on save, the popup reflects updated values when it re-renders

**FR-4: Records tab sorts by occurrence time (newest-first)**
The Records tab's record list is sorted by the record's occurrence timestamp in descending order. The popup also sorts its records by the same key.

Scenario: Edit an old record
- GIVEN the Records tab shows records in occurrence-time order
- WHEN the user edits a record from 3 months ago (without changing its occurrence time) and saves
- THEN the edited record remains in its chronological position (does NOT jump to the top)

Scenario: New record today
- GIVEN the Records tab is open
- WHEN a new record is added with today's occurrence time
- THEN the new record appears at the top of the list

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Empty-state message in popup**
When the scoped category/sub has zero records in the current month, the popup shows a short empty-state message (e.g., "No records in this category for {month}.") instead of a blank area. Deferred as NTH because total = 0 is rare on the Categories tab (the row would not typically be tapped if it shows 0) — the empty state is a polish improvement, not blocking.

Scenario: Empty scope
- GIVEN the user taps a sub-category with 0 records in the current month
- WHEN the popup opens
- THEN it shows the empty-state message and no record rows

### Non-Functional Requirements

**NFR-1: Popup open latency**
The popup must fully render within 200ms on a mid-tier Android device for a scope containing up to 100 records. A plain `ListView` (or equivalent) is acceptable — no pagination.

**NFR-2: Component reuse / code footprint**
Implementation must reuse the existing record-row widget from the Records tab (or extract a single shared widget). No more than one new widget file should be introduced for the popup itself. This is a quality constraint, not a user-visible behavior: the reviewer checks the diff.

## Success Criteria

- **Measurable — drill-down usage:** After release, the popup is opened at least once per session by ≥30% of weekly active users who use the Categories tab. Measured via analytics event `category_records_popup_opened` over a 2-week window post-launch.
- **Measurable — support/feedback signal:** Zero new complaints within 30 days about "I can't see what's in a category" or "my records reshuffled after editing". Tracked via the existing feedback channel.
- **Measurable — no regression on Records tab:** Records tab render time on a 1000-record dataset remains within 10% of the current baseline after the sort-key change. Measured via existing profiling pass.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
| ---- | -------- | ---------- | ---------- |
| Over-engineering the popup (extra components, unnecessary state) contradicts the explicit "keep it simple" ask | Medium | Medium | Hard cap of 1 new widget file for the popup; reuse the existing record-row widget; code review rejects new abstractions |
| Parent-union query returns wrong records (e.g., misses sub-cat records or includes other parents) | High | Low | Derive the sub-category id set from the existing `parentId` lookup used by `chat_api_service.dart`; unit-test the filter with a parent that has 0, 1, and multiple subs |
| Records-tab sort change silently confuses users who were used to the old behavior | Low | Low | Ship silently per product call; monitor feedback channel for first 2 weeks; the new behavior matches what users already expected |
| Edit flow launched from popup doesn't refresh the popup on save | Medium | Medium | Re-query the scoped records when the edit flow pops back, or rebuild via provider notification (same pattern the Records tab already uses) |

## Constraints & Assumptions

**Constraints:**
- Must not introduce new component abstractions beyond a single popup widget (user directive: keep UI simple, reuse existing components).
- No new server-side API — filtering is client-side against existing local data (SQLite + RecordProvider cache).
- Must ship behind the existing Categories tab — no new top-level navigation.

**Assumptions:**
- The Record model already stores a usable occurrence timestamp (date field) distinct from last-update. *If wrong*, a small migration/data audit is needed before FR-4 can ship — bumps the scope.
- Sub-categories are addressed via `parentId` on the Category model as seen in `lib/models/category.dart`. *If wrong*, the union-query logic has to be reworked.
- Record volume per category per month is typically well under 100 for target users. *If wrong*, NFR-1 holds up to 100 but a power user with 500+ monthly records in one category may see jank — revisit with pagination.

## Out of Scope

- Cross-month filtering inside the popup — *the popup inherits the tab's current month and does not offer its own selector.*
- Search / text filter inside the popup — *keep UI minimal; search belongs on the Records tab if ever added.*
- Date-range picker — *monthly scope is sufficient for the monthly-review use case.*
- Charts / visualizations — *this PRD is about drill-down lists, not analytics.*
- Export / share — *not part of the review workflow.*
- New swipe gestures or delete shortcut on record rows — *edit-only, matching Records tab.*
- Changelog / toast announcing the Records-tab sort change — *ship silently.*
- Pagination / virtualization — *plain ListView is explicitly acceptable per user directive.*

## Dependencies

- `add-category-table` PRD (status: complete) — provides the Category table and Record.categoryId FK. Resolved.
- `add-sub-category` PRD (status: backlog in PRDs dir, but code evidence shows `parentId` is already implemented on `lib/models/category.dart`) — the union behavior depends on this being live in code. **Status: implemented in code; PRD metadata should be synced separately.** Pending.
- `update-category` PRD (status: complete) — provides the Categories tab and sub-category dropdown UI that this feature attaches to. Resolved.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2]
scale: medium
discovery_mode: full
validation_status: warning
last_validated: 2026-04-25T11:45:24Z
