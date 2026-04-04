---
name: SuggestedPromptsBar widget + ChatTab integration
status: closed
created: 2026-04-03T04:11:37Z
updated: 2026-04-03T04:11:37Z
complexity: moderate
recommended_model: sonnet
phase: 2
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/157"
depends_on: [002]
parallel: false
conflicts_with: []
files:
  - lib/components/suggested_prompts_bar.dart
  - lib/screens/home/tabs/chat_tab.dart
prd_requirements:
  - FR-2
  - FR-3
  - FR-4
  - FR-5
  - NFR-1
  - NFR-2
---

# T3: SuggestedPromptsBar widget + ChatTab integration

## Context

T1 parses prompts, T2 manages selection state. Now we need to render the chip bar and wire it to the text input. The chip bar sits above the chat input in ChatTab's Column, shows either prompt chips or action chips (mutually exclusive), and interacts with `TextEditingController` for pre-fill/append.

## Description

Create `SuggestedPromptsBar` as a stateless widget (AD-3) that renders a horizontal scrollable row of chips. It has two modes: prompt mode (shows prompt names) and action mode (shows action amounts for the active prompt). Insert it into ChatTab's Column layout between the streaming indicator and input area. Wire tap callbacks to update `TextEditingController` and call provider methods. The widget uses `Consumer<ChatProvider>` for reactive rebuilds.

## Acceptance Criteria

- [ ] **FR-2 / Visible:** When `suggestedPrompts` has 2 entries, a horizontal chip row appears above the input with 2 chips
- [ ] **FR-2 / Hidden:** When `suggestedPrompts` is empty, no chip bar is rendered — layout identical to pre-feature state
- [ ] **FR-3 / Prompt tap:** Tapping "Bánh mì" chip → input text set to "Bánh mì", focus gained, chip bar replaces prompt chips with action chips ["15k", "20k"]
- [ ] **FR-3 / No actions:** Tapping a prompt with empty actions → input pre-filled, chip bar disappears (no actions to show)
- [ ] **FR-4 / Action tap:** Tapping "15k" action chip → input becomes "Bánh mì 15k", action chips hidden
- [ ] **FR-5 / Send removes:** After send with active prompt, chip bar shows remaining prompts (not action chips)
- [ ] **NFR-1 / No shift:** Chip bar appears in same frame as greeting, no visible layout jump
- [ ] **NFR-2 / No overlap:** Message list bottom padding accounts for chip bar height; no bubble occluded

## Implementation Steps

### Step 1: Create SuggestedPromptsBar widget
- Create `lib/components/suggested_prompts_bar.dart`
- Stateless widget with parameters:
  - `List<SuggestedPrompt> prompts`
  - `int? activePromptIndex`
  - `bool showingActions`
  - `ValueChanged<int> onPromptTap`
  - `ValueChanged<int> onActionTap`
- Build method:
  - If `showingActions && activePromptIndex != null`:
    - Render horizontal list of action chips from `prompts[activePromptIndex].actions`
    - Each chip calls `onActionTap(actionIndex)`
  - Else:
    - Render horizontal list of prompt chips from `prompts`
    - Each chip calls `onPromptTap(promptIndex)`
- Use `Container` with fixed height (~48px) and horizontal `SingleChildScrollView` containing a `Row`/`Wrap` of `ActionChip` widgets
- Style chips with Poppins font, matching existing app theme (see `lib/configs/app_theme.dart` or similar)
- Add horizontal padding matching the input area padding for visual alignment

### Step 2: Insert into ChatTab Column
- In `lib/screens/home/tabs/chat_tab.dart`, locate the `Column` children:
  - Currently: `Expanded(ListView)` → `StreamingIndicator` → `_buildInputArea()`
  - After: `Expanded(ListView)` → `StreamingIndicator` → `SuggestedPromptsBar` → `_buildInputArea()`
