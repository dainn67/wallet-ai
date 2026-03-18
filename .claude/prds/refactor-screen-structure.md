---
name: refactor-screen-structure
description: Reorganize monolithic screen structure into a clean, tab-based home folder architecture.
status: complete
priority: P1
scale: small
created: 2026-03-18T12:00:00Z
updated: null
---

# PRD: refactor-screen-structure

## Executive Summary
We are refactoring the current monolithic `chat_screen.dart` into a cleaner, more maintainable structure. The goal is to move the core navigation container into `lib/screens/home/home_screen.dart` and split the individual features (Chat, Records, Test) into dedicated tab files within `lib/screens/home/tabs/`. This ensures better separation of concerns and aligns with the project's "clean structure" goals without altering any underlying logic.

## Problem Statement
The current `chat_screen.dart` is a single file exceeding 400 lines that handles three distinct app domains: AI Chat, Financial Records, and Developer Testing. This monolithic approach makes it difficult for developers to locate feature-specific code, increases the risk of merge conflicts, and complicates future feature expansion. The lack of directory-based organization for screens prevents the project from scaling cleanly.

## Target Users
| Role | Context | Primary Need | Pain Level |
| ---- | ------- | ------------ | ---------- |
| Developer | Maintaining or extending features | Ability to find feature-specific UI code quickly without wading through unrelated logic. | Medium |
| Architect | Reviewing code structure | Ensuring the codebase follows clean separation of concerns and modularity. | Medium |

## User Stories
**US-1: Modular Tab Management**
As a developer, I want each tab's content to live in its own file so that I can modify the Chat or Records UI independently without touching other screens.

Acceptance Criteria:
- [ ] Each tab content is moved to its own file in `lib/screens/home/tabs/`.
- [ ] Logic for sending messages and rendering bubbles is encapsulated within `chat_tab.dart`.
- [ ] Logic for record listing and demo data is encapsulated within their respective tab files.

## Requirements
### Functional Requirements (MUST)

**FR-1: Home Screen Container**
Create `lib/screens/home/home_screen.dart` to serve as the new parent container for app navigation.

Scenario: Tab Navigation
- GIVEN the user is on the HomeScreen
- WHEN they swipe or tap a tab
- THEN the corresponding feature tab (Chat, Records, or Test) is displayed using `TabBarView`.

**FR-2: Tab Feature Extraction**
Extract existing content from `_ChatTabContent`, `_RecordsTabContent`, and `_TestTabContent` into individual files.

Scenario: File Organization
- GIVEN the new structure
- WHEN looking for Chat UI
- THEN it is found in `lib/screens/home/tabs/chat_tab.dart`.

**FR-3: Export & Import Alignment**
Update `lib/screens/screens.dart` and `lib/main.dart` to point to the new `HomeScreen`.

Scenario: App Entry
- GIVEN the app starts
- WHEN `MaterialApp` initializes
- THEN it loads `HomeScreen` as the default `home` widget.

### Functional Requirements (NICE-TO-HAVE)
- N/A for this small-scale refactor.

### Non-Functional Requirements
**NFR-1: Build Integrity**
The refactor must not introduce any compilation errors or break existing widget tests.

**NFR-2: Logic Parity**
No business logic (Provider calls, data transformations) should be altered during the move.

## Success Criteria
- [ ] Codebase has zero lint errors related to new file imports.
- [ ] `HomeScreen` successfully hosts all three tabs.
- [ ] The app's functional behavior remains identical to the pre-refactor state.

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| ---- | -------- | ---------- | ---------- |
| Broken Imports | Low | High | Use the `screens.dart` barrel file to manage exports centrally. |
| Loss of State | Low | Low | User confirmed rebuilding app is acceptable; logic is preserved in Providers. |

## Constraints & Assumptions
- **Constraints:** Must use `TabBarView` as requested by the user.
- **Assumptions:** Rebuilding the app is acceptable to the user; state preservation (KeepAlive) is not a priority for this iteration.

## Out of Scope
- Introducing new navigation patterns (e.g., BottomNavigationBar).
- Refactoring `ChatProvider` or `RecordProvider` logic.
- Adding new UI features or animations.

## Dependencies
- None.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3]
  nice_to_have: []
  nfr: [NFR-1, NFR-2]
scale: small
discovery_mode: full
validation_status: pending
last_validated: null
