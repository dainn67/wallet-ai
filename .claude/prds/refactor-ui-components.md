---
name: refactor-ui-components
description: Refactor record UI into reusable components and redesign the records overview with Material 3.
status: completed
priority: P1
scale: medium
created: 2026-03-20T03:46:51Z
updated: 2026-03-20T04:26:00Z
---

# PRD: refactor-ui-components

## Executive Summary
This PRD focuses on improving the code maintainability and visual polish of the Wally AI app. We will extract the duplicated record display logic into a reusable `RecordWidget` and redesign the `RecordsTab` overview box. The goal is to provide a cleaner, more consistent Material 3 experience across the chat and records tab while simplifying future UI development.

## Problem Statement
Currently, the UI for displaying individual records (income/expense) is duplicated in `lib/screens/home/tabs/chat_tab.dart` and `lib/screens/home/tabs/records_tab.dart`. This duplication leads to inconsistent styling and increased maintenance effort. Furthermore, the existing records overview box lacks a modern look and doesn't clearly highlight the relationship between money sources and their totals.

## Target Users
- **End-User (Financial Tracker):** Wants a clear, visually appealing summary of their finances and a consistent view of their records whether they are chatting with the AI or browsing their history.
- **Flutter Developer:** Needs a clean, componentized codebase to quickly build new features without re-implementing existing UI patterns.

## User Stories
**US-1: Consistent Record View**
As a user, I want my income and expense records to look the same across the app so that I can easily recognize and parse my financial data.

Acceptance Criteria:
- [ ] Record items in chat messages and the records history tab share the exact same visual structure.
- [ ] Income and expense items are clearly distinguishable (e.g., via color or icons).

**US-2: Clear Source Overview**
As a user, I want to see how much money is in each of my sources at a glance so that I understand my current financial position.

Acceptance Criteria:
- [ ] A horizontal list of money sources with their total balances is displayed at the top of the Records tab.
- [ ] Total income and total expense for the current view are clearly summarized.

## Requirements

### Functional Requirements (MUST)

**FR-1: Reusable RecordWidget**
Extract the record display logic into a standalone "dumb" component.

Scenario: Rendering in Chat
- GIVEN a `Record` model is passed to the widget.
- WHEN rendered within a chat bubble.
- THEN it displays the amount, category, and source without causing layout overflows.

**FR-2: Horizontal Source List**
Implement a horizontal scrolling list of money sources in the redesigned overview.

Scenario: Multiple Sources
- GIVEN the user has 3+ money sources.
- WHEN viewing the Records tab overview.
- THEN the sources are displayed as horizontal cards, each showing the source name and total amount.

**FR-3: Summary Stats**
Display the aggregated totals for income and expenses.

Scenario: Overview Update
- GIVEN the list of records changes.
- WHEN the overview box re-renders.
- THEN it displays the updated "Total Expense" and "Total Income" prominently below the source list.

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Animated Transitions**
Use subtle Material 3 animations (e.g., FadeTransition) when record items are added or the overview updates.

### Non-Functional Requirements

**NFR-1: Visual Consistency**
All UI components must adhere to Material 3 design principles, using the project's established `google_fonts` (Poppins) and color scheme.

**NFR-2: Layout Robustness**
The `RecordWidget` must handle long category names or large amounts gracefully (e.g., using `TextOverflow.ellipsis`) to prevent horizontal or vertical overflows in narrow containers like chat bubbles.

## Success Criteria
- [ ] Code duplication for record items is eliminated.
- [ ] The `RecordsTab` overview uses Material 3 `Card` or similar containers for a polished look.
- [ ] The horizontal source list scrolls smoothly on all device sizes.
- [ ] No layout overflows are reported in the chat or history views.

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
| ---- | -------- | ---------- | ---------- |
| Overflow in Chat Bubbles | High | Medium | Use `Flexible`/`Expanded` and `TextOverflow.ellipsis` inside the `RecordWidget`. |
| Performance with Many Sources | Low | Low | Use `ListView.builder` for the horizontal source list to ensure efficient rendering. |
| Inconsistent Styling | Medium | Low | Reference the theme context for all colors and text styles within the new components. |

## Constraints & Assumptions
- **Constraint:** The `RecordWidget` must remain a "dumb" component (receiving data via its constructor) to ensure maximum reusability.
- **Assumption:** The `RecordRepository` provides accurate totals for money sources and records. If these totals are incorrect, the UI will reflect those errors.

## Out of Scope
- Implementation of new record filters or search functionality.
- Database schema migrations or changes to how records are stored.
- Redesigning the chat bubble structure itself (outside of the record item content).

## Dependencies
- `provider` — Used for state management to fetch data for the overview.
- `Record` / `MoneySource` models — The foundation for the new components.
- `RecordRepository` — Source of truth for financial data.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3]
  nice_to_have: [NTH-1]
  nfr: [NFR-1, NFR-2]
scale: medium
discovery_mode: full
validation_status: pending
last_validated: null
