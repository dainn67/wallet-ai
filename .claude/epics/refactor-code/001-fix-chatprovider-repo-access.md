---
name: Fix ChatProvider direct repository access
status: open
created: 2026-03-28T17:50:49Z
updated: 2026-03-28T17:50:49Z
complexity: moderate
recommended_model: sonnet
phase: 1
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/137"
depends_on: []
parallel: false
conflicts_with: []
files:
  - lib/providers/chat_provider.dart
  - lib/providers/record_provider.dart
prd_requirements:
  - FR-1
  - FR-6
---

# Fix ChatProvider direct repository access

## Context

ChatProvider directly instantiates `RecordRepository` in its `onDone` handler (line 133) to save records parsed from chat responses. This violates FR-1 (provider-only repository access) and is the most critical layer violation in the codebase. Per AD-1, all record creation must route through RecordProvider.

## Description

Remove direct `RecordRepository` usage from ChatProvider. Add a lightweight `createRecord(Record)` method to RecordProvider that returns the inserted ID (needed by ChatProvider to attach IDs to message records). Update ChatProvider's `onDone` handler to use `_recordProvider!.createRecord(record)` instead of `recordRepository.createRecord(record)`.

## Acceptance Criteria

- [ ] **FR-1 / Happy path:** `grep -r "import.*repositories" lib/providers/chat_provider.dart` returns 0 results — ChatProvider no longer imports any repository
- [ ] **FR-1 / Happy path:** ChatProvider does not instantiate `RecordRepository` anywhere
- [ ] **FR-6 / Behavior preservation:** Sending a chat message that generates records still creates all records in the database with correct IDs
- [ ] **FR-6 / Behavior preservation:** Records created via chat appear in the Records tab after creation
- [ ] **FR-6 / Behavior preservation:** Chat message bubbles display the created records with correct data (amount, category, source)
- [ ] **FR-6 / Edge case:** Multiple records in a single chat response are all created and attached to the message

## Implementation Steps

### Step 1: Add `createRecord` method to RecordProvider

- Modify `lib/providers/record_provider.dart`
- Add a new method `Future<int> createRecord(Record record) async` that:
  - Calls `_repository.createRecord(record)` and returns the inserted ID
  - Does NOT call `loadAll()` or `notifyListeners()` — this is a lightweight operation for batch use
  - The caller (ChatProvider) will call `loadAll()` after the batch is complete (it already does this on line 170)
- This differs from `addRecord()` which sets loading state, calls loadAll, and updates the widget — that's too heavy for a batch loop

### Step 2: Update ChatProvider to use RecordProvider

- Modify `lib/providers/chat_provider.dart`
- Remove import: `import 'package:wallet_ai/repositories/record_repository.dart';` (line 6)
- In the `onDone` handler (~line 127-175):
  - Remove: `final recordRepository = RecordRepository();` (line 133)
  - Replace: `final recordId = await recordRepository.createRecord(record);` with `final recordId = await _recordProvider!.createRecord(record);`
  - Keep everything else unchanged — the loop, JSON parsing, record construction, and message update logic all stay the same
- Verify `_recordProvider` is non-null at this point (it's set via the proxy provider in main.dart, so it should always be available)

## Interface Contract

### Produces for T2:
- File: `lib/providers/record_provider.dart`
  - Method: `Future<int> createRecord(Record record)` — returns inserted record ID
  - Lightweight variant of `addRecord()` — no loading state, no notifyListeners, no widget update
  - T2 will include this method in its boilerplate consolidation

## Technical Details

- **Approach:** Per AD-1, RecordProvider is the single data gateway
- **Files to modify:**
  - `lib/providers/record_provider.dart` — add `createRecord()` method
  - `lib/providers/chat_provider.dart` — remove repo import, replace direct repo call
- **Patterns to follow:** See existing `addRecord()` in record_provider.dart for the repository call pattern
- **Edge cases:**
  - ChatProvider's `_recordProvider` could theoretically be null if proxy provider hasn't updated yet. The existing code already assumes it's non-null (line 170: `await _recordProvider?.loadAll()`). Use `_recordProvider!` with a null assertion since the record creation requires it to be present.
  - Error handling: if `createRecord` throws, the existing try-catch in ChatProvider's `onDone` handler (line 172) already catches and logs the error. No change needed.

## Tests to Write

### Unit Tests
- `test/providers/record_provider_test.dart`
  - Test: `createRecord()` calls repository and returns ID → expect non-zero int returned
  - Test: `createRecord()` does NOT trigger notifyListeners → expect no listeners notified

### Integration Tests
- Test: Send chat message → records created via RecordProvider path → records appear in provider's records list after `loadAll()`

## Verification Checklist

- [ ] `flutter analyze` passes with zero errors
- [ ] `grep -r "import.*repositories" lib/providers/chat_provider.dart` returns empty
- [ ] `grep -r "RecordRepository" lib/providers/chat_provider.dart` returns empty
- [ ] Manual test: Send a chat message that creates records → records appear in Records tab
- [ ] Manual test: Record amounts, categories, and sources match what the AI returned

## Dependencies

- **Blocked by:** None
- **Blocks:** T2 (needs the new `createRecord` method to include in consolidation)
- **External:** None
