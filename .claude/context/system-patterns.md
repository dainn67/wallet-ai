---
created: 2026-05-24T05:30:37Z
last_updated: 2026-05-24T05:30:37Z
version: 1.0
author: Claude Code PM System
---

# System Patterns

## High-Level Architecture
Single-screen Flutter app with a `PageView` of tabs, backed by Provider state and a SQLite repository layer. AI features are driven by a streaming chat pipeline against a Dify-based server.

```
UI (HomeScreen + Tabs)
  └─ Providers (ChangeNotifier)
       ├─ ChatProvider          ── ChatApiService ── ApiService ── ApiHelper ── HTTP
       ├─ RecordProvider        ── RecordRepository ── sqflite
       └─ LocaleProvider        ── StorageService ── shared_preferences
Singletons (no provider): ApiService, ChatApiService, StorageService, RecordRepository,
                          AiPatternService, ImagePickerService, ImageProcessingService, ToastService
```

## State Management
- **Provider package**, `MultiProvider` wired in `main.dart`.
- **Reactive UI only** — providers expose `ChangeNotifier`; services and repositories hold the actual data + logic.
- **`context.read<T>()`** for actions, **`Consumer<T>` / `context.watch<T>()`** for reactive rebuilds.
- **`ChangeNotifierProxyProvider`** links `RecordProvider` and `LocaleProvider` into `ChatProvider` so the chat layer can read live category/source/locale state.

## Singleton Service Pattern
Every stateless cross-cutting service uses:
```dart
class XService {
  XService._();
  static final XService _instance = XService._();
  factory XService() => _instance;
}
```
Async init runs in `main()` before `runApp` (e.g., `StorageService.init()`, `RecordRepository.init()`, `dotenv.load()`).

## Data Layer
- **`RecordRepository`** owns the SQLite `data.db`.
- **Atomic transactions** wrap every balance-affecting operation (`createRecord`, `updateRecord`, `deleteRecord`). Source impacts apply via `_applyRecordImpact`, which handles income/expense/transfer math consistently — including the dual debit+credit for transfers.
- **Schema migrations** live in `lib/services/record_migration_service.dart`. Latest: v7→v8 added `occurred_at`; v8→v9 rebuilt the table to add nullable `target_source_id` + relax the `type` CHECK constraint.
- **In-memory aggregation** — `RecordProvider` caches loaded records and computes filtered totals/category aggregates in-memory; the DB is the source of truth, the provider is the cache + indexing layer.

## Streaming Chat Protocol
1. `ChatProvider.sendMessage` adds the user message and a placeholder assistant bubble (`isAnalyzing: true`) before opening the stream.
2. `ChatApiService.streamChat` returns a `Stream<ChatStreamResponse>` of partial chunks.
3. Each chunk appends to the assistant bubble's `content` and triggers `notifyListeners()`.
4. The chunk text may contain `--//--` (`ChatConfig.delimiter`) — UI stops showing content after the first occurrence; the parser continues collecting the post-delimiter JSON.
5. `onDone` decodes the trailing JSON:
   - `Map` with `suggestedPrompts` → populates the chip bar.
   - `List` → builds `Record`s via `_buildRecordFromJson` (branches on `type`: `income`/`expense`/`transfer`); persists each via `RecordProvider.createRecord`; attaches them to the assistant bubble.
6. `_isStreaming` flips false; `_dbUpdateVersion++` lets listeners (e.g., RecordsTab) refresh.

## UI Patterns
- **`HomeScreen` shell** — `Scaffold` + `AppBar` + `Drawer` + `PageView` + `BottomNavigationBar`. `PageController` is the single source of truth for the active tab; nav bar and swipe sync via `onPageChanged`/`onTap`.
- **Auto-scroll on chat updates** — `ChatTab` listens to `ChatProvider`; while `isStreaming`, every notify schedules a post-frame `_scrollController.jumpTo(maxScrollExtent)`. `jumpTo` avoids `animateTo` conflicts under rapid chunks.
- **Popup-driven editing** — record/source edits open `EditRecordPopup` / `EditSourcePopup`; deletion goes through `ConfirmationDialog`. Transfers use `TransferPopup` (create) and `TransferInfoPopup` (read-only summary v1).
- **Inline AI banners** — `SuggestionBanner` renders inside `ChatBubble` when a record has a transient `suggestedCategory`; confirm/cancel mutates the in-memory record and (on confirm) the DB.
- **InkWell absorption** — setting `CategoryWidget.onTap` to a non-null callback intentionally absorbs taps so the wrapping `ExpansionTile` doesn't expand on row-body taps; the chevron alone toggles expansion.

## Networking
- All HTTP goes through `ApiHelper` (low-level) → `ApiService` (URL + auth wrapper) → specialized services (`ChatApiService`, `AiPatternService`).
- Streaming uses `http`'s chunked-body decoding; responses are line-delimited JSON parsed into `ChatStreamResponse`.
- `ApiConfig` centralizes base URLs and endpoint paths; secrets come from `AppConfig` (loaded from `.env`).

## Initialization Flow (`main.dart`)
1. `WidgetsFlutterBinding.ensureInitialized()`.
2. Parallel: `StorageService.init()`, `RecordRepository.init()`, `dotenv.load()`.
3. `AppConfig().init()`.
4. `HomeWidget.setAppGroupId(...)`.
5. Fire-and-forget `AiPatternService().updateUserPattern()`.
6. `runApp(MyApp)` → providers built; `RecordProvider..loadAll()`.
7. Once `RecordProvider` and `LocaleProvider` are ready, `ChatProvider._checkAndSendGreeting` triggers the adaptive `INIT_GREETING` chat flow.

## Testing
- Unit/widget tests under `test/` mirror `lib/`.
- Epic-level e2e + integration under `tests/e2e/epic_<name>/` and `tests/integration/epic_<name>/`.
- `mocktail` for mocks; `sqflite_common_ffi` for in-memory DB; services expose `setMock…` hooks where needed (e.g., `RecordRepository.setMockDatabase`).
- Always run `fvm flutter test` before committing.

## Living Docs Mandate
- `docs/features/<slug>.md` — user-facing per-feature docs; required to update when a feature changes.
- `project_context/architecture.md|context.md|coding_style.md` — developer source-of-truth; required to update on completed features or architectural changes.
