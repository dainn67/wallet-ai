---
epic: home-widgets
branch: epic/home-widgets
started: 2026-06-01T09:58:56Z
status: in-progress
---
# Epic Context: home-widgets

## Key Decisions
(Record architecture decisions and rationale here as work progresses.)

Initial ADRs from epic.md:
- **AD-1:** Plain-UI Glance composables, no overlay Activity (simplicity over premium feel).
- **AD-2:** Two distinct URIs `homeWidget://record` + `homeWidget://camera` (over single URI with query param).
- **AD-3:** Camera trigger lives on `ChatProvider.pickImageFromCamera()` (single source of truth for both in-app button and widget deep-link).

## Notes
(Accumulate context across sessions here.)

- PRD status: WARNING (3 non-blocking minor warnings — see `.claude/prds/.validation-home-widgets.md`).
- Task dependency chain: T001 → (T002 ∥ T003 ∥ T004) → T005 → T006.
- All work happens on `epic/home-widgets` branch.
