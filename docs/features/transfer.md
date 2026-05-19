# Transfer Between Sources

## Technical Overview

Moves money from one `MoneySource` to another, atomically. Persisted as a single `Record` row with `type = 'transfer'`, `money_source_id` set to the origin, and a new nullable column `target_source_id` set to the destination. The repository debits the origin and credits the destination in one DB transaction; net wallet balance is unchanged.

Transfers are not editable in v1 — opening one in `EditRecordPopup` shows a read-only summary with a Delete action. To change a transfer, delete it and create a new one.

## Schema (v8 → v9)

```sql
ALTER TABLE Record ADD COLUMN target_source_id INTEGER;
CHECK(type IN ('income', 'expense', 'transfer'))  -- relaxed
```

Because SQLite can't `ALTER` a `CHECK` constraint in place, `RecordMigrationService.addTargetSourceIdColumn` rebuilds the `Record` table (copy → drop → rename), preserving every existing row with `target_source_id = NULL`. All indexes are recreated. A new `idx_record_target_source_id` index is added. A seed `Category` row `(name: 'Transfer', type: 'transfer', parent_id: -1)` is also inserted.

## Technical Mapping

### UI Layer
- **EditSourcePopup** (`lib/components/popups/edit_source_popup.dart`): Adds a leading `Icons.swap_horiz` `IconButton`. Tapping captures the navigator, closes this popup, and opens `TransferPopup` with the current source pre-filled as the origin.
- **TransferPopup** (`lib/components/popups/transfer_popup.dart`): Read-only "From" field, "To" dropdown excluding the origin, amount field, note field. Validates that destination is selected and amount > 0. On confirm, calls `RecordProvider.createTransfer(...)` and pops.
- **RecordWidget** (`lib/components/record_widget.dart`): Detects `record.isTransfer` and renders an indigo `Icons.swap_horiz` glyph, no `+`/`-` sign on the amount, and a subtitle of `"From → To"` instead of category + source.
- **EditRecordPopup** (`lib/components/popups/edit_record_popup.dart`): Branches at the top of `build` — when `widget.record.isTransfer`, renders `_buildTransferView`, a read-only summary with a Delete button only.

### Provider Layer
- **RecordProvider.createTransfer** (`lib/providers/record_provider.dart`): Looks up the seeded Transfer category, builds a `Record` with `type: 'transfer'` + `targetSourceId`, and calls the existing `_performOperation(_repository.createRecord)`. Reuses the standard load/refresh pipeline.
- **Aggregates** (`filteredTotalIncome`, `filteredTotalExpense`, home-widget monthly totals): Already filter on `r.type == 'income'` / `'expense'`, so transfers are excluded for free.

### Repository Layer
- **`_applyRecordImpact(record, {reverse})`** (`lib/repositories/record_repository.dart`): Centralized balance math for all three types. For transfers, debits `money_source_id` and credits `target_source_id` in one transaction (reverse flips both deltas).
- **createRecord / updateRecord / deleteRecord**: All call `_applyRecordImpact` instead of branching on `type` inline. updateRecord reverses the old impact and applies the new one; deleteRecord reverses the impact before removing the row.
- **SELECT queries**: All three (getAllRecords, getRecordById, the inner SELECT in updateRecord/deleteRecord) now LEFT JOIN `MoneySource` a second time on `r.target_source_id = tms.source_id` and project `tms.source_name as target_source_name`.

### Model Layer
- **Record** (`lib/models/record.dart`): Adds `int? targetSourceId`, `String? targetSourceName` (denormalized for display). Relaxes the type assertion to allow `'transfer'`. Adds `bool get isTransfer` and `copyWith(..., clearTargetSource: bool)`.

### Detection from Chat

Transfers can also be created conversationally. When the server emits a record item with `type: "transfer"` in the post-`--//--` JSON list, `ChatProvider._buildRecordFromJson` (`lib/providers/chat_provider.dart`) takes a separate branch:

- Reads `source_id`, `target_source_id`, `amount`, `description`, `occurred_at` (same tolerant int-or-string coercion used for other types).
- **Ignores** any AI-supplied `category_id` / `category` / `suggested_category`. The category is always resolved client-side via `RecordProvider.transferCategory` (the seeded `'Transfer'` row).
- **Skips** the item (returns `null`, no DB write, no exception) when `target_source_id` is missing/unparseable, or equals `source_id`. A `debugPrint` records the dropped payload.
- Builds a `Record` with `type: 'transfer'` and persists via the same `RecordProvider.createRecord` path used for income/expense — `_applyRecordImpact` handles the debit/credit atomically.

The resulting chat-bubble card uses `RecordWidget`'s existing transfer rendering (indigo `swap_horiz` glyph, "From → To" subtitle, no `+`/`-` sign). Tapping it opens the same read-only delete-only `EditRecordPopup` view as non-chat transfers.

Expected server payload shape (one item):
```json
{
  "type": "transfer",
  "source_id": 2,
  "target_source_id": 5,
  "amount": "100000",
  "description": "moved to savings",
  "occurred_at": "2026-05-17T10:00:00"
}
```

## User Flow

```
User taps a source on Records tab
    ↓
EditSourcePopup opens with three buttons in the header:
  [Transfer]   Edit <SourceName>   [Delete]
    ↓
User taps Transfer
    ↓
EditSourcePopup closes; TransferPopup opens
  From: <SourceName>  (locked)
  To:   <dropdown of other sources>
  Amount: <input>
  Note:   <input>
    ↓
User taps Transfer → RecordProvider.createTransfer(...)
    ↓
Repo INSERT (type='transfer', money_source_id, target_source_id) + balance debit/credit
    ↓
loadAll() → list refreshes; income/expense totals unchanged
```

## Edit & Delete

- **Edit**: Not supported in v1. Opening a transfer in `EditRecordPopup` displays a read-only summary; the only mutation is Delete.
- **Delete**: Standard `RecordProvider.deleteRecord(id)` → `_applyRecordImpact(..., reverse: true)` reverses both halves before removing the row.

## Aggregation Behavior

- Transfers are **excluded** from `filteredTotalIncome`, `filteredTotalExpense`, and the home-widget monthly income/spend.
- Transfers are **included** in the records list and in category drill-downs (under the seeded "Transfer" category).
- Total wallet balance is unchanged by any transfer — the two halves cancel.

## Key Files

- `lib/models/record.dart` — `targetSourceId`, `targetSourceName`, `isTransfer`, relaxed type assertion
- `lib/repositories/record_repository.dart` — `_applyRecordImpact` helper, transfer-aware CRUD, JOIN target source
- `lib/services/record_migration_service.dart` — `addTargetSourceIdColumn` (table rebuild)
- `lib/providers/record_provider.dart` — `createTransfer` wrapper
- `lib/components/popups/edit_source_popup.dart` — Transfer button entry point
- `lib/components/popups/transfer_popup.dart` — Transfer dialog (new)
- `lib/components/popups/edit_record_popup.dart` — Read-only delete-only view for transfers
- `lib/components/record_widget.dart` — Transfer row rendering
- `lib/configs/l10n_config.dart` — `transfer_*` keys (EN/VI)
