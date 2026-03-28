---
name: Extract ChatBubble to separate component file
status: open
created: 2026-03-28T17:50:49Z
updated: 2026-03-28T17:50:49Z
complexity: simple
recommended_model: sonnet
phase: 2
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/140"
depends_on: [001]
parallel: true
conflicts_with: []
files:
  - lib/screens/home/tabs/chat_tab.dart
  - lib/components/chat_bubble.dart
  - lib/components/components.dart
prd_requirements:
  - FR-5
  - FR-6
---

# Extract ChatBubble to separate component file

## Context

`ChatBubble` is a 68-line widget class defined inside `chat_tab.dart` (lines 150-222). It has its own build logic, renders message content, displays attached records, and launches the edit record popup. Per AD-3 and FR-5, it belongs in `lib/components/` as a reusable UI component, not embedded in a screen tab file.

## Description

Move the `ChatBubble` class from `chat_tab.dart` to a new file `lib/components/chat_bubble.dart`. Update imports in `chat_tab.dart`. Add the export to the `components.dart` barrel file. Keep `_StreamingIndicator` in `chat_tab.dart` (too small and single-use).

## Acceptance Criteria

- [ ] **FR-5 / Happy path:** `ChatBubble` class exists in `lib/components/chat_bubble.dart` with all its build logic and `_showEditRecordPopup` method
- [ ] **FR-5 / Happy path:** `chat_tab.dart` no longer contains the `ChatBubble` class definition
- [ ] **FR-5 / Happy path:** `components.dart` barrel file exports `chat_bubble.dart`
- [ ] **FR-6 / Behavior preservation:** Chat messages render identically (user bubbles right-aligned, assistant bubbles left-aligned with avatar)
- [ ] **FR-6 / Behavior preservation:** Tapping edit on a record in a chat bubble opens the EditRecordPopup and saves changes correctly
- [ ] **FR-6 / Edge case:** Messages with multiple records still display all records with edit buttons

## Implementation Steps

### Step 1: Create `lib/components/chat_bubble.dart`

- Create new file `lib/components/chat_bubble.dart`
- Move the entire `ChatBubble` class (lines 150-222 of chat_tab.dart) to this file
- Add required imports:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';
  import 'package:wallet_ai/models/models.dart';
  import 'package:wallet_ai/providers/providers.dart';
  import 'package:wallet_ai/components/components.dart';
  ```
- The `_showEditRecordPopup` method uses `context.read<RecordProvider>()` and `context.read<ChatProvider>()` — these work via the widget tree regardless of file location

### Step 2: Update `chat_tab.dart`

- Remove the `ChatBubble` class and its `_showEditRecordPopup` method from `chat_tab.dart`
- Add import for the new component: `import 'package:wallet_ai/components/chat_bubble.dart';` (or via barrel file if components.dart is already imported)
- The `_StreamingIndicator` class stays in `chat_tab.dart` — it's private and only used here

### Step 3: Update barrel file

- Modify `lib/components/components.dart`
- Add: `export 'chat_bubble.dart';`

## Technical Details

- **Approach:** Per AD-3, move widget to correct architectural layer
- **Files to create:** `lib/components/chat_bubble.dart`
- **Files to modify:** `lib/screens/home/tabs/chat_tab.dart`, `lib/components/components.dart`
- **Patterns to follow:** See existing components like `record_widget.dart` for file structure
- **Edge cases:**
  - `ChatBubble` needs access to `EditRecordPopup` which is in `components/popups/edit_record_popup.dart` — already accessible via the components barrel file
  - Circular import risk: `chat_bubble.dart` imports `components.dart` which will export `chat_bubble.dart`. Avoid this by using direct imports instead of barrel in chat_bubble.dart, or import specific files.

## Tests to Write

### Unit Tests
- No unit tests needed — this is a pure file move with no logic changes

### Integration Tests
- Test: Render ChatBubble with a message → expect text displayed correctly
- Test: Render ChatBubble with records → expect RecordWidget rendered for each record

## Verification Checklist

- [ ] `flutter analyze` passes with zero errors
- [ ] `grep -n "class ChatBubble" lib/screens/` returns empty (not in screens anymore)
- [ ] `grep -n "class ChatBubble" lib/components/chat_bubble.dart` returns the class definition
- [ ] `grep "chat_bubble" lib/components/components.dart` shows the export
- [ ] Manual test: Chat messages display correctly (text, alignment, avatar, records)
- [ ] Manual test: Edit record from chat bubble → popup opens, save works

## Dependencies

- **Blocked by:** T1 (ChatProvider changes affect chat_tab.dart, do T1 first to avoid conflicts)
- **Blocks:** T7 (barrel file update depends on new file existing)
- **External:** None
