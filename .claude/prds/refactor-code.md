---
name: refactor-code
description: Audit and refactor entire codebase to enforce clean architecture — separate concerns, clean providers, correct file structure.
status: complete
priority: P1
scale: large
created: 2026-03-28T16:47:54Z
updated: 2026-03-29T04:32:29Z
---

# PRD: refactor-code

## Executive Summary

We are refactoring the wallet-ai Flutter codebase to enforce clean architecture principles across all layers. Currently, business logic leaks into UI components, repositories are sometimes accessed directly from screens, provider logic contains redundancies, and file structure is inconsistent. This refactor ensures every layer has a single clear responsibility — UI renders, providers manage state and orchestrate logic, repositories handle data persistence, and services provide stateless utilities — so that future feature development is faster, less error-prone, and consistent.

## Problem Statement

As the app has grown through rapid feature development (categories, records, chat, sources, home widget), architectural shortcuts have accumulated:

1. **Logic in UI:** Screen tabs and popup components contain business logic (filtering, validation, data transformation) that should live in providers or helper functions. This makes components hard to test and reuse.
2. **Direct repository access:** Some UI components bypass providers and call repositories directly, creating inconsistent data flow and making it unclear where state changes originate.
3. **Redundant provider logic:** Providers contain duplicated or overlapping methods that could be consolidated, increasing maintenance burden and risk of divergent behavior.
4. **Inconsistent coding style:** Different files follow different patterns for similar operations (e.g., error handling, data loading, state notification).
5. **File structure gaps:** The current `lib/` structure is reasonable but doesn't fully align with clean architecture conventions — missing clear separation between domain and data layers.

**Cost of inaction:** Every new feature built on the current structure compounds the debt. Logic scattered across layers means bugs are harder to trace, changes require touching multiple files unnecessarily, and onboarding to any area of the code requires understanding implicit dependencies.

## Target Users

**Developer (Solo)**
- **Context:** Building and maintaining the wallet-ai app end-to-end
- **Primary need:** A codebase where each file has a clear, single responsibility and follows predictable patterns — so any area can be modified confidently
- **Pain level:** High — current inconsistencies slow down feature development and increase risk of regressions

**Future Contributors**
- **Context:** Any developer who may contribute to or review the codebase in the future
- **Primary need:** Understandable, conventional architecture that doesn't require tribal knowledge
- **Pain level:** Medium — would face steep learning curve with current implicit patterns

## User Stories

**US-1: Clean provider access pattern**
As a developer, I want all repository calls to go through providers so that I have a single, predictable data flow to debug and extend.

Acceptance Criteria:
- [ ] No screen, tab, or component file imports or calls any repository directly
- [ ] All data operations (CRUD) are exposed through provider methods
- [ ] Simple, stateless utility calls (e.g., formatting, conversion) may use services/helpers directly from UI

**US-2: Logic-free UI components**
As a developer, I want UI components to contain only rendering logic so that I can modify presentation without risk of breaking business rules.

Acceptance Criteria:
- [ ] No business logic (filtering, validation, data transformation, conditional business rules) exists inline in widget build methods
- [ ] Complex logic is extracted to provider methods or standalone helper functions
- [ ] UI components delegate all state mutations to providers

**US-3: Clean provider implementations**
As a developer, I want providers to have no redundant or overlapping methods so that each operation has exactly one code path.

Acceptance Criteria:
- [ ] No duplicate methods that perform the same operation with minor variations
- [ ] Shared logic is extracted to private helper methods within the provider
- [ ] Each provider method has a clear, single responsibility

**US-4: Consistent coding style**
As a developer, I want all files to follow the same coding patterns so that I can read and modify any file without context-switching between styles.

Acceptance Criteria:
- [ ] Consistent error handling pattern across all providers and services
- [ ] Consistent state notification pattern (notifyListeners usage) across providers
- [ ] Consistent import organization and file structure within each layer

**US-5: Clean architecture file structure**
As a developer, I want the file structure to clearly reflect clean architecture layers so that I can locate any piece of logic by its responsibility.

Acceptance Criteria:
- [ ] Each directory corresponds to a single architectural layer
- [ ] No file is in the wrong layer (e.g., no business logic files in components/)
- [ ] Barrel files (e.g., models.dart, services.dart) are up-to-date and consistent

