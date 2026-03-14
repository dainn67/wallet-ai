# Context

This document provides a map of the codebase and service responsibilities.

File Structure:
- .env: Local secrets (ignored by git).
- .env.example: Template for environment variables.
- lib/config/app_config.dart: Environment settings and secrets access.
- lib/helpers/api_helper.dart: Core utility for making HTTP requests (GET, POST, Stream).
- lib/services/api_service.dart: Singleton for general REST requests (wraps APIHelper).
- lib/services/chat_api_service.dart: Singleton for streaming chat requests (wraps ApiService).
- lib/services/storage_service.dart: Singleton for synchronous persistent storage.
- lib/providers/chat_provider.dart: Manages chat UI state and stream subscriptions.
- lib/main.dart: App entry and startup initialization.
- docs/: AI context and project documentation.

Key Components:
- ApiService: Standard GET/POST/etc using APIHelper.
- ChatApiService: SSE (Server-Sent Events) streaming for LLM interactions using ApiService.
- StorageService: Sync access to SharedPreferences.
- AppConfig: Source of truth for URLs and API keys (via flutter_dotenv).

Commands:
- Install: fvm flutter pub get
- Run: fvm flutter run
- Test: fvm flutter test
