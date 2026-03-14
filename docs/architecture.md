# Architecture

This document defines the core technologies and patterns used in the wallet_ai project.

Tech Stack:
- SDK Manager: FVM (Flutter Version Management) pinned to version 3.35.7 in .fvmrc.
- Framework: Flutter SDK version ^3.9.2.
- Language: Dart.
- State Management: Provider package for reactive UI state.
- Networking: http package with APIHelper utility. ApiService wraps APIHelper, and specialized services like ChatApiService wrap ApiService. All use a singleton pattern.
- Storage: SharedPreferences wrapped in StorageService singleton for synchronous access.
- Environment: flutter_dotenv for managing API tokens and secrets.

Core Patterns:
- Service Layer: External logic isolated in singleton services (ApiService, ChatApiService, StorageService). Called directly where needed.
- Configuration: Centralized AppConfig singleton manages environment-specific variables and secrets from .env.
- Provider Pattern: Used for ChangeNotifier-based state (e.g., ChatProvider).
- Initialization: Heavy services (Storage, DotEnv) are initialized in main() before runApp().
- Testing: flutter_test with mocktail. Services support dependency injection in their factories for test mocking.
