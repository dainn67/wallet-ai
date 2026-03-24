# Context

## What the App Is
Wally AI is a mobile financial assistant that helps users track income and expenses through natural language. Users chat with an AI assistant that parses messages into structured records. The app persists financial data (Records, MoneySources, Categories) locally in SQLite and provides a modern UI with real-time updates.

## Core Mandates
- **Living Docs**: Documentation in `docs/features/` must be updated whenever a feature's technical logic changes.
- **Simplicity**: Favor concise, idiomatic code and avoid over-engineering.
- **Offline Support**: All fonts and critical data must be available locally.

## Main Flows

### Navigation
The app uses a single-screen architecture (`HomeScreen`) with a `PageView` and `BottomNavigationBar` to switch between:
1. **Chat**: The AI assistant tab for conversational record entry.
2. **Records**: The financial dashboard for list views and stats.
A navigation drawer provides secondary access to these tabs and global settings.

### AI Record Creation
1. User sends a message in the **ChatTab**.
2. **ChatProvider** fetches the list of available categories and sources from **RecordProvider**.
3. **ChatApiService** sends the request to the backend with the user message and local context.
4. Assistant replies with a text response followed by a JSON array containing `category_id`, `source_id`, `amount`, `type`, and `description`.
5. **ChatProvider** parses the JSON on completion and saves the records via **RecordRepository** using atomic transactions.
6. **RecordProvider** is notified to reload and update the **RecordsTab**.

## Directory Structure
- `lib/main.dart`: App initialization, global provider setup, and theme configuration.
- `lib/screens/home/`: `home_screen.dart` (Main container), `tabs/` (`chat_tab.dart`, `records_tab.dart`).
- `lib/providers/`: `record_provider.dart` (Records, sources, categories), `chat_provider.dart` (Streaming chat flow).
- `lib/repositories/`: `record_repository.dart` (SQLite storage and transactions).
- `lib/models/`: Entity definitions (`record.dart`, `money_source.dart`, `category.dart`).
- `lib/services/`: Singletons like `ApiService`, `ChatApiService`, `StorageService`.
- `docs/features/`: Granular technical documentation and Mermaid diagrams for specific features.

## Logic Locations
- **Navigation State**: `HomeScreen` managed by `PageController`.
- **Chat Streaming**: `ChatProvider.sendMessage` and `ChatApiService.streamChat`.
- **Parsing**: `ChatProvider.onDone` handler.
- **DB Transactions**: `RecordRepository.createRecord`.
- **State Synchronization**: `ChangeNotifierProxyProvider` links `RecordProvider` to `ChatProvider`.
