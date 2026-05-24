---
created: 2026-05-24T05:30:37Z
last_updated: 2026-05-24T05:30:37Z
version: 1.0
author: Claude Code PM System
---

# Tech Context

## Platform
- **Framework**: Flutter (Material 3).
- **Dart SDK**: `^3.9.2`.
- **Version manager**: FVM (`.fvmrc` pins the Flutter version). All Flutter/Dart commands use `fvm flutter …` / `fvm dart …`.
- **App version**: `1.2.2+28` (`pubspec.yaml`).

## Runtime Dependencies
| Package | Version | Purpose |
|---|---|---|
| `provider` | ^6.1.5+1 | State management (ChangeNotifier + MultiProvider) |
| `firebase_core` | ^3.6.0 | Firebase initialization |
| `package_info_plus` | ^9.0.0 | Read app version metadata |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |
| `http` | ^1.6.0 | HTTP transport (wrapped by `ApiHelper`) |
| `shared_preferences` | ^2.5.4 | Backing store for `StorageService` |
| `flutter_dotenv` | ^5.2.1 | Load `.env` for `AppConfig` |
| `sqflite` | ^2.4.2 | SQLite for `RecordRepository` |
| `intl` | ^0.19.0 | Date/number formatting |
| `home_widget` | ^0.9.0 | Native home-screen widget bridge |
| `meta` | ^1.16.0 | `@visibleForTesting`, etc. |
| `path` | ^1.9.1 | Filesystem path helpers |
| `path_provider` | ^2.1.5 | App documents directory |
| `flutter_native_splash` | ^2.4.7 | Splash screen generator |
| `collection` | ^1.18.0 | Iterable utilities |
| `flutter_image_compress` | ^2.3.0 | JPEG compression for chat image attachments |
| `image_picker` | ^1.1.2 | Camera + gallery image picking |
| `share_plus` | ^10.1.4 | Native share sheet (drawer Share App) |

## Dev Dependencies
| Package | Version | Purpose |
|---|---|---|
| `flutter_test` | sdk | Widget testing |
| `integration_test` | sdk | E2E integration tests |
| `sqflite_common_ffi` | ^2.3.0 | In-memory SQLite for test runs |
| `flutter_lints` | ^5.0.0 | Lint ruleset (via `analysis_options.yaml`) |
| `mocktail` | ^1.0.4 | Mock objects (preferred over mockito) |
| `change_app_package_name` | ^1.1.0 | Rename Android package id |
| `flutter_launcher_icons` | ^0.14.3 | Generate launcher icons |

## Android Toolchain
- **AGP**: 8.9.1 (pinned by Flutter SDK).
- **Kotlin**: 1.9.x (transitive).
- **`compileSdk`**: from `flutter.compileSdkVersion` (currently 36).
- **`androidx.glance` (Compose for App Widgets)**: declared at `1.1.0` in `android/app/build.gradle.kts`; `resolutionStrategy.force` pins to `1.1.1` to override `home_widget`'s `1.+` dynamic version (which resolves to `1.3.0-alpha01`, requires compileSdk 37 + AGP 9.1).
- **Compose**: enabled via `buildFeatures.compose = true`.

## Fonts
- **Poppins** only, served via local assets (`assets/fonts/`).
- `google_fonts` is **prohibited** to prevent FOUT.

## Backend
- Server lives in **sibling repo** `../chatbot-flow-server/`. Docs under `../chatbot-flow-server/docs/`. WalletAI scope is the `wallyai` project — ignore other projects in that repo (AIKaze, LinguaAI, Math Bear).
- Chat API uses Dify streaming protocol via `ChatApiService` → `ApiService` → `ApiHelper`.
- Secrets loaded from `.env` and exposed via `AppConfig` (e.g., `mainChatApiKey`).

## Firebase
- Configured via `firebase.json` and `lib/firebase_options.dart`.
- Initialized in `main.dart` via `Firebase.initializeApp(options: ...)`.

## Build Tools
- **FVM**: `fvm install`, `fvm flutter pub get`, `fvm flutter run`, `fvm flutter build apk --debug`, `fvm flutter test`.
- **Lints**: `package:flutter_lints/flutter.yaml` (no project-specific overrides in `analysis_options.yaml`).
