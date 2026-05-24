# Wally AI

A Flutter mobile app for personal finance tracking through natural-language chat. Tell the assistant what you spent or earned — "coffee 50k from cash" — and the AI parses it into a structured record saved locally in SQLite. Built to collapse expense logging into a single chat message and keep activation energy near zero.

## Features

### Chat & AI
- **Streaming AI chat** with the Dify-based backend; partial display + trailing structured JSON for records / prompts.
- **Image attachments** in chat (up to 5 per message, compressed JPEG).
- **Auto-scroll** on send and on every streaming chunk.
- **Suggested Prompts** chip bar for returning users (one-tap entry).
- **Suggest Category banner** — inline confirm/cancel when the AI is unsure of the category.
- **AI User Pattern + Adaptive Greeting** — background analysis personalizes the launch greeting.
- **Transfer from chat** — `type: 'transfer'` records persisted atomically as a single dual-update row.

### Records, Categories, Money Sources
- **Records tab** — monthly filter, sort by `occurredAt DESC`, RecordsOverview card with mask toggle.
- **Categories tab** — hierarchical (parent/sub) with monthly totals + drill-down bottom sheet.
- **Money sources** with atomic balance tracking; per-source transfer popup.
- **Edit / delete** via `EditRecordPopup` and `EditSourcePopup`.

### Platform & Settings
- **English / Vietnamese** UI with first-launch auto-detection of language + currency.
- **Currency selection** included in AI prompt context.
- **Onboarding** multi-step dialog on first launch.
- **Glance home-screen widget** (Android) mirroring monthly totals.
- **Share App** via system share sheet (Play Store URL; App Store TBD).

## Tech Stack

- **Flutter** (Material 3), **Dart `^3.9.2`**.
- **FVM**-pinned Flutter version (`.fvmrc`) — all commands run via `fvm`.
- **Provider** for reactive UI state; singletons for services + repositories.
- **`sqflite`** for local persistence (SQLite); `sqflite_common_ffi` for in-memory test DBs.
- **`http`** wrapped by `ApiHelper` → `ApiService` → specialized services.
- **`firebase_core`** initialized (no active cloud features yet).
- **`home_widget`** + native Glance widget for Android home-screen monthly totals.
- **`image_picker` + `flutter_image_compress`** for chat image attachments.
- **`share_plus`** for the drawer Share App entry.
- **Fonts**: Poppins via **local assets only** — `google_fonts` is prohibited.
- **Lints**: `flutter_lints` (default ruleset).
- **Mocks**: `mocktail`.

## Getting Started

### Prerequisites
- [FVM](https://fvm.app/) installed (`brew tap leoafarias/fvm && brew install fvm`).
- Android Studio + Android SDK (compileSdk 36).
- Xcode (for iOS builds).
- A `.env` file at project root — see `.env.example` for the required keys.

### Setup
```bash
fvm install                  # install pinned Flutter version
fvm flutter pub get          # install Dart deps
```

### Run
```bash
fvm flutter run              # debug build on connected device/emulator
fvm flutter run --release    # release build
fvm flutter build apk --debug
```

### Test
```bash
fvm flutter test             # unit + widget tests (mirrors lib/)
fvm flutter test tests/      # epic e2e + integration tests
```

## Project Structure

```
wallet-ai/
├── lib/
│   ├── main.dart              # entry, MultiProvider, async init
│   ├── components/            # reusable widgets
│   │   └── popups/            # modal popups (edit_record, transfer, …)
│   ├── configs/               # app_config, api_config, chat_config, l10n_config
│   ├── helpers/               # api_helper (HTTP), currency_helper
│   ├── models/                # Record, Category, MoneySource, ChatMessage, …
│   ├── providers/             # Chat, Record, Locale (ChangeNotifier)
│   ├── repositories/          # record_repository (SQLite singleton)
│   ├── screens/home/          # HomeScreen + ChatTab/RecordsTab/CategoriesTab/TestTab
│   └── services/              # api, chat_api, storage, ai_pattern, image_*, …
├── test/                      # unit + widget tests (mirrors lib/)
├── tests/                     # epic e2e + integration tests
├── android/                   # Kotlin host + Glance widget
├── ios/                       # iOS host
├── assets/                    # images, fonts, onboarding, .env
├── docs/
│   ├── features/              # per-feature user-facing docs (kept in sync)
│   └── server/                # mirrors of server-side specs (wallyai scope)
├── project_context/           # developer source of truth
│   ├── architecture.md
│   ├── context.md
│   └── coding_style.md
├── .claude/                   # CCPM agent system (commands, rules, context, epics)
├── pubspec.yaml
└── CLAUDE.md                  # mandatory project instructions for AI agents
```

### Barrel-file convention
Every leaf directory exposes a `<dir>.dart` barrel re-exporting its public surface. First-party imports go through the barrel:
```dart
import 'package:wallet_ai/providers/providers.dart';
```

## Documentation

- `CLAUDE.md` — mandatory instructions for AI agents working in this repo.
- `project_context/architecture.md` — service / provider / repository architecture.
- `project_context/context.md` — app behavior, main flows, logic locations.
- `project_context/coding_style.md` — coding standards.
- `docs/features/<slug>.md` — per-feature behavior + technical flow (kept in sync with code).
- `.claude/context/` — generated baseline context for AI agents (`/context:create`, `/context:update`).

## Backend

The AI chat backend lives in the sibling repo `../chatbot-flow-server/` (project scope: `wallyai`). See `../chatbot-flow-server/docs/` for server architecture, prompts, and protocol details.
