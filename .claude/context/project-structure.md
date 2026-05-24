---
created: 2026-05-24T05:30:37Z
last_updated: 2026-05-24T05:30:37Z
version: 1.0
author: Claude Code PM System
---

# Project Structure

## Root Layout
```
wallet-ai/
├── lib/                   # Flutter app source (61 .dart files)
├── test/                  # Unit/widget tests (35 .dart files, mirrors lib/)
├── tests/                 # Epic e2e + integration tests
│   ├── e2e/
│   └── integration/
├── android/               # Android host (Kotlin + Glance widget)
├── ios/                   # iOS host
├── macos/ linux/          # Desktop hosts (default Flutter scaffold)
├── assets/                # images/, fonts/, onboarding/, .env
├── docs/
│   ├── features/          # Per-feature user-facing docs (REQUIRED to keep updated)
│   ├── server/            # Server-side spec mirrors (wallyai scope)
│   ├── architecture.md
│   ├── coding_style.md
│   └── context.md
├── project_context/       # Developer source-of-truth (architecture, context, style)
├── scripts/               # Dev helper scripts
├── .claude/               # CCPM agent system: commands, rules, context, epics
├── .fvm/ .fvmrc           # FVM-pinned Flutter version
├── pubspec.yaml
├── analysis_options.yaml
├── firebase.json
└── CLAUDE.md              # Mandatory project instructions for AI agents
```

## `lib/` Organization
```
lib/
├── main.dart              # App entry, MultiProvider wiring, async init
├── firebase_options.dart
├── components/            # Reusable widgets (chat_bubble, record_widget, …)
│   └── popups/            # Modal popups (edit_record, transfer, onboarding, …)
├── configs/               # app_config, api_config, chat_config, l10n_config
├── helpers/               # api_helper (HTTP), currency_helper
├── models/                # Record, Category, MoneySource, ChatMessage, …
├── providers/             # ChangeNotifier providers (Chat, Record, Locale)
├── repositories/          # record_repository (SQLite singleton)
├── screens/
│   └── home/
│       ├── home_screen.dart   # Scaffold + AppBar + Drawer + PageView + bottom nav
│       └── tabs/              # ChatTab, RecordsTab, CategoriesTab, TestTab
├── services/              # Singleton services (api, chat_api, storage, …)
└── screens.dart, providers.dart, etc.  # Barrel files
```

## Barrel-file Pattern
Every leaf directory exports its public surface through a single `<dir>.dart` barrel file (`components.dart`, `providers.dart`, `services.dart`, `models.dart`, `configs.dart`, `helpers.dart`, `repositories.dart`, `screens.dart`). External imports always go through the barrel: `import 'package:wallet_ai/providers/providers.dart'`.

## Test Layout
- `test/` — unit and widget tests, mirroring `lib/` 1:1.
- `tests/e2e/epic_{name}/` — end-to-end epic flows.
- `tests/integration/epic_{name}/` — integration-level epic flows.
- Run with `fvm flutter test` (root) or `fvm flutter test tests/` (epics).

## Android Host
- `android/app/build.gradle.kts` — Compose enabled (`buildFeatures.compose = true`); explicit `androidx.glance:glance-appwidget` + `glance-material3` at `1.1.0`; `resolutionStrategy.force` pins glance to `1.1.1` to override `home_widget`'s `1.+`.
- `MyWidgetReceiver.kt` + `AppWidget.kt` — Glance-based home widget for monthly totals.

## `.claude/` Layout
- `commands/pm/*` — CCPM slash-command definitions.
- `rules/*` — Standard patterns (frontmatter, git, GitHub ops, delegation, debug journal).
- `context/` — This directory.
- `epics/` — Per-epic working dirs.
- `verify/` — Verification artifacts.

## File-naming Conventions
- Files: `snake_case.dart` (e.g., `chat_provider.dart`, `edit_record_popup.dart`).
- Tests: `<source>_test.dart`.
- Epic test dirs: `epic_<slug>/`.
- Per-feature doc: `docs/features/<slug>.md`.
