---
name: update-context
status: backlog
created: 2026-03-18T12:15:00Z
progress: 0%
priority: P1
prd: .claude/prds/update-context.md
task_count: 5
github: "https://github.com/dainn67/wallet-ai/issues/51"
---

# Epic: update-context

## Overview
This epic implements a "Living Docs" strategy to ensure project documentation remains accurate and actionable for both developers and AI assistants. We will move away from monolithic architectural docs toward a feature-centric structure in `docs/features/`. Each feature doc will provide a detailed technical mapping (Screen > Provider > Service > Utils) and a Mermaid sequence diagram. Crucially, we will update `GEMINI.md` to establish a mandatory documentation update loop, preventing technical debt from accumulating in the context files.

## Architecture Decisions
### AD-1: Feature-Centric Documentation
**Context:** High-level docs like `architecture.md` are becoming cluttered with specific implementation details, making it hard to find relevant info for a single feature.
**Decision:** Extract feature-specific details into standalone files in `docs/features/`.
**Alternatives rejected:** Maintaining a single monolithic `architecture.md` (rejected for lack of scalability).
**Trade-off:** More files to manage, but significantly higher signal-to-noise ratio for AI context.
**Reversibility:** Easy to merge files back if needed.

### AD-2: Mandatory Context Update Hook
**Context:** Documentation often decays because developers/AI forget to update it after logic changes.
**Decision:** Add a mandate to `GEMINI.md` that requires updating the corresponding feature doc whenever logic is changed.
**Alternatives rejected:** Using git hooks (rejected as too restrictive for documentation) or automated doc generators (rejected as too complex for this project's scale).
**Trade-off:** Adds a small overhead to every feature change, but ensures long-term context accuracy.
**Reversibility:** Easy to remove the instruction from `GEMINI.md`.

## Technical Approach
### Documentation Structure
- **New Directory**: `docs/features/` will contain files like `ai-chat.md` and `expense-records.md`.
- **Content Requirements**: Each file must contain:
  - Technical overview of the feature.
  - Class/method mapping for each layer (UI, Provider, Service, Repository, DB).
  - Mermaid sequence diagram for the primary happy-path flow.

### Context Cleanup
- **architecture.md**: Remove specific parsing logic or DB schema details that now live in feature docs. Replace with high-level summaries and links to the new feature files.
- **GEMINI.md**: Update the "Mandates" section with the new documentation sync rule.

## Traceability Matrix
| PRD Requirement | Epic Coverage | Task(s) | Verification |
| --------------- | ------------- | ------- | ------------ |
| FR-1: Feature Directory Structure | §Documentation Structure | T1 | Directory and files exist |
| FR-2: Full-Stack Flow Mapping | §Documentation Structure | T2, T3 | Docs contain Mermaid + technical maps |
| FR-3: Context Injection in GEMINI.md | §Context Cleanup | T4 | `GEMINI.md` updated |
| NFR-1: AI-Friendliness | Task Implementation | T2, T3 | Verify Mermaid syntax and MD structure |
| NFR-2: Human-Readability | Task Implementation | T2, T3 | Manual review of doc clarity |

## Implementation Strategy
### Phase 1: Foundation
Create the `docs/features/` directory and set up the new structure.
### Phase 2: Content Migration
Extract and expand the documentation for the two core features (AI Chat and Expense Records).
### Phase 3: Global Context Alignment
Simplify `architecture.md` and update `GEMINI.md` with the new mandates.

## Task Breakdown

##### T1: Scaffold Feature Docs
- **Phase:** 1 | **Parallel:** no | **Est:** 0.2d | **Depends:** — | **Complexity:** simple
- **What:** Create `docs/features/` directory and create empty files for `ai-chat.md` and `expense-records.md` with standard headers.
- **Key files:** `docs/features/ai-chat.md`, `docs/features/expense-records.md`
- **PRD requirements:** FR-1
- **Key risk:** None.

##### T2: Document AI Chat Feature
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1 | **Complexity:** moderate
- **What:** Map the full flow for AI Chat: `ChatTab` → `ChatProvider` → `ChatApiService` → `ApiHelper`. Include a Mermaid diagram of the streaming response parsing logic.
- **Key files:** `docs/features/ai-chat.md`
- **PRD requirements:** FR-2
- **Key risk:** Missing internal utility classes in the flow mapping.

##### T3: Document Expense Records Feature
- **Phase:** 2 | **Parallel:** yes | **Est:** 0.5d | **Depends:** T1 | **Complexity:** moderate
- **What:** Map the full flow for Records: `RecordsTab` → `RecordProvider` → `RecordRepository` → `DatabaseService`. Include a Mermaid diagram of the CRUD operations and state sync.
- **Key files:** `docs/features/expense-records.md`
- **PRD requirements:** FR-2
- **Key risk:** Inaccuracies in mapping the DB service interactions.

##### T4: Update Global Context (GEMINI.md)
- **Phase:** 3 | **Parallel:** no | **Est:** 0.3d | **Depends:** T2, T3 | **Complexity:** simple
- **What:** Add the mandatory documentation update rule to `GEMINI.md`. Update `architecture.md` to link to the new feature files and remove redundant details.
- **Key files:** `GEMINI.md`, `docs/architecture.md`
- **PRD requirements:** FR-3
- **Key risk:** `GEMINI.md` becomes too verbose; must keep the instruction concise.

##### T5: Integration Verification
- **Phase:** 3 | **Parallel:** no | **Est:** 0.2d | **Depends:** T4 | **Complexity:** simple
- **What:** Verify all links between docs work. Ensure Mermaid diagrams are valid. Perform a final check of the "Living Docs" instructions.
- **Key files:** `docs/`
- **PRD requirements:** NFR-1, NFR-2
- **Key risk:** Broken links between documentation files.

## Risks & Mitigations
| Risk | Severity | Likelihood | Impact | Mitigation |
| ---- | -------- | ---------- | ------ | ---------- |
| Documentation Inaccuracy | High | Medium | AI makes wrong assumptions | Peer review docs against actual code during task implementation. |
| Context Window Bloat | Medium | Medium | Slower AI response | Keep feature docs focused on technical "how-it-works" rather than user stories. |
| Fragmented Info | Low | Low | Harder human navigation | Ensure `architecture.md` acts as a clear table of contents for all features. |

## Dependencies
- None.

## Success Criteria (Technical)
| PRD Criterion | Technical Metric | Target | How to Measure |
| ------------- | ---------------- | ------ | -------------- |
| Directory structure | File existence | 100% | `ls docs/features/` |
| Mermaid validity | Syntax check | 0 errors | Visual check in Markdown viewer |
| Mandatory Update Rule | GEMINI.md content | Exists | `grep` for the new mandate |

## Tasks Created
| #   | Task                         | Phase | Parallel | Est. | Depends On | Status |
| --- | ---------------------------- | ----- | -------- | ---- | ---------- | ------ |
| 001 | Scaffold Feature Docs        | 1     | no       | 0.2d | —          | open   |
| 010 | Document AI Chat Feature     | 2     | yes      | 0.5d | 001        | open   |
| 011 | Document Expense Records     | 2     | yes      | 0.5d | 001        | open   |
| 020 | Update Global Context        | 3     | no       | 0.3d | 010,011    | open   |
| 090 | Integration verification     | 3     | no       | 0.2d | all        | open   |

### Summary
- **Total tasks:** 5
- **Parallel tasks:** 2 (Phase 2)
- **Sequential tasks:** 3 (Phase 1 + 3)
- **Estimated total effort:** 1.7d
- **Critical path:** T001 → T010 → T020 → T090 (~1.2d)

### Dependency Graph
```
  T001 ──→ T010 (parallel) ──→ T020 ──→ T090
       ──→ T011 (parallel) ──→ T020
```

### PRD Coverage
| PRD Requirement | Covered By | Status    |
| --------------- | ---------- | --------- |
| FR-1: [name]    | T001       | ✅ Covered |
| FR-2: [name]    | T010, T011 | ✅ Covered |
| FR-3: [name]    | T020       | ✅ Covered |
| NFR-1: [name]   | T090       | ✅ Covered |
| NFR-2: [name]   | T090       | ✅ Covered |
