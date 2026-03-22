---
epic: edit-record
branch: epic/edit-record
started: 2026-03-22T00:00:00Z
status: in-progress
---
# Epic Context: edit-record

## Key Decisions
- AD-1: Schema Modernization (`record` -> `Record`, `created_at` -> `last_updated`).
- AD-2: Transactional Update Logic (Atomic delta calculation).
- AD-3: UI Component Versatility (`isEditable` flag in `RecordWidget`).

## Notes
- Scale: Medium (UI + Model + Repository + Schema).
- Breaking Change: Database v6 will trigger fresh start.
