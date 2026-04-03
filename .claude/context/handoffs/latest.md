---
epic: suggested-prompts
task: 002-provider-state
status: completed
created: 2026-04-03T04:28:47Z
updated: 2026-04-03T04:28:47Z
---

# Handoff: T2 ChatProvider prompt interaction state management

## Status
COMPLETE — all 13 tests pass, no analyze issues.

## What Was Done

- Added `_activePromptIndex` (int?) and `_showingActions` (bool) fields to `ChatProvider` with public getters.
- Added `@visibleForTesting` helper `setTestSuggestedPrompts()` for test setup.
- Added `selectPrompt(int index)` method: sets `_activePromptIndex`, sets `_showingActions` based on whether prompt has actions, calls `notifyListeners()`.
- Added `selectAction()` method: sets `_showingActions = false`, calls `notifyListeners()`.
- Added `_removeActivePrompt()` private method: guards on null `_activePromptIndex`, removes prompt from list, resets both fields.
- Modified `sendMessage()`: calls `_removeActivePrompt()` + `notifyListeners()` BEFORE the empty-content guard, so empty sends still clear the active prompt (FR-5).
- Added 7 new unit tests covering all acceptance criteria; all 13 tests pass.

## Files Changed

- `lib/providers/chat_provider.dart` (fields, getters, methods, sendMessage modified)
- `test/providers/chat_provider_test.dart` (7 new tests added)

## Warnings for T3

- `selectPrompt(index)` does not bounds-check — UI must only pass valid indices.
- `_suggestedPrompts` is a mutable list reference; T3 should use the `suggestedPrompts` getter (returns the list directly, not unmodifiable — treat as read-only).
- After `sendMessage()` removes the active prompt, `suggestedPrompts` list shrinks by 1. T3 chip bar should check `suggestedPrompts.isEmpty` to decide visibility.
- `showingActions` is independent of `activePromptIndex` — T3 must check both as needed.
