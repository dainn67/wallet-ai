---
epic: suggested-prompts
task: 001-model-and-parsing
status: completed
created: 2026-04-03T04:21:10Z
updated: 2026-04-03T04:21:10Z
---

# Handoff: T1 SuggestedPrompt model + greeting JSON parsing branch

## Status
COMPLETE — all 6 tests pass, no analyze issues.

## What Was Done

- Created `lib/models/suggested_prompt.dart` with `prompt` (String) and `actions` (List<String>) fields, `fromJson` factory, and `toString()` override.
- Exported from `lib/models/models.dart`.
- Added `_suggestedPrompts` field and `suggestedPrompts` getter to `ChatProvider`.
- Refactored `_handleStream()` onDone JSON parsing: decode first, branch on type — Map with `suggestedPrompts` key parses prompts; List runs existing record logic (unchanged). Wrapped in try-catch (NFR-3).
- Changed `parts[1]` to `parts.sublist(1).join(ChatConfig.delimiter)` to handle multiple delimiters correctly.
- Added 5 new unit tests to `test/providers/chat_provider_test.dart`; all 6 tests pass.

## Files Changed

- `lib/models/suggested_prompt.dart` (new)
- `lib/models/models.dart` (export added)
- `lib/providers/chat_provider.dart` (field + getter + onDone refactor)
- `test/providers/chat_provider_test.dart` (5 new tests added)

## Warnings for T2

- `_suggestedPrompts` is not reset at the start of each `_handleStream` call. T2 should add a reset if stale prompts need clearing between conversations.
- `suggestedPrompts` getter returns the list reference directly — T2 may want to wrap with `List.unmodifiable()` for safety.
