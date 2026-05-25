---
epic: category-icons
task: 211
status: completed
created: 2026-05-25T16:39:40Z
updated: 2026-05-25T16:39:40Z
---
# Handoff: Task #211 — Add emoji column, migration & curated seed map

## What shipped

- `Category.emoji` field (non-null `String`, default `'🏷️'`) added to the model with full `toMap`/`fromMap`/`copyWith` round-trip support. `fromMap` coalesces null/empty/missing to `'🏷️'`.
- `_dbVersion` bumped from 9 to 10 in `RecordRepository`. `CREATE TABLE Category` DDL updated with `emoji TEXT NOT NULL DEFAULT '🏷️'`. `_seedDatabase` now seeds all 9 parents and 8 subs with the AD-5 curated emoji map.
- `RecordMigrationService.addEmojiColumn(db)` added — mirrors the `addOccurredAtColumn` idempotency shape: PRAGMA-guarded ALTER TABLE, then guarded UPDATE per seed id/name (`WHERE emoji = '🏷️'` prevents overwriting user values).
- `_onUpgrade` wired: `if (oldVersion < 10) { await RecordMigrationService.addEmojiColumn(db); }`.
- 3 test files: 15 unit tests in `category_test.dart`, 3 migration tests in `record_migration_service_test.dart`, 3 new v10 tests in `record_repository_test.dart`. Existing `record_repository_test.dart` setUp updated with `singleInstance: false` and emoji column in DDL to support `Category.toMap()` now always serializing emoji.

## Test results

- `fvm flutter test test/models/category_test.dart` — 15/15 pass
- `fvm flutter test test/services/record_migration_service_test.dart` — 3/3 pass
- `fvm flutter test test/repositories/record_repository_test.dart` — 17/17 pass
- Full suite: 21 pre-existing failures (verification_test, providers, components — all involve v8→v9 schema issues unrelated to this task); no new failures introduced; issue count in `fvm flutter analyze` dropped from 117 to 113.

## Deviations

None. Implementation follows the spec exactly.

## What's unblocked

- #214 (Category edit dialog — needs `Category.copyWith(emoji: ...)`) — unblocked immediately
- #215 (emoji render sites — needs `category.emoji` field) — unblocked immediately
- #213 (server contract — needs `Category.emoji` model field) — unblocked; still waits on #212 (server-side work) independently
- #216 (final integration gate) — still waits on all of the above

## Notes for next agent

- The 21 pre-existing test failures are NOT introduced by this task. They existed on the branch before this commit.
- `test/repositories/record_repository_test.dart` setUp now uses `singleInstance: false` — intentional, required because `Category.toMap()` always serializes `emoji` and the v9-schema test DB must have the column.
