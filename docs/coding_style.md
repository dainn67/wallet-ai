# Coding Style

This document defines the implementation guidelines for simplicity and maintainability.

Guiding Principles:
- Simplicity: Choose the most direct solution. Avoid over-engineering and complex abstractions.
- Standard Tools: Prioritize Dart/Flutter standard libraries and lightweight packages over feature-heavy alternatives.
- Minimal Boilerplate: Keep code concise and readable. If a solution is too verbose, find a simpler way.
- AI-Friendly: Write clear, predictable code that is easy for AI to assist with and humans to maintain.

Technical Rules:
- Networking: Use ApiService for all calls. Do not instantiate http.Client in UI or providers.
- State: Keep providers small and focused on one responsibility.
- Errors: Always throw or return ApiException for network-related failures.
- Async: Never block the UI thread. Use Future/Stream correctly.
- Tests: Every service or provider must have a corresponding test file in the test/ directory.
- Mocks: Use mocktail for mocks to keep test setups clean and readable.
- Formatting: Run 'dart format .' before every commit.
