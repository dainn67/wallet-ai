---
name: add-sub-category
description: Implement a two-level hierarchical categorization system with parentId, ExpansionTile UI, and updated AI prompt mapping.
status: backlog
priority: P1
scale: medium
created: 2026-03-27T08:34:21Z
updated: null
---

# PRD: add-sub-category

## Executive Summary
This feature introduces a nested (Parent → Sub) category system to provide users with more granular control over their financial tracking. We will update the `Category` model and SQLite schema to include a `parentId` field (defaulting to -1 for parent categories). The Categories tab will be refactored to use `ExpansionTile` for displaying sub-categories, including an "Add Sub-category" button within each expanded tile. The AI prompt logic will also be updated to understand the hierarchy and map transactions directly to sub-category IDs when possible, displaying them as "Parent - Sub" in the UI.

## Problem Statement
The current flat category system lacks the necessary depth for users who want to track specific spending habits (e.g., distinguishing between "Groceries" and "Dining Out" within a broader "Food" category). This makes financial summaries less actionable. Without a parent-child relationship, the list of categories could also become cluttered as more options are added.

## Target Users
| Role | Context | Primary Need | Pain Level |
| ---- | ------- | ------------ | ---------- |
| Specialist | Detailed budgeting | To see exactly where money goes within a broad category (e.g., "Transport - Fuel"). | High |
| Organizer | Clean UI | To group related categories together and keep the main list tidy. | Medium |
| AI Assistant | Transaction classification | To accurately categorize records based on specific sub-category contexts. | Medium |

## User Stories
**US-1: Hierarchical Organization**
As a user, I want to group related sub-categories under a parent category so that I can organize my finances more logically.

Acceptance Criteria:
- [ ] A `parentId` field exists in the `Category` table.
- [ ] Parent categories have `parentId = -1`.
- [ ] Sub-categories reference their parent's `categoryId`.

**US-2: Nested UI Interaction**
As a user, I want to expand a parent category in the Categories tab to see its sub-categories and add new ones.

Acceptance Criteria:
- [ ] Categories tab uses `ExpansionTile` for parent categories.
- [ ] Expanding a tile reveals a list of its sub-categories.
- [ ] The last item in the expanded list is an "Add Sub-category" button.

**US-3: AI-Powered Sub-categorization**
As a user, I want the AI to automatically identify the most appropriate sub-category for my transaction.

Acceptance Criteria:
- [ ] AI prompt includes a hierarchical list of parent and sub-categories.
- [ ] AI returns the specific sub-category ID (or parent ID if no sub-category exists).
- [ ] Records display as "Parent - Sub" (e.g., "Food - Restaurant") in the transaction list.

## Requirements

### Functional Requirements (MUST)

**FR-1: Database & Model Update**
Update the `Category` model and SQLite schema to include `parentId` (Integer).
Scenario: Adding a sub-category
- GIVEN A parent category "Food" (ID: 5).
- WHEN A user adds "Restaurant" as a sub-category.
- THEN The new record is saved with `parentId = 5`.

**FR-2: Seed Default Hierarchy**
Seed the database with the following structure:
1. **Food** (Restaurant, Groceries, Coffee)
2. **Transport** (Fuel, Taxi/Grab, Maintenance)
3. **Shopping** (Clothing, Electronics, Home Decor)
4. **Entertainment** (Movies, Gaming, Concerts)
5. **Health** (Pharmacy, Doctor, Gym)
6. **Bills** (Electricity, Water, Internet, Rent)
7. **Salary** (Base, Bonus)
8. **Uncategorized** (No sub-categories)

**FR-3: Categories Tab Refactor**
Replace the flat list with a nested `ExpansionTile` structure.
Scenario: Viewing sub-categories
- GIVEN The user opens the Categories tab.
- WHEN They tap on "Food".
- THEN The tile expands to show "Restaurant", "Groceries", "Coffee", and an "Add Sub-category" button.

**FR-4: AI Prompt Hierarchy**
Update the AI service to include the parent-sub structure in its system prompt.
Scenario: AI classification
- GIVEN User says "I spent 50k on a burger".
- WHEN AI processes the message.
- THEN AI returns the ID for "Food - Restaurant" (sub-category).

**FR-5: Display Logic**
Update `RecordProvider` and UI components to display the full hierarchical name.
Scenario: Displaying transaction
- GIVEN A record linked to sub-category "Restaurant" (Parent: "Food").
- THEN The UI displays "Food - Restaurant" as the category name.

### Functional Requirements (NICE-TO-HAVE)
- **NTH-1: Bulk Move** — Option to move all records from one sub-category to another during deletion.

### Non-Functional Requirements
**NFR-1: Performance**
Rendering the `ExpansionTile` list must be smooth (60fps) even with 20+ sub-categories per parent.
**NFR-2: AI Accuracy**
The AI should correctly map 90%+ of clear descriptions to the correct sub-category when provided in the prompt.

## Success Criteria
- [ ] All seeded categories follow the Parent-Sub hierarchy.
- [ ] User can add a custom sub-category via the Categories tab.
- [ ] Records are displayed as "Parent - Sub" in both the chat and transaction list.
- [ ] AI correctly identifies and assigns sub-category IDs.

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| ---- | -------- | ---------- | ---------- |
| AI ID Confusion | Medium | Medium | Use explicit "ID: Name (Parent: ParentName)" formatting in the prompt. |
| DB Migration Issues | High | Low | Ensure `parentId` defaults to -1 for all existing records if a migration is needed. |
| UI Overflow | Low | Medium | Ensure "Parent - Sub" text is truncated or wrapped gracefully. |

## Constraints & Assumptions
- **Constraints:** Maximum 2 levels of hierarchy (Parent and Sub).
- **Assumptions:** Users prefer seeing the full path (Parent - Sub) for clarity.

## Out of Scope
- Infinite nesting levels.
- Reassigning a sub-category to a different parent.
- UI for managing parents (adding/deleting parents) - focus is on sub-categories first.

## Dependencies
- **RecordRepository**: Needs schema update and hierarchical query support.
- **AI Service**: Needs prompt template update.

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