- Wrap the `SuggestedPromptsBar` insertion with `Consumer<ChatProvider>`:
  ```dart
  Consumer<ChatProvider>(
    builder: (context, provider, _) {
      if (provider.suggestedPrompts.isEmpty) return const SizedBox.shrink();
      return SuggestedPromptsBar(
        prompts: provider.suggestedPrompts,
        activePromptIndex: provider.activePromptIndex,
        showingActions: provider.showingActions,
        onPromptTap: (index) => _onPromptTap(provider, index),
        onActionTap: (index) => _onActionTap(provider, index),
      );
    },
  ),
  ```

### Step 3: Wire onPromptTap callback
- In ChatTab, create `_onPromptTap(ChatProvider provider, int index)`:
  - `_controller.text = provider.suggestedPrompts[index].prompt;`
  - `_controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));` (cursor at end)
  - `provider.selectPrompt(index);`
  - `_focusNode.requestFocus();`

### Step 4: Wire onActionTap callback
- In ChatTab, create `_onActionTap(ChatProvider provider, int index)`:
  - `final action = provider.suggestedPrompts[provider.activePromptIndex!].actions[index];`
  - `_controller.text = '${_controller.text} $action';`
  - `_controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));`
  - `provider.selectAction();`

### Step 5: Verify no _handleSend changes needed
- Confirm that the existing `_handleSend()` calls `chatProvider.sendMessage(_controller.text)` — this already triggers prompt removal via T2's sendMessage modification. No changes to `_handleSend()`.

## Interface Contract

### Receives from T2 (002):
- Getters on `ChatProvider`: `suggestedPrompts` (List\<SuggestedPrompt\>), `activePromptIndex` (int?), `showingActions` (bool)
- Methods on `ChatProvider`: `selectPrompt(int index)`, `selectAction()`
- Behavior: `sendMessage()` auto-removes active prompt — no extra widget logic needed

## Technical Details

- **Approach:** AD-3 — standalone stateless widget, ChatTab wires callbacks
- **Files to create:** `lib/components/suggested_prompts_bar.dart`
- **Files to modify:** `lib/screens/home/tabs/chat_tab.dart` — add Consumer block + two callback methods
- **Patterns to follow:**
  - See `lib/components/chat_bubble.dart` for component extraction pattern
  - See existing `Consumer<ChatProvider>` usage in ChatTab for provider wiring
  - See existing `_controller` usage in ChatTab for TextEditingController manipulation
- **Edge cases:**
  - `activePromptIndex` is out of bounds (prompt list shrank) → guard with bounds check before accessing actions
  - Chip bar renders with 0 prompts after all consumed → `SizedBox.shrink()` returns empty space, Column adjusts naturally
  - Keyboard appears when focus requested → message list auto-scrolls via existing `_onChatProviderUpdate` listener

## Tests to Write

### Widget Tests
- `test/screens/chat_tab_test.dart`
  - Test: Mock `suggestedPrompts` returns 2 prompts → `SuggestedPromptsBar` found in widget tree
  - Test: Mock `suggestedPrompts` returns empty → `SuggestedPromptsBar` not in widget tree
  - Test: Tap prompt chip → verify `_controller.text` updated (may need to verify via `find.text` on TextField)

## Verification Checklist

- [ ] All widget tests pass: `fvm flutter test test/screens/chat_tab_test.dart`
- [ ] No regression: `fvm flutter test`
- [ ] Manual check: Run app with stored pattern → chip bar visible above input after greeting
- [ ] Manual check: Tap prompt → input filled, action chips shown
- [ ] Manual check: Tap action → amount appended, actions hidden
- [ ] Manual check: Send → prompt removed, remaining prompts shown
- [ ] Manual check: Scroll to bottom of message list → no overlap with chip bar

## Dependencies

- **Blocked by:** T2 (002) — needs provider getters and methods
- **Blocks:** T4 (004) — comprehensive test coverage
- **External:** None
