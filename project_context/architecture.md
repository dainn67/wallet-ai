# Architecture

## Tooling
- **FVM**: Use `fvm` for all Flutter and Dart commands (e.g., `fvm flutter run`). Flutter version is pinned via `.fvmrc`.
- **Environment**: SDK `^3.9.2`. Material 3 enabled.

## Typography
- **Poppins**: The ONLY font family used. Served via **LOCAL ASSETS** to ensure full offline support.
- **Prohibited**: The `google_fonts` package is forbidden to prevent network-related rendering delays (FOUT).
- **Configuration**: Managed in `pubspec.yaml` and applied via `ThemeData` in `main.dart`.

## State Management (Provider)
- **MultiProvider**: Set up in `main.dart`.
- **RecordProvider**: Central state for Records, MoneySources, and Categories.
  - **In-Memory Aggregation**: Calculations for category totals (flat and hierarchical) are performed in-memory using cached data to ensure immediate UI responsiveness during filtering.
  - **Shared Filter State**: `RecordProvider` manages the global `selectedDateRange` (initialized to current month) which filters all transaction data across all tabs.
- **ChatProvider**: Manages streaming chat state, conversation history, and AI response parsing. Refers to `RecordProvider` for contextual data.
- **Consumption**: Use `context.read<T>()` for actions and `Consumer<T>` or `context.watch<T>()` for reactive UI updates.

## Services & Singletons
- **Pattern**: Static `_instance` with a private constructor and a factory.
- **Initialization**: Async init methods (e.g., `StorageService.init()`) called in `main()` before `runApp`.
- **Services**: `ApiService` (HTTP), `ChatApiService` (Chat payload), `StorageService` (SharedPreferences), `HomeWidget` (Widget integration).

## Data Layer (Repositories)
- **RecordRepository**: Singleton managing the SQLite `data.db`.
- **Transactions**: All balance-affecting operations (creating/updating/deleting records) are executed as atomic database transactions.
- **Schema**:
  - `Record`: Transaction data with foreign keys to `Category` and `MoneySource`.
  - `Category`: User-defined or default classification. Supports `parent_id` for grouping.
  - `MoneySource`: Named sources with tracked balances.

## UI Architecture
Wally AI uses a single-screen architecture with a `PageView` for top-level navigation, supported by a navigation drawer and a bottom navigation bar.
- **HomeScreen**: The core container. It holds the `Scaffold`, `AppBar`, `Drawer`, `BottomNavigationBar`, and a `PageView`.
- **GlobalNavigationDrawer**: Custom drawer for high-level switches (Chat vs. Financials).
- **PageView**: Manages the horizontal tabs:
  1. **ChatTab**: Streaming AI chat interface.
  2. **RecordsTab**: Detailed transaction lists and stats.
  3. **CategoriesTab**: Hierarchical category management.
  4. **TestTab**: Developer tools (demo data, AI pattern testing).

### Controller Layer
- **PageController**: Managed by `HomeScreen` to programmatically transition between tabs.
- **Synchronization**: The `BottomNavigationBar` and `PageView` are linked via `onPageChanged` and `onTap` callbacks.

## Navigation Flow
1. **Initial View**: `main.dart` initializes all singleton services and sets `HomeScreen` as the entry widget.
2. **Tab Switching**:
   - Tapping `BottomNavigationBarItem` -> `_pageController.animateToPage(index)`.
   - Swiping screens -> `onPageChanged` syncs the `BottomNavigationBar` state.
3. **Contextual Headers**: The `AppBar` dynamically adapts its title and action buttons based on the active tab index.

```mermaid
graph TD
    A[HomeScreen] --> B[AppBar]
    A --> C[Drawer]
    A --> D[PageView]
    A --> E[BottomNavigationBar]
    
    D --> F[ChatTab]
    D --> G[RecordsTab]
    D --> H[CategoriesTab]
    D --> I[TestTab]
    
    E -- onTap --> D
    D -- onPageChanged --> E
    C -- Navigation --> D
```

## Initialization Flow
1. **main()**:
   - `WidgetsFlutterBinding.ensureInitialized()`.
   - Parallel init: `StorageService.init()`, `RecordRepository.init()`, `dotenv.load()`.
   - `AppConfig().init()`.
   - `HomeWidget.setAppGroupId()`.
   - Background update: `AiPatternService().updateUserPattern()` (fire-and-forget).
2. **runApp(MyApp)**: Providers initialized and data loaded (e.g., `RecordProvider()..loadAll()`).

## Networking
- **APIHelper**: Low-level HTTP implementation with JSON encoding and stream support.
- **ApiConfig**: Centralized management of base URLs, endpoint paths, and authentication tokens.
- **ApiService**: Higher-level wrapper for standardized requests.
- **ChatApiService**: Handles Dify-based streaming chat interactions.
- **AiPatternService**: Orchestrates context collection and requests for AI User Pattern analysis.

## Testing
- **Unit/Widget Tests**: Mirror the `lib/` directory in `test/`. Use `mocktail` for dependencies.
- **Mocking**: Services support dependency injection or mock setters (e.g., `RecordRepository.setMockDatabase`).
- **Execution**: Run `fvm flutter test`.
