# Suggest Category Feature Documentation

## Technical Overview
When a user logs an expense the AI cannot match to an existing category, the server returns a `suggested_category` object alongside `category_id: "-1"` in the record JSON. The Flutter client parses this into a transient `SuggestedCategory` field on the `Record` model and displays an inline `SuggestionBanner` below the unclassified record card in the chat. Users can confirm (creates or reuses the category, re-assigns the record) or cancel (keeps record Uncategorized).

## Technical Mapping

### UI Layer
- **ChatBubble** (`lib/components/chat_bubble.dart`): Renders each record via a `Column`. For records where `record.suggestedCategory != null`, a `SuggestionBanner` is inserted below the `RecordWidget` using `.expand`-style layout.
- **SuggestionBanner** (`lib/components/suggestion_banner.dart`): StatefulWidget. Displays the AI message, category name chip, type badge (expense/income), and Confirm/Cancel buttons. Manages `_isProcessing` bool to guard against double-tap. Does NOT access providers directly — all side-effects are delegated via `onConfirm` and `onCancel` callbacks.

### Provider Layer
- **ChatProvider** (`lib/providers/chat_provider.dart`): In `_handleStream()`, when a record has `category_id == -1`, calls `SuggestedCategory.fromJson(item['suggested_category'])` and stores the result as a transient field on the `Record`. Also exposes `updateMessageRecord(messageId, Record)` to let the banner update in-memory state after confirm/cancel.
- **RecordProvider** (`lib/providers/record_provider.dart`): Exposes `resolveCategoryByNameOrCreate(name, type, parentId) -> Future<int?>`, which checks `categories` cache for an existing match (case-insensitive), creates a new `Category` via repository if absent, refreshes the cache, and returns the resolved `categoryId`. Returns null on error without rethrowing.

### Model Layer
- **SuggestedCategory** (`lib/models/suggested_category.dart`): Read-only data class with `name`, `type`, `parentId`, `message`. Static `fromJson(dynamic json) -> SuggestedCategory?` is fully defensive — returns null on any missing or invalid field without throwing.
- **Record** (`lib/models/record.dart`): Transient nullable `suggestedCategory` field added after `toMap()`/`fromMap()` (never persisted to SQLite). `copyWith` passes it through by default; use `copyWith(clearSuggestedCategory: true)` to reset it to null.

## Server Response Format

Record items in the `--//--` JSON array may include `suggested_category` only when `category_id` is `"-1"`:

```json
{
  "source_id": 1,
  "category_id": "-1",
  "amount": 50000,
  "description": "Netflix subscription",
  "type": "expense",
  "suggested_category": {
    "name": "Streaming",
    "type": "expense",
    "parent_id": -1,
    "message": "I couldn't find a category for this. Want to create Streaming?"
  }
}
```

## User Flow

```
User sends "50k Netflix subscription"
    ↓
Stream completes → ChatProvider._handleStream parses suggested_category
    ↓
Record saved to DB with categoryId: -1 (no suggestion persisted)
    ↓
ChatBubble renders RecordWidget + SuggestionBanner beneath it
    ↓
Option A — Confirm:
  RecordProvider.resolveCategoryByNameOrCreate → category created or reused
  recordProvider.updateRecord(record.copyWith(categoryId: newId))
  chatProvider.updateMessageRecord(messageId, updatedRecord)
  → Banner disappears, record shows correct category
    ↓
Option B — Cancel:
  chatProvider.updateMessageRecord(messageId, record.copyWith(clearSuggestedCategory: true))
  → Banner disappears, record stays Uncategorized (categoryId: -1)
```

## Key Technical Notes

- **Transient only**: `SuggestedCategory` is never stored in SQLite. App restart clears all suggestion banners; records with `categoryId: -1` remain accessible via the Records tab.
- **Duplicate guard**: `resolveCategoryByNameOrCreate` checks existing categories by name (case-insensitive) before creating. If two records in one message suggest the same category, the second confirm reuses the first's created category.
- **Malformed payload**: `SuggestedCategory.fromJson` returns null for any invalid input (null, string, missing name, invalid type). No crash path.
- **Double-tap guard**: `SuggestionBanner._isProcessing` is set to true on first Confirm tap and only reset on error. Prevents duplicate category creates.
- **Parent validation**: `resolveCategoryByNameOrCreate` validates `parentId` against the category cache; falls back to `-1` (top-level) if not found.

## Key Files

- `lib/models/suggested_category.dart` — Data class + defensive fromJson
- `lib/models/record.dart` — Transient `suggestedCategory` field (excluded from toMap/fromMap)
- `lib/providers/chat_provider.dart` — Parses suggestion in `_handleStream` (~line 210)
- `lib/providers/record_provider.dart` — `resolveCategoryByNameOrCreate` helper
- `lib/components/suggestion_banner.dart` — Inline banner widget
- `lib/components/chat_bubble.dart` — Integration point (~line 78)
- `test/components/suggestion_banner_test.dart` — Widget tests (9 tests)
- `test/models/suggested_category_test.dart` — Model/parse tests (10 tests)
- `test/providers/chat_provider_test.dart` — Stream parsing tests (5 new tests in suggested_category group)
- `test/providers/record_provider_test.dart` — resolveCategoryByNameOrCreate tests (7 tests)
