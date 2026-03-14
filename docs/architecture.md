# Architecture

This document defines the core technologies and patterns used in the wallet_ai project.

Tech Stack:
- SDK Manager: FVM (Flutter Version Management) pinned to version 3.35.7 in .fvmrc.
- Framework: Flutter SDK version ^3.9.2.
- Language: Dart.
- State Management: Provider package for dependency injection and state updates.
- Networking: http package (standard library approach, chosen for simplicity over Dio).
- Storage: SharedPreferences (wrapped in a singleton for synchronous access).

Core Patterns:
- MultiProvider: Root-level provider setup in main.dart for global service access.
- Service Layer: All external logic is isolated in service classes (e.g., ApiService).
- Configuration: Centralized AppConfig singleton for environment-specific variables like baseUrl and timeouts.
- State Updates: ChangeNotifier used within providers to notify UI of data changes.
- Testing: flutter_test with mocktail for dependency mocking.
- Async Logic: Strict use of async/await for all network and heavy operations.
