---
name: refactor-ui-components
status: completed
created: 2026-03-20T03:48:00Z
progress: 100%
priority: P1
prd: .claude/prds/refactor-ui-components.md
task_count: 5
github: "https://github.com/dainn67/wallet-ai/issues/69"
updated: 2026-03-20T04:26:00Z
completed: 2026-03-20T04:26:00Z
---

# Epic: refactor-ui-components

## Overview
This epic implements a cleaner, more maintainable UI structure by extracting duplicated record display logic into a reusable `RecordWidget` and redesigning the `RecordsTab` overview. We adopt a "dumb component" pattern for the `RecordWidget` to ensure it can be safely used in different layout contexts (chat bubbles vs. full-width lists) without side effects. The redesign leverages Material 3 `Card` and horizontal `ListView` to improve financial data visualization.

## Architecture Decisions

### AD-1: "Dumb" RecordWidget Pattern
**Context:** Record display logic is currently coupled with screen-specific code in `ChatTab` and `RecordsTab`.
**Decision:** Extract `RecordWidget` as a stateless, "dumb" component that receives a `Record` model and an optional `onTap` callback.
**Alternatives rejected:** A "smart" component that fetches its own data would make it harder to reuse inside the `ChatProvider`'s message stream.
**Trade-off:** Requires parent widgets to pass the full `Record` model, but ensures predictable rendering and easy testing.
**Reversibility:** Easy - the widget can be made "smarter" later if needed without changing its visual structure.

### AD-2: Horizontal Source List Implementation
**Context:** The PRD requires a horizontal list of money sources in the redesigned overview.
**Decision:** Use `ListView.builder` with `scrollDirection: Axis.horizontal` inside a fixed-height container. Each source will be represented by a Material 3 `Card`.
**Alternatives rejected:** A `SingleChildScrollView` with a `Row` is simpler but less performant for many sources.
**Trade-off:** Slightly more boilerplate but follows Flutter best practices for lists.
**Reversibility:** Moderate - changing the layout structure would require refactoring the overview card's `Column`.

## Technical Approach

### lib/components/ (New Directory)
- Create `record_widget.dart`: A stateless widget that takes a `Record` model.
- Create `records_overview.dart`: A stateless widget that takes total balance, income, expenses, and a list of `MoneySource` objects.
- Create `components.dart`: A barrel file for easy imports.

### lib/screens/home/tabs/
- **chat_tab.dart**: Replace `_buildRecordCard` with `RecordWidget`. Ensure the widget is wrapped in `Flexible` or `ConstrainedBox` to prevent overflows within `ChatBubble`.
- **records_tab.dart**: Replace the inline overview card and the record list items with `RecordsOverview` and `RecordWidget` respectively.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: RecordWidget | `lib/components/record_widget.dart` | T1, T2 | Unit test + Manual check in Chat/History |
| FR-2: Horizontal Source List | `lib/components/records_overview.dart` | T3 | Manual check with multiple sources |
| FR-3: Summary Stats | `lib/components/records_overview.dart` | T3 | Verify totals match provider data |
| NFR-1: Visual Consistency | All components | T1, T3 | Style audit against M3 standards |
| NFR-2: Layout Robustness | `RecordWidget` | T1, T2 | Overflow test with long descriptions |

## Implementation Strategy
### Phase 1: Foundation
Extract the `RecordWidget` and establish the `components` directory. This is the critical path as it removes the primary source of duplication.
- **Exit Criterion:** `RecordWidget` exists and is visually consistent with the current design.

### Phase 2: Core Refactor
Integrate `RecordWidget` into `ChatTab` and `RecordsTab`.
- **Exit Criterion:** All records in the app are rendered using the new component.

### Phase 3: Redesign
Implement the `RecordsOverview` with the horizontal source list and summarized stats.
- **Exit Criterion:** `RecordsTab` matches the new design requirements.

## Task Breakdown

##### T1: Create RecordWidget Component
- **Phase:** 1 | **Parallel:** no | **Est:** 1d | **Depends:** — | **Complexity:** simple
- **What:** Create `lib/components/record_widget.dart` as a stateless widget. Implement the UI based on the current `ChatBubble._buildRecordCard` but with Material 3 enhancements (better spacing, typography from `GoogleFonts.poppins`). Use `TextOverflow.ellipsis` for descriptions.
- **Key files:** `lib/components/record_widget.dart`, `lib/components/components.dart`
- **PRD requirements:** FR-1, NFR-1, NFR-2
- **Key risk:** Slight visual regression if padding/margins aren't perfectly matched.

