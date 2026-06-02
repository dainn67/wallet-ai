# Execution Status — home-widgets

Snapshot at: 2026-06-01T09:58:56Z
Branch: epic/home-widgets

## Summary
- Ready: 1
- Blocked: 5
- In progress: 0
- Complete: 0 / 6

## Ready
- T001 (#219) — Layout spec + icon asset audit  *[no dependencies]*

## Blocked
- T002 (#220) — Rewrite AppWidget.kt Glance composables  *[waiting on T001]*
- T003 (#221) — Deep-link routing for homeWidget://camera  *[waiting on T001]*
- T004 (#222) — Extract camera trigger to ChatProvider  *[waiting on T001]*
- T005 (#223) — Cold-start camera flow + wire-up  *[waiting on T003, T004]*
- T006 (#224) — QA sweep — 5 breakpoints × 3 APIs + NFR verification  *[waiting on T002, T005]*

## Dependency chain
```
T001
 ├── T002 ─────────────┐
 ├── T003 ──┐           │
 └── T004 ──┴── T005 ──┴── T006
```
