# Context

This document provides a map of the codebase and service responsibilities.

File Structure:
- lib/config/app_config.dart: Environment and app-wide settings.
- lib/services/api_service.dart: Centralized http client and request logic.
- lib/services/api_exception.dart: Standardized error model for network failures.
- lib/services/storage_service.dart: Synchronous persistent storage using SharedPreferences.
- lib/providers/counter_provider.dart: Example state management implementation.
- lib/main.dart: App entry, MultiProvider configuration, and root widget.
- test/services/: Unit tests for API and error handling.
- docs/: AI context and project documentation.

Key Components and Responsibilities:
- ApiService: Manages GET, POST, PUT, DELETE requests. Uses http client. Handles JSON encoding/decoding and timeouts.
- StorageService: Handles persistent data storage. Uses singleton pattern for synchronous access.
- AppConfig: Returns environment-specific baseUrl (Dev/Prod) and Duration objects for timeouts.
- MultiProvider: Injects AppConfig, ApiService, and StorageService so they are available via context.read<T>().

Commands:
- Install: fvm flutter pub get
- Run: fvm flutter run
- Test: fvm flutter test
