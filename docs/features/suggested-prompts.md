# Suggested Prompts Feature Documentation

## Technical Overview
For returning users, the AI greeting response may include a `suggestedPrompts` JSON object after the `--//--` delimiter. ChatProvider detects this and populates a list of `SuggestedPrompt` items, which are displayed as interactive chips above the chat input in ChatTab. Users can tap a prompt chip to pre-fill the input, optionally tap an action chip to append a specific amount, then send — removing that prompt from the list.

## Technical Mapping

### UI Layer
- **ChatTab**: Hosts the chip bar via a `Consumer<ChatProvider>` block inserted between the streaming indicator and the input area. Implements `_onPromptTap` (clears input, pre-fills with prompt text, requests focus) and `_onActionTap` (appends action amount, hides action chips).
- **SuggestedPromptsBar** (`lib/components/suggested_prompts_bar.dart`): Stateless widget. Renders either prompt chips (default) or action chips (when `showingActions` is true and `activePromptIndex` is set). Fixed ~48px height with horizontal `SingleChildScrollView`. Hidden via `SizedBox.shrink()` in ChatTab when the prompt list is empty.

### Provider Layer
- **ChatProvider**: Manages all suggested prompt state.
  - `_suggestedPrompts`: Populated by the greeting JSON parse in `_handleStream()`.
  - `_activePromptIndex` / `_showingActions`: Tracks which prompt is selected and whether action chips are visible.
  - `selectPrompt(int index)`: Sets active prompt, enables action chips if the prompt has actions.
  - `selectAction()`: Hides action chips; active prompt index stays set until send.
  - `_removeActivePrompt()`: Removes the active prompt from the list and resets indices.
  - `sendMessage()`: Calls `_removeActivePrompt()` before the empty-content guard so the active prompt is always removed on send.

### Model Layer
- **SuggestedPrompt** (`lib/models/suggested_prompt.dart`): Read-only model with `prompt` (String) and `actions` (List\<String\>). Factory `fromJson()` handles missing fields gracefully.

## Response Format

The greeting stream may return one of two formats after `--//--`:

**Suggested prompts (returning user with stored pattern):**
```
greeting_text--//--{"suggestedPrompts": [{"prompt": "Bánh mì", "actions": ["15k", "20k"]}, ...]}
```

**Record array (expense parsing response):**
```
reply_text--//--[{"source_id": 1, "category_id": 2, "amount": 50000, ...}]
```

ChatProvider detects the type after `jsonDecode` — `Map` with `suggestedPrompts` key → parse prompts; `List` → existing record parsing. A try-catch ensures malformed JSON causes no crash.

## Interaction Flow

```
Greeting arrives with suggestedPrompts
    ↓
Chip bar appears above input (prompt chips)
    ↓
User taps prompt chip → input pre-filled, action chips replace prompt chips
    ↓
User taps action chip (optional) → amount appended, action chips hidden
    ↓
User sends → active prompt removed, remaining prompts shown (or bar hides if last)
```

## State Machine

| State | `suggestedPrompts` | `activePromptIndex` | `showingActions` | Bar displays |
|-------|--------------------|---------------------|------------------|--------------|
| Initial / no prompts | empty | null | false | Hidden |
| After greeting | [P1, P2, ...] | null | false | Prompt chips |
| After prompt tap (with actions) | [P1, P2, ...] | 0 | true | Action chips |
| After prompt tap (no actions) | [P1, P2, ...] | 0 | false | Prompt chips |
| After action tap | [P1, P2, ...] | 0 | false | Prompt chips |
| After send | [P2, ...] | null | false | Prompt chips (or hidden) |