##### T2: Integrate RecordWidget in Chat and History
- **Phase:** 2 | **Parallel:** yes | **Est:** 1d | **Depends:** T1 | **Complexity:** simple
- **What:** Update `lib/screens/home/tabs/chat_tab.dart` and `lib/screens/home/tabs/records_tab.dart` to use the new `RecordWidget`. Remove the old `_buildRecordCard` method from `ChatTab`. Ensure layout stability in `ChatBubble`.
- **Key files:** `lib/screens/home/tabs/chat_tab.dart`, `lib/screens/home/tabs/records_tab.dart`
- **PRD requirements:** FR-1, US-1
- **Key risk:** Layout overflows in the restricted width of chat bubbles.

##### T3: Implement Redesigned RecordsOverview
- **Phase:** 3 | **Parallel:** no | **Est:** 2d | **Depends:** — | **Complexity:** moderate
- **What:** Create `lib/components/records_overview.dart`. Implement a horizontal scrolling list of `MoneySource` cards followed by total income/expense summaries. Use the dark gradient theme from the current design but refine with M3 `Card` or `Container` styling.
- **Key files:** `lib/components/records_overview.dart`, `lib/components/components.dart`
- **PRD requirements:** FR-2, FR-3, US-2
- **Key risk:** Handling the transition between the horizontal list and the vertical summary stats cleanly.

##### T4: Verification and Final Polish
- **Phase:** 3 | **Parallel:** yes | **Est:** 1d | **Depends:** T2, T3 | **Complexity:** simple
- **What:** Perform a final audit of the UI on different screen sizes. Ensure all colors and fonts match the project's branding. Add a simple fade-in animation to `RecordWidget` if `NTH-1` is pursued.
- **Key files:** `lib/components/record_widget.dart`, `lib/screens/home/tabs/records_tab.dart`
- **PRD requirements:** NFR-1, NTH-1
- **Key risk:** Small UI glitches during screen resizing or orientation changes.

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Overflow in Chat Bubbles | High | Medium | Ugly UI/Crashing | Use `Flexible` and `TextOverflow.ellipsis` inside `RecordWidget`. |
| Breaking Chat Message Flow | Medium | Low | Record items missing in chat | Thorough manual testing of AI record generation flow. |
| Inconsistent Spacing | Low | Medium | Unpolished feel | Use a consistent `SizedBox` or `Padding` scale (e.g., 4, 8, 12, 16). |

## Dependencies
- `Record` / `MoneySource` models (Internal)
- `RecordProvider` for data (Internal)
- `google_fonts` (External)

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Eliminate Duplication | LOC reduction in tabs | >30 lines removed | Git diff check on `chat_tab.dart` and `records_tab.dart`. |
| M3 Consistency | Theme usage | 100% Theme.of usage | Static analysis/Code review. |
| Scrolling Performance | Frame rate | 60 FPS | Flutter DevTools performance overlay. |

## Estimated Effort
- **Total Estimate:** 5 days
- **Critical Path:** T1 → T2 → T4
- **Phases Timeline:** Phase 1 (1d), Phase 2 (1d), Phase 3 (3d)

## Tasks Created
| #   | Task                     | Phase | Parallel | Est. | Depends On | Status |
| --- | ------------------------ | ----- | -------- | ---- | ---------- | ------ |
| 70 | Create RecordWidget      | 1     | no       | 1d   | —          | open   |
| 71 | Integrate in Chat        | 2     | yes      | 1d   | 70        | open   |
| 72 | Integrate in History     | 2     | yes      | 1d   | 70        | open   |
| 73 | Redesign Overview        | 3     | no       | 2d   | —          | open   |
| 74 | Integration Verification | 3     | no       | 1d   | 010,011,020| open   |

### Summary
- **Total tasks:** 5
- **Parallel tasks:** 2 (Phase 2)
- **Sequential tasks:** 3 (Phase 1 + 3)
- **Estimated total effort:** 6d
- **Critical path:** T70 → T71/T72 → T74 (~3-4d)

### Dependency Graph
```
Dependency Graph:
  T70 ──→ T71 (parallel) ─→ T74
       ──→ T72 (parallel) ─→ T74
  T73 ──────────────────→ T74
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: RecordWidget | T70, T71, T72 | ✅ Covered |
| FR-2: Horizontal Source List | T73 | ✅ Covered |
| FR-3: Summary Stats | T73 | ✅ Covered |
| NFR-1: Visual Consistency | All tasks | ✅ Covered |
| NFR-2: Layout Robustness | T70, T71 | ✅ Covered |
| US-1: Consistent Record View | T71, T72 | ✅ Covered |
| US-2: Clear Source Overview | T73 | ✅ Covered |
