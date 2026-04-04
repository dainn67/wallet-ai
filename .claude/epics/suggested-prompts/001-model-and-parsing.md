---
name: SuggestedPrompt model + greeting JSON parsing branch
status: closed
created: 2026-04-03T04:11:37Z
updated: 2026-04-03T04:21:10Z
complexity: moderate
recommended_model: sonnet
phase: 1
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/155"
depends_on: []
parallel: false
conflicts_with: []
files:
  - lib/models/suggested_prompt.dart
  - lib/providers/chat_provider.dart
prd_requirements:
  - FR-1
  - NFR-3
---

# T1: SuggestedPrompt model + greeting JSON parsing branch

## Context

The server already returns `suggestedPrompts` in the greeting JSON for returning users, but `ChatProvider._handleStream()` only parses record arrays. We need a new model and a branching parser to extract prompt data without breaking the existing record path.

## Description

Create the `SuggestedPrompt` data model and add a JSON branch in `ChatProvider._handleStream()` onDone block. Currently the parser assumes JSON after `--//--` is always a `List<dynamic>` of records. We need to `jsonDecode` first, check the type, then route: `Map` with `suggestedPrompts` key → parse prompts; `List` → parse records (existing). Per AD-2 from the epic, we detect by type check after decode, not try-catch cascading.

## Acceptance Criteria

- [ ] **FR-1 / Happy path:** When server returns `greeting_text--//--{"suggestedPrompts": [{"prompt": "Bánh mì", "actions": ["15k", "20k"]}]}`, `ChatProvider.suggestedPrompts` contains one `SuggestedPrompt` with `prompt: "Bánh mì"` and `actions: ["15k", "20k"]`
- [ ] **FR-1 / New user path:** When server returns plain text greeting with no `--//--` delimiter, `ChatProvider.suggestedPrompts` remains empty
- [ ] **FR-1 / Record path regression:** When JSON part is `[{record...}]`, records are parsed as before; `suggestedPrompts` remains empty
- [ ] **NFR-3 / Malformed JSON:** When JSON is `{"suggestedPrompts": "invalid"}` or unparseable, `suggestedPrompts` remains empty, no crash, greeting displays normally

## Implementation Steps

### Step 1: Create SuggestedPrompt model
- Create `lib/models/suggested_prompt.dart`
- Class with `final String prompt` and `final List<String> actions`
- Factory `SuggestedPrompt.fromJson(Map<String, dynamic> json)`:
  - `prompt = json['prompt'] as String`
  - `actions = List<String>.from(json['actions'] ?? [])`
- Follow `Record.fromMap()` pattern from `lib/models/record.dart` for style consistency
- Add `toString()` override for debug logging

### Step 2: Add suggestedPrompts field to ChatProvider
- In `lib/providers/chat_provider.dart`, add:
  - `List<SuggestedPrompt> _suggestedPrompts = [];`
  - `List<SuggestedPrompt> get suggestedPrompts => _suggestedPrompts;`
- Import `lib/models/suggested_prompt.dart`

### Step 3: Refactor _handleStream onDone JSON parsing
- In the `onDone` callback of `_handleStream()`, after `fullText.split(ChatConfig.delimiter)`:
  - If `parts.length >= 2`, get `jsonString = parts.sublist(1).join(ChatConfig.delimiter)`
  - Replace the direct `jsonDecode(jsonString)` cast to `List<dynamic>` with:
    ```
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic> && decoded.containsKey('suggestedPrompts')) {
        // Parse suggested prompts
        final promptsList = decoded['suggestedPrompts'] as List<dynamic>;
        _suggestedPrompts = promptsList
            .map((p) => SuggestedPrompt.fromJson(p as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } else if (decoded is List) {
        // Existing record parsing logic (move existing code here)
      }
    } catch (e) {
      // NFR-3: graceful failure — prompts stay empty, greeting continues
    }
    ```
- CRITICAL: Move the existing record parsing code INTO the `else if (decoded is List)` branch. Do not delete it.
- Error handling: The outer try-catch ensures malformed JSON doesn't crash.

## Technical Details

- **Approach:** AD-2 — jsonDecode first, type-check, then branch. One parse regardless of type.
- **Files to create:** `lib/models/suggested_prompt.dart` — lightweight read-only model
- **Files to modify:** `lib/providers/chat_provider.dart` — onDone block refactoring
- **Patterns to follow:** See `lib/models/record.dart` for fromMap/toMap style. See existing onDone block for record parsing reference.
- **Edge cases:**
  - JSON string is empty → caught by try-catch
  - `suggestedPrompts` key exists but value is not a list → caught by `as List<dynamic>` cast in try-catch
  - Individual prompt missing `prompt` or `actions` field → `fromJson` handles with defaults/nullability
  - Multiple `--//--` delimiters → `parts.sublist(1).join()` handles correctly (existing pattern)

## Tests to Write

### Unit Tests
- `test/providers/chat_provider_test.dart`
  - Test: Stream greeting with `suggestedPrompts` JSON → `chatProvider.suggestedPrompts` has correct entries with prompt and actions
  - Test: Stream greeting with record array `[{"source_id": 1, ...}]` → `chatProvider.suggestedPrompts` is empty, records parsed normally
  - Test: Stream greeting with no delimiter (plain text) → `chatProvider.suggestedPrompts` is empty
  - Test: Stream greeting with malformed JSON `{"suggestedPrompts": 123}` → `suggestedPrompts` is empty, no exception thrown
  - Test: Stream greeting with empty suggestedPrompts `{"suggestedPrompts": []}` → `suggestedPrompts` is empty list

## Verification Checklist

- [ ] All unit tests pass: `fvm flutter test test/providers/chat_provider_test.dart`
- [ ] No regression on existing tests: `fvm flutter test`
- [ ] Manual check: Run app with stored pattern, verify greeting loads without crash

## Dependencies

- **Blocked by:** None
- **Blocks:** T2 (needs `_suggestedPrompts` field and `SuggestedPrompt` model)
- **External:** Server `suggestedPrompts` JSON — already implemented
