---
created: 2026-05-24T05:30:37Z
last_updated: 2026-05-24T05:30:37Z
version: 1.0
author: Claude Code PM System
---

# Project Overview

## High-Level Summary
Wally AI is a Flutter mobile app for personal finance tracking. The headline interaction is a streaming chat with an AI assistant that parses messages into structured `Record` rows (income / expense / transfer), each tied to a `MoneySource` and a `Category`. Data lives locally in SQLite (`sqflite`); the UI consumes it through `RecordProvider` for monthly aggregates and drill-downs. A Glance-based home-screen widget mirrors monthly totals.

## Feature Catalog

### Chat & AI
- **Streaming AI chat** (`ChatTab` + `ChatProvider` + `ChatApiService`) — Dify streaming protocol with a custom `--//--` delimiter separating display text from trailing JSON.
- **Image attachments** in chat — up to 5 per message; compressed JPEG via `ImageProcessingService`; picked through `ImagePickerService` (camera + gallery).
- **Auto-scroll** on send and on every streaming chunk (`jumpTo(maxScrollExtent)`).
- **Suggested Prompts** chip bar — populated from the adaptive greeting's `suggestedPrompts` JSON; tapping pre-fills input, action chips append amounts.
- **Suggest Category banner** — inline confirm/cancel UI when AI returns `category_id: -1` with a `suggested_category`.
- **AI User Pattern + Adaptive Greeting** — background pattern sync (`AiPatternService`) feeds personalized launch greetings via a hidden `INIT_GREETING` request.
- **Transfer from chat** — server returns `type: 'transfer'` with `target_source_id`; client resolves the seeded Transfer category and persists atomically.

### Records & Aggregation
- **Records tab** — monthly filter, sort by `occurredAt DESC`, RecordsOverview card with total / income / spent.
- **Balance visibility toggle** — eye/eye-off masks Total Balance + Income to `*****` (Spent stays visible); local, non-persisted.
- **Date-group dividers** in the records list.
- **Edit / delete records** via `EditRecordPopup` (date+time picker for `occurredAt`, delete confirmation through `ConfirmationDialog`).
- **In-memory totals** computed by `RecordProvider` from cached records.

### Categories
- **Hierarchical categories** with parent/sub relationship.
- **Monthly category totals** (flat + hierarchical) computed in-memory.
- **Drill-down bottom sheet** — tap a parent row to see union of parent+sub records; tap a sub row to see just that sub.
- **Seeded `Transfer` category** — single source of truth for transfer rows.

### Money Sources
- **Per-source balance tracking**, atomic across all record mutations.
- **Add / edit source** popups.
- **Transfer popup** — opens with origin pre-locked when launched from `EditSourcePopup`'s swap icon.

### Localization & Settings
- **Auto-detect language + currency** on first launch.
- **English / Vietnamese** UI strings (`L10nConfig`).
- **Currency selection** popup; currency is included in AI prompt context.
- **Onboarding** redesigned multi-step dialog on first launch.
- **Drawer navigation** — Chat vs Financials sections + global Settings.
- **Share App** — drawer ListTile opens system share with localized copy + Play Store URL.

### Native Integrations
- **Glance home-screen widget** (Android) — monthly totals; updates after each record write.
- **Firebase Core** initialized (no active cloud features yet).
- **`flutter_native_splash`** generated splash.

### Developer Surfaces
- **TestTab** — demo data, AI pattern testing tooling.
- **`@visibleForTesting` hooks** on providers (`setTestSuggestedPrompts`, `incrementDbUpdateVersionForTest`).
- **`RecordRepository.setMockDatabase`** for in-memory test DBs.

## Integration Points
- **Server**: sibling repo `../chatbot-flow-server/`, project scope `wallyai`. Documented under `../chatbot-flow-server/docs/`.
- **Streaming protocol**: chat chunks + `--//--` + trailing JSON (List → records, Map with `suggestedPrompts` → prompt chips).
- **Home Widget bridge**: `home_widget` Flutter package + native Glance widget in `android/app/src/main/kotlin/.../AppWidget.kt`.
- **`.env` + `AppConfig`**: secrets and base URLs.

## Current State (as of 2026-05-24)
- **Branch**: `main`, clean tracking.
- **Last shipped feature**: transfer from chat (4786791).
- **Active uncommitted fixes**:
  - AAR metadata fix — pin `androidx.glance:*` to `1.1.1` via `resolutionStrategy` to override `home_widget`'s `1.+`.
  - Chat auto-scroll fix — always scroll on user send + every streaming chunk; `jumpTo` over `animateTo`.
- **App version**: 1.2.2+28.
- **Recently completed epic**: onboarding (merged via PR #198).
