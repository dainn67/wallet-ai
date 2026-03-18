---
name: update-context
description: Reorganize and expand project documentation into a feature-centric, AI-friendly "Living Docs" structure.
status: backlog
priority: P1
scale: small
created: 2026-03-18T12:00:00Z
updated: null
---

# PRD: update-context

## Executive Summary
The goal of this epic is to modernize the project's technical documentation to serve as a reliable "source of truth" for both developers and AI assistants. We will move feature-specific details from high-level docs into a new `docs/features/` directory, organized by feature name (e.g., `ai-chat.md`, `expense-records.md`). These documents will provide detailed, full-stack technical flows (Screen > Provider > Service > Utils) using simple Mermaid diagrams. We will also update `GEMINI.md` and related context files to mandate documentation updates whenever a feature's logic changes.

## Problem Statement
The current `docs/` directory provides high-level architectural overviews but lacks granular, feature-specific implementation details. As the app grows (e.g., with the recent `HomeScreen` refactor and upcoming `record-provider` work), the "monolithic" architecture docs are becoming cluttered and redundant. Without a clear "Living Docs" strategy, developers and AI assistants struggle to map the full execution path of a feature, leading to slower onboarding and increased risk of design-spec drift.

## Target Users
| Role | Context | Primary Need | Pain Level |
| ---- | ------- | ------------ | ---------- |
| AI Assistant | Implementing or refactoring a feature | Needs precise, up-to-date technical flows to avoid making incorrect assumptions about the stack. | High |
| Developer | Onboarding or maintaining a specific domain | Quick access to the full-stack dependency graph for a feature (e.g., "Where does the chat stream get parsed?"). | Medium |

## User Stories
**US-1: Feature-Centric Documentation**
As a developer or AI assistant, I want each core feature to have its own documentation file so that I can understand its specific implementation details without wading through unrelated architectural info.

Acceptance Criteria:
- [ ] A new `docs/features/` directory is created.
- [ ] Files are named by feature (e.g., `ai-chat.md`, `expense-records.md`).
- [ ] Each file includes a simple Mermaid sequence diagram showing the flow from Screen to Utils.

**US-2: Mandatory Context Updates**
As a project architect, I want the AI instructions to mandate documentation updates so that the "Living Docs" stay in sync with the codebase.

Acceptance Criteria:
- [ ] `GEMINI.md` is updated with a rule requiring documentation updates after feature changes.
- [ ] Existing context files (e.g., `docs/architecture.md`) are simplified by moving specific logic to the new feature files.

## Requirements
### Functional Requirements (MUST)

**FR-1: Feature Directory Structure**
Create `docs/features/` and initialize it with files for current core features.

Scenario: Directory Organization
- GIVEN the new documentation structure
- WHEN looking for feature details
- THEN they are found in \`docs/features/{feature-name}.md\`.

**FR-2: Full-Stack Flow Mapping**
Each feature doc must describe the flow: Screen → Provider → Service → Repository → Database/API → Utils.

Scenario: Technical Understanding
- GIVEN a feature doc (e.g., \`ai-chat.md\`)
- WHEN an AI assistant reads it
- THEN it can identify the specific classes and methods involved in the entire execution chain.

**FR-3: Context Injection in GEMINI.md**
Add instructions to \`GEMINI.md\` that force the agent to update relevant feature docs when logic is modified.

Scenario: Living Docs Maintenance
- GIVEN a developer issues a directive to change the chat logic
- WHEN the AI assistant reviews its core mandates in \`GEMINI.md\`
- THEN it sees a rule to update \`docs/features/ai-chat.md\`.

### Functional Requirements (NICE-TO-HAVE)
- N/A for this documentation-centric refactor.

### Non-Functional Requirements
**NFR-1: AI-Friendliness**
Documentation must use structured Markdown (headers, code blocks, lists) and simple Mermaid syntax to ensure high signal-to-noise for AI context windows.

**NFR-2: Human-Readability**
The docs must remain clear and concise for human developers, avoiding overly verbose or repetitive technical jargon.

## Success Criteria
- [ ] \`docs/features/\` contains accurate flows for at least AI Chat and Expense Records.
- [ ] \`docs/architecture.md\` is simplified and free of duplicate feature details.
- [ ] \`GEMINI.md\` contains the mandatory update rule.
- [ ] App still builds and runs correctly (no logic changed).

## Risks & Mitigations
| Risk | Severity | Likelihood | Mitigation |
| ---- | -------- | ---------- | ---------- |
| Information Fragmentation | Medium | Low | Use high-level docs (\`architecture.md\`) as entry points that link to feature-specific files. |
| Documentation Decay | Medium | Medium | Mitigated by the mandatory update rule in \`GEMINI.md\`. |

## Constraints & Assumptions
- **Constraints:** Must use Mermaid diagrams for visual flows.
- **Assumptions:** Documentation-only changes will not affect the app's runtime behavior.

## Out of Scope
- Writing user manuals or non-technical onboarding guides.
- Changing the underlying Flutter/Dart code or state management logic.

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
