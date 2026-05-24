---
created: 2026-05-24T05:30:37Z
last_updated: 2026-05-24T05:30:37Z
version: 1.0
author: Claude Code PM System
---

# Product Context

## What It Is
**Wally AI** — a mobile personal-finance assistant that turns natural-language messages into structured financial records. Instead of filling forms, users tell the assistant what they spent or earned; the AI parses the message into one or more records and saves them locally.

## Target Users
- **Casual budget keepers** who find traditional expense apps too friction-heavy (manual forms, dropdowns, picker hell).
- **Conversational-UI natives** comfortable describing actions in chat ("just bought coffee 50k from cash").
- **Multilingual users** — current localized surfaces support **English** and **Vietnamese**, with auto-detection of language + currency on first launch.

## Core User Jobs
1. **"Log what I just spent/earned, fast."** — chat-driven record entry; AI fills `amount`, `type`, `category`, `money source`, optional event-time, and image-derived context.
2. **"Tell me where my money went this month."** — Records and Categories tabs with monthly default filter, hierarchical category drill-down, in-memory totals.
3. **"Move money between my sources without breaking my balance sheet."** — popup-driven *or* chat-driven transfer (`type: 'transfer'`) recorded atomically as a single row that debits the origin and credits the destination.
4. **"See my month at a glance."** — RecordsOverview card with monthly total/income/expense, optional masking, and a native home-screen widget (Glance / iOS) showing the same monthly totals.
5. **"Don't make me re-categorize the same thing twice."** — when the AI can't pick a category confidently, it returns `category_id: -1` plus a `suggested_category`; the chat bubble shows an inline `SuggestionBanner` to confirm/cancel.
6. **"Pick up where I left off."** — on launch, an adaptive greeting personalized by `user_pattern` (a periodic AI analysis of recent transactions) may include `suggestedPrompts` chips above the input.

## Core Features
- **Chat-driven record entry** (text + image attachments, up to 5 per message; compressed JPEG).
- **Records management**: monthly default filter, sort by `occurredAt DESC`, edit/delete via popups.
- **Categories management**: hierarchical (parent/sub) with monthly totals + drill-down bottom sheet.
- **Money sources**: balances tracked atomically; per-source transfer popup.
- **Transfers**: popup-driven and chat-driven; single row debit+credit; excluded from income/expense aggregates.
- **Suggested prompts**: returning-user chips for one-tap entry.
- **Suggest Category banner**: inline AI suggestion when classification is ambiguous.
- **AI Pattern + Adaptive Greeting**: background pattern sync + personalized launch greeting.
- **Localization**: English / Vietnamese with first-launch auto-detect.
- **Currency selection**: per-user, used in display + AI prompt context.
- **Home-screen widget**: Glance (Android) showing monthly totals.
- **Share App**: drawer entry opens system share with localized copy + Play Store URL (App Store TBD).
- **Onboarding**: redesigned multi-step dialog on first launch.

## Use Cases
- "Coffee 50k from cash" → 1 expense record, source "Cash", category "Food/Drinks".
- "Salary 20m to bank" → 1 income record, source "Bank".
- "Transfer 500k from cash to bank for rent" → 1 transfer row, Cash debited, Bank credited.
- Photo of receipt + caption "lunch" → image-aware parse via the chat pipeline.
- Tap a money source → `EditSourcePopup` → swap icon → `TransferPopup` pre-locked to that origin.

## Non-Goals (v1)
- Multi-user / cloud sync — data is local-only via SQLite.
- Investment tracking beyond money sources / balances.
- Recurring transactions / scheduled records.
- Rich transfer editing — `EditRecordPopup` for transfers is delete-only.
- iOS App Store distribution copy in Share App — pending submission.
