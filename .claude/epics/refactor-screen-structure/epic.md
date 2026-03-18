---
name: refactor-screen-structure
status: backlog
created: 2026-03-18T12:05:00Z
progress: 0%
priority: P1
prd: .claude/prds/refactor-screen-structure.md
task_count: 5
github: "https://github.com/dainn67/wallet-ai/issues/44"
---

# Epic: refactor-screen-structure

## Overview
This epic decomposes the monolithic `chat_screen.dart` into a modular architecture. We are introducing a `lib/screens/home/` directory for high-level navigation and a `tabs/` subdirectory for feature-specific UI. This approach improves code maintainability and readability by separating the Chat, Records, and Test domains into their own files. We will use the existing `TabBarView` pattern to ensure zero logic changes and a seamless transition.

## Architecture Decisions
### AD-1: Directory-based Organization
**Context:** The current structure has all screen logic in a single file (`chat_screen.dart`).
**Decision:** Organize screens by feature/domain folder.
**Alternatives rejected:** Keeping a single `screens/` folder with flat files (doesn't scale for complex apps).
**Trade-off:** Slightly more files to manage, but significantly better isolation.
**Reversibility:** Easy to move files back if needed.

### AD-2: Local Feature Helpers
**Context:** `chat_screen.dart` has many private helper methods (e.g., `_buildInputArea`).
**Decision:** Move these helpers into the specific tab files where they are used.
**Alternatives rejected:** Creating a global `widgets/` folder for these (rejected because they are currently specific to these tabs and we want to avoid over-engineering).
**Trade-off:** Keeps the logic close to the UI, but might lead to duplication if another screen needs the same widget later.
**Reversibility:** Easy to extract to shared widgets if needed.

## Technical Approach
### Navigation Layer
- **HomeScreen**: A new `StatefulWidget` in `lib/screens/home/home_screen.dart` that manages the `DefaultTabController`, `AppBar`, `Drawer`, and `TabBarView`.
- **Imports**: Updates to `lib/screens/screens.dart` to export the new `HomeScreen` and remove `ChatScreen`.

### Feature Tabs
- **ChatTab**: Extract `_ChatTabContent`, `_ChatScreenState._buildInputArea`, `_ChatScreenState._handleSend`, `ChatBubble`, and `_StreamingIndicator` into `lib/screens/home/tabs/chat_tab.dart`.
- **RecordsTab**: Extract `_RecordsTabContent` and its sub-widgets into `lib/screens/home/tabs/records_tab.dart`.
- **TestTab**: Extract `_TestTabContent` and demo data methods into `lib/screens/home/tabs/test_tab.dart`.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Home Screen Container | §Navigation Layer | T1 | Manual navigation check |
| FR-2: Tab Feature Extraction | §Feature Tabs | T2, T3, T4 | UI consistency check |
| FR-3: Export & Import Alignment | §Navigation Layer | T5 | App builds and runs |
| NFR-1: Build Integrity | Task Verification | T1-T5 | `fvm flutter test` |
| NFR-2: Logic Parity | Task Implementation | T1-T5 | Manual functional test |

## Implementation Strategy
### Phase 1: Foundation
Create the new folder structure and the `HomeScreen` shell.
### Phase 2: Feature Migration
Extract the individual tabs and their associated logic/widgets.
### Phase 3: Integration & Cleanup
Update the main app entry point and remove the deprecated `chat_screen.dart`.

## Task Breakdown

##### T1: Scaffold Home Screen
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Create `lib/screens/home/home_screen.dart` and implement the basic structure with `AppBar`, `Drawer`, and `TabBarView`. Use placeholders for the tab contents.
- **Key files:** `lib/screens/home/home_screen.dart`
- **PRD requirements:** FR-1
- **Key risk:** Initial build might fail until tab placeholders are added.

##### T2: Extract Chat Tab
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Move all chat-related UI logic from `chat_screen.dart` to `lib/screens/home/tabs/chat_tab.dart`. Include `_ChatTabContent`, bubble widgets, and input area helpers.
- **Key files:** `lib/screens/home/tabs/chat_tab.dart`
- **PRD requirements:** FR-2
- **Key risk:** Missing helper methods or private state variables from the original `ChatScreen`.

##### T3: Extract Records Tab
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1 | **Complexity:** simple
- **What:** Move all record-related UI logic to `lib/screens/home/tabs/records_tab.dart`.
- **Key files:** `lib/screens/home/tabs/records_tab.dart`
- **PRD requirements:** FR-2
- **Key risk:** Broken references to `RecordProvider` if imports are not handled.

##### T4: Extract Test Tab
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1 | **Complexity:** simple
- **What:** Move the developer test tab and demo data generation logic to `lib/screens/home/tabs/test_tab.dart`.
- **Key files:** `lib/screens/home/tabs/test_tab.dart`
- **PRD requirements:** FR-2
- **Key risk:** None.

##### T5: Integration and Cleanup
- **Phase:** 3 | **Parallel:** no | **Est:** 0.5d | **Depends:** T2, T3, T4 | **Complexity:** simple
- **What:** Update `lib/screens/screens.dart` to export `HomeScreen`, update `lib/main.dart` to use `HomeScreen`, and delete `lib/screens/chat_screen.dart`.
- **Key files:** `lib/screens/screens.dart`, `lib/main.dart`
- **PRD requirements:** FR-3
- **Key risk:** Catch-all for any missed imports across the project.

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Private State Access | Medium | Medium | Chat scroll/input state lost | Ensure `TextEditingController` and `ScrollController` are managed correctly in the new `ChatTab` state. |
| Broken Imports | Low | High | App won't compile | Use the `screens.dart` barrel file and fix all red squiggles before finalizing. |
| Logic Accidental Change | Medium | Low | App behavior changes | Strict "copy-paste" policy for logic, followed by manual functional verification. |

## Dependencies
- None.

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Zero lint errors | Static analysis | 0 errors | `fvm flutter analyze` |
| Functional Parity | Manual check | 100% | Compare Chat/Records behavior with previous version |
| Successful Build | Compilation | Success | `fvm flutter run` |

## Tasks Created
| #   | Task                         | Phase | Parallel | Est. | Depends On | Status |
| --- | ---------------------------- | ----- | -------- | ---- | ---------- | ------ |
| 001 | Scaffold Home Screen         | 1     | no       | 0.5d | —          | open   |
| 010 | Extract Chat Tab             | 2     | yes      | 1d   | 001        | open   |
| 011 | Extract Records Tab          | 2     | yes      | 0.5d | 001        | open   |
| 012 | Extract Test Tab             | 2     | yes      | 0.5d | 001        | open   |
| 020 | Integration and Cleanup      | 3     | no       | 0.5d | 010,011,012| open   |
| 090 | Integration verification     | 3     | no       | 0.5d | all        | open   |

### Summary
- **Total tasks:** 6
- **Parallel tasks:** 3 (Phase 2)
- **Sequential tasks:** 3 (Phase 1 + 3)
- **Estimated total effort:** 3.5d
- **Critical path:** T001 → T010 → T020 → T090 (~2.5d)

### Dependency Graph
```
  T001 ──→ T010 (parallel) ──→ T020 ──→ T090
       ──→ T011 (parallel) ──→ T020
       ──→ T012 (parallel) ──→ T020
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: [name]    | T001       | ✅ Covered |
| FR-2: [name]    | T010, T011, T012 | ✅ Covered |
| FR-3: [name]    | T020       | ✅ Covered |
| NFR-1: [name]   | T090       | ✅ Covered |
| NFR-2: [name]   | T090       | ✅ Covered |
