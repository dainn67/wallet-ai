---
created: 2026-05-24T05:30:37Z
last_updated: 2026-05-24T05:30:37Z
version: 1.0
author: Claude Code PM System
---

# Project Brief

## What It Does
**Wally AI** is a Flutter mobile app that lets users log and review personal finances by chatting with an AI assistant in natural language. The AI parses each message (and optional image attachments) into one or more structured records — income, expense, or transfer — which are saved locally in SQLite and reflected immediately across the Records, Categories, and home-screen-widget surfaces.

## Why It Exists
Traditional budget apps demand high friction per entry: open the app, pick "expense", choose category, choose source, type amount, type note, save. The activation energy is enough that users stop logging within weeks. Wally AI collapses that flow into one chat message — "coffee 50k from cash" — and lets the AI handle the structured fields. The app's goal is to keep entry friction near-zero so casual budgeters actually maintain a useful financial ledger.

## Primary Goals
1. **Sub-3-second record entry** from intent to saved row, including AI round-trip.
2. **Offline-first reliability** — local SQLite + bundled fonts so the app never blocks on the network for view/edit, only for new AI parses.
3. **One source of truth for balances** — all source-impact math goes through `RecordRepository._applyRecordImpact` in atomic transactions; no UI-side balance math.
4. **Living documentation discipline** — `docs/features/` + `project_context/` updated alongside every feature change so future contributors (human or AI) can ramp without spelunking.

## Success Criteria
- Users complete record entry in chat without falling back to manual popups for routine cases.
- Monthly totals on the home-screen widget always match the in-app RecordsOverview card (no drift between widget and app).
- Transfers never leave the two source balances inconsistent (atomic debit + credit).
- A new contributor can add a feature end-to-end (model → repo → provider → UI → docs) by reading `project_context/` + the matching `docs/features/<slug>.md` and following established patterns without inventing new ones.

## Scope (in)
- Local financial record keeping with AI-driven entry.
- English + Vietnamese localization, multi-currency display.
- Android + iOS as primary targets. (macOS / Linux scaffolds exist but aren't actively shipped.)
- Native home-screen widget on Android (Glance).
- Firebase initialization for future analytics/auth, but no current dependence on cloud data.

## Scope (out)
- Multi-device sync, cloud accounts, server-side persistence of user data.
- Investment / portfolio tracking, scheduled / recurring transactions.
- Rich transfer editing in v1 (delete-only).
- Languages beyond English + Vietnamese.

## Key Constraints
- **FVM-pinned Flutter** — all commands run via `fvm`.
- **`google_fonts` prohibited** — fonts must be local assets.
- **Provider only for reactive UI state** — services and repositories are singletons with their own state.
- **Server scope = `wallyai` only** in the shared `chatbot-flow-server` repo.
- **Server-side prompt + JSON contract** is the integration boundary; any change to the trailing-JSON shape must be mirrored in `ChatProvider._handleStream` and the relevant `docs/features/*.md`.
