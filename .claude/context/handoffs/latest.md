# Handoff: Task #115 → Task #116

## Completed
- Modified `ChatApiService.streamChat` to accept a `language` parameter and include it in the API request body.
- Updated `ChatProvider` to depend on `LocaleProvider` and pass the current language string ("English" or "Vietnamese") to the API service.
- Refactored `lib/main.dart` to use `ChangeNotifierProxyProvider2` for `ChatProvider`, ensuring it has access to both `RecordProvider` and `LocaleProvider`.

## Decisions Made
- Used explicit language strings ("English", "Vietnamese") instead of ISO codes to match current backend expectations.
- Standardized `ChatProvider` initialization via `ProxyProvider` to maintain clean dependency injection.

## Interfaces Exposed/Modified
```dart
// ChatApiService
Stream<ChatStreamResponse> streamChat(String message, {
  String? conversationId,
  String? categoryList,
  String? moneySourceList,
  String language = 'English', // New parameter
})

// ChatProvider
void update(RecordProvider rp, LocaleProvider lp) // Dependency sync
```

## State of Tests
- `test/providers/locale_provider_test.dart`: PASS (6 tests)
- `test/configs/l10n_config_test.dart`: PASS (2 tests)
- Regression tests pass after `main.dart` refactoring.

## Warnings for Next Task
- UI components in Task #116 should use `context.watch<LocaleProvider>()` to ensure they react to language changes.
- Ensure all hardcoded strings are moved to `L10nConfig`.

## Files Changed
- `lib/services/chat_api_service.dart` (modified)
- `lib/providers/chat_provider.dart` (modified)
- `lib/main.dart` (modified)
- `.claude/epics/update-language-and-currency/115.md` (closed)