**US-6: Navigable codebase for new contributors**
As a future contributor, I want the codebase to follow a conventional clean architecture so that I can understand where to find and place any piece of logic without asking questions.

Acceptance Criteria:
- [ ] Each `lib/` directory has a single, documented architectural role
- [ ] No file is misplaced in the wrong layer
- [ ] Patterns are consistent enough that any file in a directory can serve as a template for similar files in that directory

## Requirements

### Functional Requirements (MUST)

**FR-1: Enforce provider-only repository access**
All repository interactions must be routed through providers. No UI layer file (screens, tabs, components, popups) may import or invoke repository classes directly.

Scenario: Repository access audit
- GIVEN the entire lib/ codebase
- WHEN scanning all files in screens/, components/ directories
- THEN zero files import from repositories/

Scenario: Data operation through provider
- GIVEN a UI component that currently calls a repository directly
- WHEN refactored
- THEN the component calls the corresponding provider method, which internally calls the repository

**FR-2: Extract business logic from UI components**
All business logic (filtering, validation, data transformation, conditional rules) must be removed from widget build methods and extracted to providers or helper functions.

Scenario: Logic extraction from popup
- GIVEN edit_record_popup.dart contains inline validation or data transformation logic
- WHEN refactored
- THEN validation/transformation logic lives in a provider method or helper function, and the popup only calls that method

Scenario: Logic extraction from tab
- GIVEN categories_tab.dart contains filtering or sorting logic inline
- WHEN refactored
- THEN filtering/sorting is handled by the provider or a helper, and the tab only renders the result

**FR-3: Consolidate redundant provider logic**
Identify and merge duplicate or overlapping methods within and across providers. Extract shared patterns into private helpers.

Scenario: Duplicate method consolidation
- GIVEN record_provider.dart has two methods that perform similar record filtering with minor variations
- WHEN refactored
- THEN a single parameterized method replaces both, with no change to external behavior

Scenario: Cross-provider shared logic
- GIVEN multiple providers implement the same utility pattern (e.g., error handling, loading state management)
- WHEN refactored
- THEN shared patterns are consolidated (via private helpers, base class, or mixin as appropriate), reducing duplication with no change to external behavior

**FR-4: Standardize coding style across all files**
Apply consistent patterns for: error handling, state notification, async operations, import organization, and method ordering. Error handling convention: `try-catch → set error state field → call notifyListeners()`. Import ordering convention: `dart:` → `package:` → relative imports, each group separated by a blank line.

Scenario: Consistent error handling
- GIVEN provider methods handle errors with different patterns (some try-catch, some silent, some rethrow)
- WHEN refactored
- THEN all provider methods follow the same error handling convention

Scenario: Consistent imports
- GIVEN files use mixed import styles (relative vs package, unordered)
- WHEN refactored
- THEN all files use a consistent import organization (dart:, package:, relative — grouped and sorted)

**FR-5: Align file structure with clean architecture**
Validate and correct the directory structure. Ensure each file is in the correct layer. Update barrel files to reflect current contents.

Scenario: File placement audit
- GIVEN the lib/ directory structure
- WHEN auditing each file's contents against its directory's responsibility
- THEN every file resides in the directory matching its architectural role

Scenario: Barrel file consistency
- GIVEN barrel files (models.dart, services.dart, etc.) exist in each directory
- WHEN checking exports against actual files in the directory
- THEN every public file is exported and no removed files are referenced

**FR-6: Preserve all existing behavior**
Every refactored file must produce identical runtime behavior. No UI changes, no logic changes — only structural reorganization.

Scenario: Behavior preservation
- GIVEN any screen or feature in the app
- WHEN exercised after refactoring
- THEN the behavior is identical to pre-refactor (same data displayed, same interactions, same error handling)

Scenario: No regression in data flow
- GIVEN the record creation flow (chat → provider → repository → database)
- WHEN exercised after refactoring
- THEN records are created, stored, and displayed identically to pre-refactor

### Functional Requirements (NICE-TO-HAVE)

