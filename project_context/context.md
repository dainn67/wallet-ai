# Context

## What the App Is

Wally AI is a mobile financial assistant that helps users track income and expenses through natural language. Users chat with an AI assistant that parses messages into structured records. The app persists financial data (Records, MoneySources, Categories) locally in SQLite and provides a modern UI with real-time updates.

## Core Mandates

- **Living Docs**: Documentation in `docs/features/` must be updated whenever a feature's technical logic changes.
- **Simplicity**: Favor concise, idiomatic code and avoid over-engineering.
- **Offline Support**: All fonts and critical data must be available locally.

## Main Flows

### Navigation

The app uses a single-screen architecture (`HomeScreen`) with a `TabBarView` to switch between:

1. **Chat**: The AI assistant tab for conversational record entry.
2. **Records**: The financial dashboard for list views and stats.
3. **Categories**: The classification manager with hierarchical grouping and monthly reporting.
   A navigation drawer provides secondary access to these tabs and global settings (Language, Currency, Data Management).

### Data Filtering

- **Monthly Focus**: The app defaults to filtering all records, totals, and aggregates by the **current month**.
- **Cross-Tab Filter**: `RecordProvider.selectedDateRange` is a global state that keeps all tabs in sync.

### AI Record Creation

1. User sends a message in the **ChatTab**.
2. **ChatProvider** fetches the list of available categories and sources from **RecordProvider**.
3. **ChatApiService** sends the request to the backend with the user message and local context.
4. Assistant replies with a text response followed by a JSON array of records.
5. **ChatProvider** parses the JSON and saves records via **RecordRepository** using atomic transactions.
6. **RecordProvider** reloads from disk and recalculates in-memory totals.

### Record Deletion
Users can delete a record from either the **RecordsTab** or the **ChatTab** by opening `EditRecordPopup` and tapping the red **Delete** button at the bottom of the form. Confirming the `ConfirmationDialog` calls `RecordProvider.deleteRecord`, which atomically removes the row and reverses the affected `MoneySource` balance. When invoked from a chat bubble, the optional `onDeleted` callback also calls `ChatProvider.removeMessageRecord` so the deleted record disappears from the conversation UI.

### Record Event Time (`occurredAt`)
Every `Record` carries two timestamps: `lastUpdated` (audit — when the row was last written) and `occurredAt` (the user-editable event time the record represents). Defaults to `DateTime.now()` at creation. `ChatProvider._handleStream` parses an optional `occurred_at` field (int millis or ISO-8601) from the server's record JSON; if absent, falls back to now. `EditRecordPopup` exposes a date+time picker row (native `showDatePicker` + `showTimePicker`) that edits `occurredAt`. All user-facing sorting, the cross-tab date-range filter, `RecordWidget`'s dd/mm/yyyy display, the records-tab date-group dividers, the home-widget monthly totals, and `AiPatternService` context collection use `occurredAt`. Schema migration (v7 → v8) lives in `lib/services/record_migration_service.dart` and backfills existing rows with `occurred_at = last_updated`. Server-side spec: `docs/server/record-time-server-spec.md`.

### Balance Visibility Toggle
The `RecordsOverview` card exposes a trailing eye/eye-off icon on the Total Balance row. Tapping it flips a local `_valuesHidden` flag that masks both **Total Balance** and **Income** as `*****` (Spent stays visible). State defaults to hidden and is not persisted — it resets on any tab/app rebuild.

### Suggested Prompts (Returning Users)

For returning users, the adaptive greeting may include a `suggestedPrompts` JSON object (instead of a record array) after the `--//--` delimiter. ChatProvider detects the type after `jsonDecode` and populates `_suggestedPrompts`. These are displayed as interactive chips above the chat input via **SuggestedPromptsBar**. Tapping a chip pre-fills the input; tapping an action chip appends an amount; sending removes the active prompt from the list. See `docs/features/suggested-prompts.md`.

### Suggest Category (Inline AI Banner)

When a record has `category_id: -1` and the server returns a `suggested_category` object, `ChatProvider._handleStream` parses the suggestion into a transient `Record.suggestedCategory` field. The `ChatBubble` widget renders a `SuggestionBanner` beneath the unclassified record card. Confirming calls `RecordProvider.resolveCategoryByNameOrCreate`, updates the record in DB, and clears the banner. Cancelling clears the suggestion from in-memory state only. The suggestion is never persisted — app restart removes all banners. See `docs/features/suggest-category.md`.

### AI Pattern Analysis & Adaptive Greeting

1. **Background Pattern Sync**: On app launch, `AiPatternService` checks the last update time. If an update is due, it collects recent transaction context (Latest vs. Momentum) and sends it to the AI for high-level behavior analysis.
2. **Adaptive Greeting**: On app load, `ChatProvider` automatically sends a hidden `INIT_GREETING` request to the server, including the locally stored `user_pattern` string. This allows the AI to generate a highly personalized greeting based on established user habits.

## Logic Locations

- **Parsing**: `ChatProvider._handleStream` onDone handler — type-checks decoded JSON: Map with `suggestedPrompts` key → prompts; List → records. Also parses `suggested_category` per record when `categoryId == -1`.
- **Aggregation Logic**: `RecordProvider._calculateCategoryTotals` (calculates flat and hierarchical totals from cached records).
- **Category Drill-Down**: `RecordProvider.getRecordsForCategory(List<int> categoryIds, DateTimeRange?)` — pure in-memory filter+sort (`occurredAt DESC`); used by `lib/components/popups/category_records_bottom_sheet.dart`. Tapping a parent row opens the sheet with union of parent+sub ids; tapping a sub row opens it with only that sub's id.
- **AI Pattern Logic**: `AiPatternService.updateUserPattern` (orchestrates date range windows and context snapshot collection).
- **Adaptive Greeting Logic**: `ChatProvider.sendAdaptiveGreeting` (triggers the INIT_GREETING flow).
- **Suggested Prompts State**: `ChatProvider.selectPrompt`, `selectAction`, `_removeActivePrompt` — manage chip bar state.
- **Suggested Category Parsing**: `ChatProvider._handleStream` (~line 210) — `SuggestedCategory.fromJson(item['suggested_category'])` when `categoryId == -1`.
- **Category Resolver**: `RecordProvider.resolveCategoryByNameOrCreate(name, type, parentId)` — finds or creates a category, refreshes cache, returns new id.
- **Suggestion Banner UI**: `lib/components/suggestion_banner.dart` — inline widget with double-tap guard; wired in `lib/components/chat_bubble.dart`.
- **DB Transactions**: `RecordRepository.createRecord`.
- **State Synchronization**: `ChangeNotifierProxyProvider` links `RecordProvider` to `ChatProvider`.
