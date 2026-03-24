# Architecture

## Tooling
- **FVM**: Use `fvm` for all Flutter and Dart commands (e.g., `fvm flutter run`). Flutter version is pinned via `.fvmrc`.
- **Environment**: SDK `^3.9.2`. Material 3 enabled.

## Typography
- **Poppins**: The ONLY font family used. Served via **LOCAL ASSETS** to ensure full offline support.
- **Prohibited**: The `google_fonts` package is forbidden to prevent network-related rendering delays (FOUT).
- **Configuration**: Managed in `pubspec.yaml` (18 weights/styles) and applied via `ThemeData` in `main.dart`.

## State Management (Provider)
- **MultiProvider**: Set up in `main.dart`.
- **RecordProvider**: Central state for Records, MoneySources, and Categories. Reactive and synchronized with the repository.
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
  - `Category`: User-defined or default classification.
  - `MoneySource`: Named sources with tracked balances.

## Initialization Flow
1. **main()**:
   - `WidgetsFlutterBinding.ensureInitialized()`.
   - Parallel init: `StorageService.init()`, `RecordRepository.init()`, `dotenv.load()`.
   - `AppConfig().init()`.
   - `HomeWidget.setAppGroupId()`.
2. **runApp(MyApp)**: Providers initialized and data loaded (e.g., `RecordProvider()..loadAll()`).

## Networking
- **APIHelper**: Low-level HTTP requests (GET, POST, POST_STREAM).
- **ApiService**: High-level wrapper for `APIHelper`.
- **ChatApiService**: Specific logic for the Dify-based streaming chat API.

## Testing
- **Unit/Widget Tests**: Mirror the `lib/` directory in `test/`. Use `mocktail` for dependencies.
- **Mocking**: Services should support dependency injection or mock setters (e.g., `RecordRepository.setMockDatabase`).
- **Commands**: Run `fvm flutter test`.
