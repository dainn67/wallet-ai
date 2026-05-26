---
epic: category-icons
branch: epic/category-icons
started: 2026-05-25T16:24:21Z
status: in-progress
---
# Epic Context: category-icons

## Key Decisions
(See `.claude/epics/category-icons/epic.md` Architecture Decisions for the full set. Brief recap below; record any drift from these as work proceeds.)

- **AD-1:** Emoji is a single `String emoji` column on `Category` (non-null, default `'🏷️'`). No icon table, no asset bundle.
- **AD-2:** SQLite v9 → v10 migration uses `ALTER TABLE ADD COLUMN` + guarded `UPDATE` (idempotent, mirrors `addOccurredAtColumn`). No table rebuild.
- **AD-3:** Edit UI uses plain `TextField` + OS emoji keyboard. **No `emoji_picker_flutter` package.** Deferred unless QA on #214 shows the TextField is unclear.
- **AD-4:** Server validates + coerces to `'🏷️'` on invalid AI output; client defensively coalesces null/empty/missing to `'🏷️'`. Both sides enforce the invariant.
- **AD-5:** Concrete curated seed emoji map (17 entries) hard-coded in `record_repository.dart::_seedDatabase` and the v10 migration. See epic AD-5 table for the full mapping.

## Notes

### Session 2026-05-25 — epic-start

- Branch `epic/category-icons` created from `main` (commit `a1e4613` after auto-commit of redesign-ui WIP + epic/PRD files; head pulled with rebase).
- 39-file auto-commit bundles in-flight `redesign-ui` working tree alongside this epic's PRD + task files. **Risk:** if `redesign-ui` rolls back or rebases, this branch's render-site assumptions (#215) may drift. Mirror this risk in any PR description.
- Embedded-git-repo warning during commit: `.claude/worktrees/agent-a410e0cdd33caef56` was added as a submodule pointer. Not intentional — clean up via `git rm --cached .claude/worktrees/agent-a410e0cdd33caef56` if it causes friction later, or add `.claude/worktrees/` to `.gitignore`.
- Phase 1 (#211 ‖ #212) is unblocked. Critical path anchor is **#211** — every Phase 2 task needs `Category.emoji` to exist on the model.
- Server work for #212 happens in `../chatbot-flow-server/` (wallyai scope). Coordinate deploy timing — additive field is backwards-compatible so server can ship first without breaking older clients.
