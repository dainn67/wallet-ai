# Context

This document provides a map of the codebase and service responsibilities.

File Structure:
- .env: Local secrets (ignored by git).
- .env.example: Template for environment variables.
- lib/config/app_config.dart: Environment settings and secrets access via flutter_dotenv.
- lib/helpers/api_helper.dart: Core utility for making HTTP requests (GET, POST, Stream).
- lib/services/api_service.dart: Singleton for general REST requests (wraps APIHelper).
- lib/services/chat_api_service.dart: Singleton for specialized chat streaming logic (wraps `ApiService`).
- lib/services/storage_service.dart: Singleton for synchronous persistent storage.
- lib/services/database_service.dart: Singleton for SQLite-based transactional storage.
- lib/models/chat_stream_response.dart: Structured response model for chat API chunks.
- lib/models/chat_message.dart: Represents conversation turns, now includes optional `List<Record>` for transaction data.
- lib/providers/chat_provider.dart: Manages chat UI state, message history, server session continuity (conversationId), and relational data extraction.
- lib/main.dart: App entry, style configuration, and startup initialization.
- docs/: AI context and project documentation.

Key Components:
- ApiService: Standardized GET/POST/Stream requests using APIHelper.
- ChatApiService: SSE (Server-Sent Events) streaming for LLM interactions.
- StorageService: Sync access to SharedPreferences for simple flags and settings.
- DatabaseService: Relational storage for transactions and wallet data. Supports name-to-ID lookup for AI-driven record creation.
- AppConfig: Centralized source of truth for URLs and API keys.
- ChatProvider: Hybrid state manager for UI, server-side session persistence, and intelligent data parsing from stream.

Commands:
- Install: fvm flutter pub get
- Run: fvm flutter run
- Test: fvm flutter test
