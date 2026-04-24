---
epic: voice-input
branch: epic/voice-input
updated: 2026-04-22T12:10:41Z
---
# Execution Status Snapshot: voice-input

## Counts
- Ready: 2
- Blocked: 5
- In Progress: 0
- Complete: 0 / 7

## Ready Issues
- #179 — Add record + permission_handler dependencies and platform plumbing (phase 1, sequential)
- #184 — Error strings — voice and image failure messages (phase 2, parallel)

## Blocked Issues
- #180 — Implement AudioRecordingService singleton (depends on: #179)
- #181 — Chat composer mic icon + recording bar UI (depends on: #180)
- #182 — ChatApiService — add audioBase64 parameter and top-level audio field (depends on: #180)
- #183 — ChatProvider — audio plumbing and voice-error surfacing (depends on: #180, #182)
- #185 — Integration tests, cross-device smoke, and docs (depends on: #179, #180, #181, #182, #183, #184)

## Critical Path
#179 → #180 → #181 → #185  (~4.5 days)

## Notes
- Dependency IDs remapped from pre-sync numbers (001–013) to GitHub issue numbers (179–185) during epic-start.
- #184 can start in parallel with #179 — no deps, non-conflicting files (l10n only).
- #183 carries a `conflicts_with: [181, 182]` — file-level overlap check kicks in during parallel scheduling.