**NTH-1: Add documentation comments to provider public methods**
Add concise doc comments to public provider methods explaining what they do, to improve discoverability.

Scenario: Provider documentation
- GIVEN a public method in record_provider.dart
- WHEN documentation is added
- THEN a one-line /// comment describes the method's purpose

**NTH-2: Introduce a consistent naming convention for private provider methods**
Standardize naming of private/internal provider methods only (e.g., `_loadX`, `_buildX`, `_computeX`). Public method signatures must remain unchanged to avoid breaking callers.

Scenario: Private method naming audit
- GIVEN private provider methods use inconsistent naming patterns internally
- WHEN renamed
- THEN private methods follow a consistent verb convention; no public method signatures are changed

### Non-Functional Requirements

**NFR-1: Zero behavior regressions**
All existing app functionality must work identically after refactoring. Threshold: 0 regressions detected through manual testing of all screens and flows.

**NFR-2: No increase in app startup time**
Refactoring must not introduce additional initialization overhead. Baseline: run `flutter run --profile` before starting refactor and note time-to-first-frame from DevTools. Threshold: post-refactor startup time remains within ±10% of that baseline.

**NFR-3: Maintainability improvement**
After refactoring, no single file should exceed 400 lines (excluding generated files). Average file length should decrease or remain stable. Threshold: max file length ≤400 lines, no file increases in line count by more than 10%.

## Success Criteria

| Criterion | Measurement | When |
|-----------|-------------|------|
| Zero repository imports in UI layer | `grep -r "import.*repositories" lib/screens/ lib/components/` returns 0 results | After refactor |
| Zero inline business logic in build methods | Manual audit of all widget build() methods | After refactor |
| No duplicate provider methods | Manual audit — each operation has exactly one code path | After refactor |
| Consistent coding style | All provider files follow the agreed error handling pattern (try-catch → set error state → notifyListeners); all files use grouped import ordering (dart:, package:, relative) — verified by checklist review | After refactor |
| All barrel files up-to-date | Each barrel file exports exactly the files in its directory | After refactor |
| All files in correct layer | Checklist audit against layer mapping table returns 0 misplacements | After refactor |
| No file exceeds 400 lines | `wc -l lib/**/*.dart \| sort -rn \| head -5` — no entry exceeds 400 | After refactor |
| Zero behavior regressions | Full manual walkthrough of all screens and flows | After refactor |

## Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Breaking existing logic during structural changes | High | Medium | Refactor one file at a time, test each change in isolation, commit frequently |
| Accidentally changing UI appearance or behavior | High | Low | Keep all widget trees intact — only move logic out, don't restructure widgets |
| Scope creep — temptation to improve logic while refactoring | Medium | High | Strict rule: structure only, no logic changes. If a bug is found, log it as a separate issue |
| Refactoring creates circular dependencies | Medium | Medium | Plan dependency direction upfront: UI → Provider → Repository → Model. Services are standalone |
| Large PR becomes hard to review | Medium | Medium | Break into phases: providers first, then UI extraction, then file structure |

## Constraints & Assumptions

**Constraints:**
- App is in active development — no backward compatibility concerns
- Provider is the state management solution — not changing to Riverpod, Bloc, etc.
- UI must remain visually and functionally identical
- Flutter SDK ^3.9.2, Dart conventions apply
- **Business logic definition:** Any operation that reads, writes, filters, validates, or transforms domain data (records, categories, sources, currency). Examples: filtering records by date range, calculating totals, validating a record before saving.
- **UI logic definition:** Pure presentation state with no domain knowledge. Examples: toggling a dropdown open/closed, tracking which tab is selected, managing a text field's focus.

**Clean architecture layer mapping for this project:**

| Directory | Architectural Role |
|-----------|-------------------|
| `lib/screens/` | Page-level widgets — navigation entry points only |
| `lib/screens/home/tabs/` | Tab-level widgets — compose components, call providers |
| `lib/components/` | Reusable UI widgets — may read provider state via `Consumer<T>` or `Provider.of<T>()`; must not call mutating provider methods directly (mutations go via callbacks passed from parent) |
| `lib/components/popups/` | Dialog/popup widgets — may read from providers, delegate mutations to providers |
| `lib/providers/` | State management + business logic orchestration — only layer that touches repositories |
| `lib/repositories/` | Data persistence — SQLite queries, local storage read/write |
| `lib/services/` | Stateless utilities — API calls, toast, storage helpers (no state) |
| `lib/helpers/` | Pure functions — formatting, conversion, calculation (no I/O, no state) |
| `lib/models/` | Data classes — plain Dart objects, no logic |
| `lib/configs/` | Static configuration constants |

