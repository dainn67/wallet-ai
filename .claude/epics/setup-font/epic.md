---
name: setup-font
status: backlog
created: 2026-03-21T10:05:00Z
progress: 0%
priority: P1
prd: .claude/prds/setup-font.md
task_count: 2
github: "https://github.com/dainn67/wallet-ai/issues/81"
---

# Epic: setup-font

## Overview
This epic handles the complete removal of the `google_fonts` package and the registration of local Poppins font assets. By hosting fonts locally, we eliminate network latency on first load and provide full offline support. The architectural approach is to register all Poppins weights in `pubspec.yaml` and set Poppins as the global `fontFamily` in the app's `ThemeData`, allowing us to replace widget-level `GoogleFonts` calls with standard `TextStyle` or let them inherit the global default.

## Technical Approach
### Asset Registration
- Map all 18 Poppins TTF files in `assets/fonts/` to the `Poppins` family in `pubspec.yaml`.
- Ensure correct weight mapping (e.g., Black=900, Bold=700, Light=300, etc.) and italic styles.

### Global Theme
- Update `lib/main.dart` to set `fontFamily: 'Poppins'` in `ThemeData`.
- Remove `GoogleFonts.poppinsTextTheme` and replace with standard `Theme.of(context).textTheme`.

### UI Refactoring
- Perform a global search and replace of `GoogleFonts.poppins(...)` with `TextStyle(...)`.
- Since the global `fontFamily` is set to Poppins, explicitly specifying `fontFamily` in each `TextStyle` is not strictly necessary but can be done for clarity or safety during the transition.
- Remove all `import 'package:google_fonts/google_fonts.dart';` statements.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Register Local Font Assets | §Technical Approach / Asset Registration | T1 | `pubspec.yaml` check |
| FR-2: Set Global Default Font | §Technical Approach / Global Theme | T2 | UI visual check |
| FR-3: Remove google_fonts | §Technical Approach / UI Refactoring | T2 | Compilation check |
| NFR-1: Fast Load Time | §Overview | T2 | Manual launch check |

## Implementation Strategy
### Phase 1: Foundation
Register the font assets in `pubspec.yaml` so they are available to the Flutter engine. Verify that the files are correctly linked.
### Phase 2: Core Refactor
Update the global theme and refactor all UI components to use standard `TextStyle`. Remove the `google_fonts` dependency once all references are gone.

## Task Breakdown

##### T1: Register Poppins Fonts & Verify Assets
- **Phase:** 1 | **Parallel:** no | **Est:** 0.5d | **Depends:** — | **Complexity:** simple
- **What:** Add the `fonts` section to `pubspec.yaml`. List all Poppins TTF files from `assets/fonts/` with their respective weights and styles. Run `fvm flutter pub get` to verify.
- **Key files:** `pubspec.yaml`
- **PRD requirements:** FR-1
- **Key risk:** Incorrect weight mapping causing subtle weight mismatches in the UI.

##### T2: Global Theme Update & UI Refactoring
- **Phase:** 2 | **Parallel:** no | **Est:** 1d | **Depends:** T1 | **Complexity:** moderate
- **What:** Update `lib/main.dart` to use `fontFamily: 'Poppins'`. Replace all `GoogleFonts.poppins(...)` with `TextStyle(...)` across the codebase. Remove `google_fonts` from `pubspec.yaml` and remove all imports.
- **Key files:** `lib/main.dart`, all `lib/**/*.dart` files using GoogleFonts
- **PRD requirements:** FR-2, FR-3, NFR-1
- **Key risk:** Missing a specific `GoogleFonts` override that defaults to a different font weight than intended.

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| UI Visual Regression | Low | Medium | Weights/styles look different | Perform a thorough visual audit of all screens against the current version. |
| Compilation Errors | Low | Low | App won't build | Ensure all `google_fonts` imports are removed before final dependency removal. |
| Path Errors | Low | Low | Fonts not found | Use exact paths in `pubspec.yaml` and check logs for "Font asset not found" warnings. |

## Tasks Created
| #   | Task                     | Phase | Parallel | Est. | Depends On | Status | Issue |
| --- | ------------------------ | ----- | -------- | ---- | ---------- | ------ | ----- |
| 001 | Register Poppins Fonts   | 1     | no       | 0.5d | —          | open   | #82   |
| 002 | Global Theme & UI Refact | 2     | no       | 1d   | 001        | open   | #83   |

### Summary
- **Total tasks:** 2
- **Parallel tasks:** 0
- **Sequential tasks:** 2
- **Estimated total effort:** 1.5d
- **Critical path:** T001 → T002 (~1.5d)

### Dependency Graph
```
Dependency Graph:
  T001 ──→ T002
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: Register Assets | T001       | ✅ Covered |
| FR-2: Global Theme    | T002       | ✅ Covered |
| FR-3: Remove Library  | T002       | ✅ Covered |
| NFR-1: Performance    | T002       | ✅ Covered |
