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

## Logic Locations
- **Parsing**: `ChatProvider.onDone` handler.
- **Aggregation Logic**: `RecordProvider._calculateCategoryTotals` (calculates flat and hierarchical totals from cached records).
- **DB Transactions**: `RecordRepository.createRecord`.
- **State Synchronization**: `ChangeNotifierProxyProvider` links `RecordProvider` to `ChatProvider`.
