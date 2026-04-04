---
name: Unit tests + widget tests for suggested prompts
status: closed
created: 2026-04-03T04:11:37Z
updated: 2026-04-03T04:11:37Z
complexity: moderate
recommended_model: sonnet
phase: 3
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/158"
depends_on: [003]
parallel: false
conflicts_with: []
files:
  - test/providers/chat_provider_test.dart
  - test/screens/chat_tab_test.dart
prd_requirements:
  - FR-1
  - FR-2
  - FR-3
  - FR-4
  - FR-5
  - NFR-3
---

# T4: Unit tests + widget tests for suggested prompts

## Context

T1-T3 implement the full feature. This task adds comprehensive test coverage ensuring all PRD scenarios are verified, no regressions on existing record parsing, and edge cases are handled. Tests follow the existing mocktail pattern used throughout the project.

## Description

Add provider unit tests for JSON parsing, state management, and send removal. Add widget tests for chip bar visibility and interaction. Update existing mock providers to include the new `suggestedPrompts`, `activePromptIndex`, and `showingActions` getters so existing tests don't break.

## Acceptance Criteria

- [ ] **FR-1 / Parse test:** Unit test verifies greeting with suggestedPrompts JSON → prompts list populated correctly
- [ ] **FR-1 / Regression test:** Unit test verifies greeting with record array → records parsed normally, prompts empty
- [ ] **NFR-3 / Resilience test:** Unit test verifies malformed suggestedPrompts JSON → prompts empty, no crash
- [ ] **FR-3 / Selection test:** Unit test verifies `selectPrompt(0)` → correct state updates
- [ ] **FR-4 / Action test:** Unit test verifies `selectAction()` → `showingActions` false
- [ ] **FR-5 / Removal test:** Unit test verifies `sendMessage()` with active prompt → prompt removed
- [ ] **FR-2 / Visibility test:** Widget test verifies chip bar visible when prompts non-empty, hidden when empty
- [ ] **Regression:** All existing tests pass unchanged after adding new getters to mock

## Implementation Steps

### Step 1: Update MockChatProvider with new getters
- In `test/screens/chat_tab_test.dart`, find the existing `MockChatProvider` class
- Add stubs for the new getters:
  - `when(() => mockChatProvider.suggestedPrompts).thenReturn([]);`
  - `when(() => mockChatProvider.activePromptIndex).thenReturn(null);`
  - `when(() => mockChatProvider.showingActions).thenReturn(false);`
- This must be done FIRST so existing widget tests don't break on missing getter stubs

### Step 2: Add provider parsing tests
- In `test/providers/chat_provider_test.dart`, add a new `group('suggestedPrompts parsing')`:
  - Test `'parses suggestedPrompts from greeting JSON'`:
    - Set up `StreamController<ChatStreamResponse>` emitting greeting text + `--//--` + `{"suggestedPrompts": [{"prompt": "Bánh mì", "actions": ["15k", "20k"]}]}`
    - Verify `chatProvider.suggestedPrompts.length == 1`
    - Verify `chatProvider.suggestedPrompts[0].prompt == 'Bánh mì'`
    - Verify `chatProvider.suggestedPrompts[0].actions == ['15k', '20k']`
  - Test `'record array does not set suggestedPrompts'`:
    - Emit greeting + `--//--` + `[{"source_id": 1, "amount": "15000", ...}]`
    - Verify `chatProvider.suggestedPrompts.isEmpty`
    - Verify records were created (existing pattern)
  - Test `'no delimiter keeps suggestedPrompts empty'`:
    - Emit plain text greeting only
    - Verify `chatProvider.suggestedPrompts.isEmpty`
  - Test `'malformed JSON keeps suggestedPrompts empty'`:
    - Emit greeting + `--//--` + `{"suggestedPrompts": "not_a_list"}`
    - Verify `chatProvider.suggestedPrompts.isEmpty`
    - Verify no exception thrown
  - Test `'empty suggestedPrompts array'`:
    - Emit greeting + `--//--` + `{"suggestedPrompts": []}`
    - Verify `chatProvider.suggestedPrompts.isEmpty`

### Step 3: Add provider state management tests
- Add a new `group('suggestedPrompts interaction')`:
  - Set up provider with pre-loaded `suggestedPrompts` (parse a greeting first, or set directly if test helper exists)
  - Test `'selectPrompt sets active index and showingActions'`
  - Test `'selectPrompt with empty actions sets showingActions false'`
  - Test `'selectAction sets showingActions to false'`
  - Test `'sendMessage with active prompt removes it'`
  - Test `'sendMessage without active prompt leaves list unchanged'`
  - Test `'sendMessage with last prompt clears list'`

### Step 4: Add widget visibility tests
- In `test/screens/chat_tab_test.dart`, add:
  - Test `'shows SuggestedPromptsBar when prompts non-empty'`:
    - Mock `suggestedPrompts` to return 2 `SuggestedPrompt` objects
    - Pump widget
    - Verify `find.byType(SuggestedPromptsBar)` finds one widget
  - Test `'hides SuggestedPromptsBar when prompts empty'`:
    - Mock `suggestedPrompts` to return `[]`
    - Pump widget
    - Verify `find.byType(SuggestedPromptsBar)` finds nothing

### Step 5: Run full test suite
- Execute `fvm flutter test` and verify 0 failures across entire project

## Technical Details

- **Approach:** Follow existing mocktail patterns from `test/providers/chat_provider_test.dart` and `test/screens/chat_tab_test.dart`
- **Files to modify:** Both test files
- **Patterns to follow:**
  - See existing `'handles stream with records'` test in `chat_provider_test.dart` for streaming test setup with `StreamController<ChatStreamResponse>`
  - See existing `MockChatApiService.setMockInstance()` pattern for service injection
  - See existing `MultiProvider` setup in `chat_tab_test.dart` for widget test provider wiring
- **Edge cases:**
  - Mock provider must return consistent state (e.g., if `showingActions` is true, `activePromptIndex` must not be null)
  - Streaming tests must emit all chunks and close the stream before assertions

## Tests to Write

### Unit Tests
- `test/providers/chat_provider_test.dart`:
  - 5 parsing tests (happy path, record array, no delimiter, malformed, empty array)
  - 6 state tests (selectPrompt with/without actions, selectAction, sendMessage with/without/last active)

### Widget Tests
- `test/screens/chat_tab_test.dart`:
  - 2 visibility tests (chip bar shown/hidden based on prompts list)

## Verification Checklist

- [ ] All new tests pass: `fvm flutter test test/providers/chat_provider_test.dart`
- [ ] All widget tests pass: `fvm flutter test test/screens/chat_tab_test.dart`
- [ ] Full suite green: `fvm flutter test`
- [ ] No existing test modified in behavior (only mock setup added)

## Dependencies

- **Blocked by:** T3 (003) — needs complete feature implementation to test against
- **Blocks:** None — final task
- **External:** None
