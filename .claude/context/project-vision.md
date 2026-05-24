---
created: 2026-05-24T05:30:37Z
last_updated: 2026-05-24T05:30:37Z
version: 1.0
author: Claude Code PM System
---

# Project Vision

## Long-Term Vision
A personal-finance assistant where logging is so low-friction it disappears into the rest of your messaging behavior. The end state is "you type a sentence; the ledger updates" — a single-message interaction that beats every form-based competitor on time-to-record, without sacrificing the structured aggregation, drill-downs, and balance accuracy a real budget app needs.

## Strategic Priorities (next few horizons)
1. **Friction minimization above all** — every feature is measured against "does this preserve or improve sub-3-second record entry?" Features that don't pass this test live elsewhere (settings, secondary tabs, optional flows).
2. **AI parsing quality** — the chat parse is the product. Server prompt improvements (categories, suggested-category, transfers, suggested-prompts) compound more than any UI polish.
3. **Local-first data sovereignty** — never trade offline reliability for cloud convenience. Any cloud sync, if added, must be opt-in and never become the source of truth for balances.
4. **Living docs as infrastructure** — `docs/features/` + `project_context/` are part of the build, not afterthoughts. Future contributors (and AI coding agents) depend on them.

## Future Goals (directional, not committed)
- **Richer transfer editing** — promote v1's delete-only to full edit (amount, sources, note, date) without losing the atomic dual-update guarantee.
- **More languages** — currently EN + VI; expand once the AI prompt scaffolding generalizes cleanly.
- **iOS App Store distribution** — currently Android Play Store only in Share App copy; ship iOS and fold the App Store URL into `L10nConfig.share_app_message`.
- **Opt-in cloud backup** — encrypted SQLite snapshot to user-owned storage; not a sync engine.
- **Recurring records** — only if entry friction stays at sub-3 seconds in the common case.
- **Smarter AI Pattern signals** — use long-term `user_pattern` analysis to drive better suggested prompts, anomaly hints ("you spent 3x more on Food this week"), and proactive category suggestions.
- **Investment / net-worth view** — a separate, opt-in surface; not in scope for the core ledger.

## Potential Expansions
- **Receipt OCR pipeline** beyond the current "send the image to the chat" approach — pre-process on-device for structured extraction.
- **Voice input** — server already has some voice-input groundwork (`docs/server-update-voice-input.md`); revisit when offline STT or low-cost cloud STT is viable.
- **Widget interactions** — current widget is read-only; tappable widget actions ("quick add expense") could shave even more friction.
- **Cross-record analytics** — month-over-month, category trends, source-flow sankey-style visualization.

## Anti-Goals
- **Don't become a generic chat app**. The chat is a *parsing surface*, not a conversational companion.
- **Don't move the source of truth off-device** without explicit, granular user opt-in.
- **Don't add settings to compensate for unclear defaults** — make better defaults instead.
- **Don't ship features that require manual data migration steps**. Schema changes go through `record_migration_service.dart` with backfill.
