---
epic: suggested-prompts
task: 003-ui-widget
status: completed
created: 2026-04-03T05:00:00Z
updated: 2026-04-03T05:00:00Z
---

# Handoff: T3 SuggestedPromptsBar widget + ChatTab integration

## Status
COMPLETE — analyze clean, test failures match pre-existing baseline (4 failures, all unrelated to this epic).

## What Was Done

- Created `lib/components/suggested_prompts_bar.dart`: stateless widget with two modes — prompt chips (when `!showingActions`) and action chips (when `showingActions && activePromptIndex != null`). Uses `SizedBox(height: 48)` + `SingleChildScrollView` + `Row` of `ActionChip` widgets. Guards on bounds check before accessing actions.
- Added export to `lib/components/components.dart`.
- Modified `lib/screens/home/tabs/chat_tab.dart`: inserted `Consumer<ChatProvider>` block between `_StreamingIndicator` and `_buildInputArea()` rendering `SuggestedPromptsBar` when `suggestedPrompts.isNotEmpty`. Added `_onPromptTap()` and `_onActionTap()` callbacks using `FocusScope.of(context).requestFocus(widget.focusNode)`.
- Fixed 5 test files (`chat_tab_test.dart`, `chat_tab_polish_test.dart`, `home_screen_test.dart`, `home/home_screen_test.dart`, `home/home_localization_test.dart`) — added stubs for `suggestedPrompts`, `activePromptIndex`, `showingActions` on `MockChatProvider`.

## Files Changed

- `lib/components/suggested_prompts_bar.dart` (created)
- `lib/components/components.dart` (export added)
- `lib/screens/home/tabs/chat_tab.dart` (Consumer block + 2 callback methods)
- `test/screens/chat_tab_test.dart` (mock stubs)
- `test/screens/chat_tab_polish_test.dart` (mock stubs)
- `test/screens/home_screen_test.dart` (mock stubs)
- `test/screens/home/home_screen_test.dart` (mock stubs)
- `test/screens/home/home_localization_test.dart` (mock stubs)

## Notes for T4

- `_focusNode` does not exist in ChatTab — it uses `widget.focusNode` (nullable, passed from parent). `_onPromptTap` uses `FocusScope.of(context).requestFocus(widget.focusNode)`.
- No `_handleSend()` changes were made.
- Pre-existing failures (4): `l10n_integration_test.dart` SC-1/SC-3 (ApiException), `ai_context_service_test.dart` (missing file). All unrelated to this epic.
- T4 should add widget tests for `SuggestedPromptsBar` in `test/components/` and integration tests in `test/screens/chat_tab_test.dart`.
