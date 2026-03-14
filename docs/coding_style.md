# Coding Style

This document defines the implementation guidelines for simplicity and maintainability.

Guiding Principles:
- Simplicity: Choose the most direct solution. Avoid over-engineering.
- Singleton Services: Services that don't hold conversational state should be singletons called directly (e.g. `ApiService()`, `DatabaseService()`).
- Minimal Boilerplate: Use standardized utilities like `APIHelper` for repeated logic.
- AI-Friendly: Clean, predictable code.

Technical Rules:
- Secrets: Never hardcode keys. Use .env and access via AppConfig.
- Networking: All network calls must go through `ApiService`. Specialized services (e.g., `ChatApiService`) should utilize `ApiService` rather than calling `APIHelper` directly to maintain centralized URL and connection management.
- State: Use Providers only for UI-reactive state. Services handle the raw logic.
- Async: Initialize critical sync or high-latency dependencies in `main()` (e.g. `StorageService.init()`, `DatabaseService.init()`).
- Tests: Every service or provider must have a corresponding test.
- Mocks: Factory constructors in services allow injecting mocks/clients for testing.
