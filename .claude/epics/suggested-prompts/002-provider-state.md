---
name: ChatProvider prompt interaction state management
status: closed
created: 2026-04-03T04:11:37Z
updated: 2026-04-03T04:28:47Z
complexity: moderate
recommended_model: sonnet
phase: 2
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/156"
depends_on: [001]
parallel: false
conflicts_with: []
files:
  - lib/providers/chat_provider.dart
prd_requirements:
  - FR-3
  - FR-4
  - FR-5
---

# T2: ChatProvider prompt interaction state management

## Context

T1 parses `suggestedPrompts` into a list on the provider. Now the provider needs state fields and methods to track which prompt is selected, whether action chips should show, and to remove the active prompt on send. This is the state backbone that the UI widget (T3) will consume.

## Description

Add `_activePromptIndex` and `_showingActions` fields to `ChatProvider`. Add `selectPrompt(int)`, `selectAction()`, and internal `_removeActivePrompt()` methods. Modify `sendMessage()` to remove the active prompt before processing the message. Per AD-1, all state lives in `ChatProvider` (not a separate notifier) because it tightly couples to the greeting and send lifecycle.

## Acceptance Criteria

- [ ] **FR-3 / Prompt selection:** Calling `selectPrompt(0)` on a provider with 2 prompts where `prompts[0].actions` is non-empty → `activePromptIndex == 0`, `showingActions == true`
- [ ] **FR-3 / No actions:** Calling `selectPrompt(0)` where `prompts[0].actions` is empty → `activePromptIndex == 0`, `showingActions == false`
- [ ] **FR-4 / Action selection:** Calling `selectAction()` → `showingActions == false`, `activePromptIndex` unchanged
- [ ] **FR-5 / Send removes active:** With `activePromptIndex == 0` and 2 prompts, calling `sendMessage("Bánh mì 15k")` → `suggestedPrompts` has 1 entry, `activePromptIndex == null`, `showingActions == false`
- [ ] **FR-5 / Send without active:** With `activePromptIndex == null`, calling `sendMessage("Grab 25k")` → `suggestedPrompts` unchanged
- [ ] **FR-5 / Last consumed:** With 1 prompt active, calling `sendMessage(...)` → `suggestedPrompts` is empty
- [ ] **FR-5 / Input cleared:** Active prompt persists through input text changes — only cleared by `sendMessage()`

## Implementation Steps

### Step 1: Add state fields
- In `lib/providers/chat_provider.dart`, add:
  - `int? _activePromptIndex;`
  - `bool _showingActions = false;`
  - `int? get activePromptIndex => _activePromptIndex;`
  - `bool get showingActions => _showingActions;`

### Step 2: Add selectPrompt method
- `void selectPrompt(int index)`:
  - `_activePromptIndex = index;`
  - `_showingActions = _suggestedPrompts[index].actions.isNotEmpty;`
  - `notifyListeners();`

### Step 3: Add selectAction method
- `void selectAction()`:
  - `_showingActions = false;`
  - `notifyListeners();`

### Step 4: Add _removeActivePrompt internal method
- `void _removeActivePrompt()`:
  - If `_activePromptIndex == null` → return
  - `_suggestedPrompts.removeAt(_activePromptIndex!);`
  - `_activePromptIndex = null;`
  - `_showingActions = false;`

### Step 5: Modify sendMessage
- In `sendMessage(String content)`, BEFORE the existing `if (content.trim().isEmpty) return;` early check:
  - Save `final hadActivePrompt = _activePromptIndex != null;`
  - If `hadActivePrompt` → call `_removeActivePrompt()`, then `notifyListeners()`
- This ensures prompt removal happens even if content is empty (per FR-5 edge case: input cleared, active prompt still removed on send)

## Interface Contract

### Receives from T1 (001):
- Field: `List<SuggestedPrompt> _suggestedPrompts` — populated by `_handleStream()` greeting parse
- Class: `SuggestedPrompt` from `lib/models/suggested_prompt.dart` — has `.actions` (List\<String\>) and `.prompt` (String)

### Produces for T3 (003):
- Getters: `suggestedPrompts`, `activePromptIndex`, `showingActions` — consumed via `Consumer<ChatProvider>` in ChatTab
- Methods: `selectPrompt(int)`, `selectAction()` — called by widget tap handlers
- Behavior: `sendMessage()` removes active prompt automatically — ChatTab's `_handleSend()` needs no modification

## Technical Details

- **Approach:** AD-1 — all state in ChatProvider, no separate notifier
- **Files to modify:** `lib/providers/chat_provider.dart`
- **Patterns to follow:** See existing `_isStreaming` / `_error` pattern for state + getter + notifyListeners
- **Edge cases:**
  - `selectPrompt` called with out-of-bounds index → should not happen (UI controls index), but could add bounds check
  - `_removeActivePrompt` called when list is empty → `_activePromptIndex` is null, early return handles it
  - `sendMessage` called rapidly twice → first removes prompt, second finds `_activePromptIndex == null`, skips removal

## Tests to Write

### Unit Tests
- `test/providers/chat_provider_test.dart`
  - Test: `selectPrompt(0)` with non-empty actions → `activePromptIndex == 0`, `showingActions == true`
  - Test: `selectPrompt(0)` with empty actions → `activePromptIndex == 0`, `showingActions == false`
  - Test: `selectAction()` → `showingActions == false`
  - Test: `sendMessage()` with active prompt → prompt removed, list shrinks by 1, indices reset
  - Test: `sendMessage()` without active prompt → list unchanged
  - Test: `sendMessage()` with last prompt active → list empty, chip bar should disappear
  - Test: `sendMessage("")` with active prompt → prompt still removed (empty send edge case)

## Verification Checklist

- [ ] All unit tests pass: `fvm flutter test test/providers/chat_provider_test.dart`
- [ ] No regression: `fvm flutter test`

## Dependencies

- **Blocked by:** T1 (001) — needs `_suggestedPrompts` field and `SuggestedPrompt` model
- **Blocks:** T3 (003) — UI widget depends on these getters and methods
- **External:** None
