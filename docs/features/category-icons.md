# Category Icons (Emoji) Feature Documentation

## Technical Overview

Every `Category` row carries a single `emoji` field — a non-null `String` containing exactly one emoji grapheme. This replaces the prior icon-font / asset approach: the platform's built-in color-emoji font (Apple Color Emoji on iOS, Noto Color Emoji on Android) renders each glyph natively, requiring zero additional assets.

The emoji is set by one of three sources:
- **AI suggestion**: The server returns a validated emoji in the `suggested_category` response (AD-1 contract).
- **User input**: The category edit form (`CategoryFormDialog`) exposes a plain `TextField` so the user can type or paste an emoji from the OS keyboard.
- **Seed map**: 17 curated per-category emojis are hard-coded in `RecordRepository._seedDatabase` and applied during the v9 → v10 migration.

The fallback value is `'🏷️'`, applied both in the `Category` constructor default and as a defensive coalesce in `Category.fromMap` when the DB value is null or empty.

## Where the Emoji Renders

### 1. Categories Tab (`CategoryWidget`)
`lib/components/category_widget.dart` — the leading element in the category row is now `Text(category.emoji, style: TextStyle(fontSize: 20))`, placed before the income/expense direction icon. The directional arrow remains because it conveys transaction direction (in/out), not category identity — the two signals are complementary.

### 2. Record Card Subtitle (`RecordWidget`)
`lib/components/record_widget.dart` — `_buildSubtitle` prefixes the category name with `'${emoji} '`, producing strings like `🍔 Food & Drink • Cash`. The emoji is resolved from `RecordProvider.categories` by `categoryId`; if the category is not found in cache (e.g., during initial load), the fallback `'🏷️'` is used.

### 3. Suggestion Banner (`SuggestionBanner`)
`lib/components/suggestion_banner.dart` — **no client-side change**. The server includes the suggested emoji inline in `suggestion.message` (e.g., `"Should I create a new one called 🚌 'Commute'?"`). The banner renders `widget.suggestion.message` verbatim, so the emoji appears automatically. See epic AD-1 / task 212 for the server-side contract.

## Fallback Semantics

`'🏷️'` (label emoji) is the default for:
- User-created categories where the user has not yet set an emoji.
- Rows migrated from schema v9 that did not match any seed entry.
- Any DB row where `emoji` is null or an empty string (`Category.fromMap` coalesces these).

The fallback renders natively on both iOS and Android — no tofu / missing-glyph risk.

## Data Layer

- **Model**: `lib/models/category.dart` — `final String emoji` (default `'🏷️'`).
- **Persistence**: SQLite `categories` table, `emoji TEXT NOT NULL DEFAULT '🏷️'`.
- **Migration**: `RecordMigrationService.addEmojiColumn` (v9 → v10) — `ALTER TABLE ADD COLUMN` followed by seeded `UPDATE` statements for the 17 curated categories.
- **Seed map**: `RecordRepository._seedDatabase` hard-codes emojis for 17 common categories (see `epic.md` AD-5 table for the full list).

## Key Files

- `lib/models/category.dart` — data class with `emoji` field
- `lib/services/record_migration_service.dart` — `addEmojiColumn` (v9 → v10)
- `lib/repositories/record_repository.dart` — seed map + `_seedDatabase`
- `lib/components/category_widget.dart` — leading emoji in CategoriesTab rows
- `lib/components/record_widget.dart` — emoji prefix in record card subtitle
- `lib/components/suggestion_banner.dart` — server-supplied emoji in banner message
- `test/components/category_widget_test.dart` — widget tests for emoji rendering
- `test/components/record_widget_test.dart` — widget tests for subtitle emoji prefix

## Cross-References

- PRD: `.claude/prds/category-icons.md`
- Epic: `.claude/epics/category-icons/epic.md`