**Assumptions:**
- The current provider/repository/service layer separation is the right foundation — we're enforcing it, not redesigning it. *If wrong:* would need a larger architectural redesign PRD.
- All current features work correctly — we're preserving behavior, not fixing bugs. *If wrong:* bugs should be logged separately and fixed before or after refactoring.
- The codebase is small enough (~44 files) to refactor comprehensively in one epic. *If wrong:* split into phase 1 (providers + data layer) and phase 2 (UI layer).

## Out of Scope

- **UI redesign or visual changes** — this refactor is structural only, no pixel changes
- **New features or functionality** — no adding capabilities during refactor
- **Changing state management approach** — Provider stays, no migration to Bloc/Riverpod
- **Model/schema changes** — data models remain as-is
- **Test creation** — writing unit/widget tests is a separate initiative (though the refactored code will be more testable)
- **Performance optimization** — unless a clear regression is introduced by the refactor
- **Chat feature logic changes** — chat logic is explicitly preserved unchanged; structural cleanup (import ordering, style) applies equally to chat files like all others

## Migration Strategy

Refactor in three sequential phases. Complete and verify each phase before starting the next. Each phase ends with `flutter analyze` (zero errors) and a manual smoke test of all affected screens.

**Phase 1 — Provider & Data Layer** (highest risk, do first)
- Audit `record_provider.dart`, `chat_provider.dart`, `locale_provider.dart`
- Remove any direct repository calls from non-provider files
- Consolidate redundant provider methods (FR-3)
- Apply consistent error handling and notifyListeners patterns (FR-4)
- Verify: `flutter analyze`, manual test of records, categories, chat tabs
- Commit: `refactor: phase 1 — clean provider and data layer`

**Phase 2 — UI Logic Extraction**
- Audit all files in `screens/`, `components/`, `components/popups/`
- Extract any business logic to providers or helpers (FR-2)
- Ensure no file imports from `repositories/` (FR-1)
- Verify: `flutter analyze`, manual test of all popups and tabs
- Commit: `refactor: phase 2 — extract logic from UI layer`

**Phase 3 — File Structure & Style**
- Audit file placements against the layer mapping table (FR-5)
- Update all barrel files (`*.dart` exports) to match current contents
- Apply consistent import ordering across all files (FR-4)
- Verify: `flutter analyze`, full app walkthrough
- Commit: `refactor: phase 3 — file structure and style consistency`

## Rollback Plan

Each phase ends with a dedicated commit, enabling targeted rollback without losing other phases:

- **Phase 1 regression:** `git revert <phase-1-commit>` — restores provider/data layer to pre-refactor state
- **Phase 2 regression:** `git revert <phase-2-commit>` — restores UI files without touching providers
- **Phase 3 regression:** `git revert <phase-3-commit>` — restores structure/style changes only
- **Full rollback:** `git revert <phase-3> <phase-2> <phase-1>` in reverse order
- **Safety net:** Before starting, tag the pre-refactor state: `git tag pre-refactor-code` for easy diff and reset reference

## Dependencies

- **record-provider epic (active)** — Must coordinate to avoid conflicting changes to record_provider.dart. Either complete that epic first or ensure changes don't overlap. Owner: self. Status: pending.
- **setup-font epic (active)** — Low risk of conflict, font setup is isolated. Status: resolved.

## _Metadata
<!-- Auto-generated. Updated by prd-edit. Read by prd-parse, prd-validate. -->
requirement_ids:
  must: [FR-1, FR-2, FR-3, FR-4, FR-5, FR-6]
  nice_to_have: [NTH-1, NTH-2]
  nfr: [NFR-1, NFR-2, NFR-3]
scale: large
discovery_mode: full
validation_status: warning
last_validated: 2026-03-28T17:41:23Z
