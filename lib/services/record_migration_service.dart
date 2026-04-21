import 'package:sqflite/sqflite.dart';

/// Handles schema migrations for the `Record` table.
///
/// Kept separate from `RecordRepository` so migration logic can evolve
/// without cluttering the main repository file.
class RecordMigrationService {
  /// Adds `occurred_at` as NOT NULL, backfilled from `last_updated`.
  ///
  /// SQLite's `ALTER TABLE ADD COLUMN` can't express `NOT NULL` without a
  /// constant default, so we add it nullable, backfill, then rebuild the
  /// table with the `NOT NULL` constraint so migrated DBs match the v8
  /// fresh-install schema exactly.
  ///
  /// Idempotent across all partial-failure states:
  ///   - column missing            → add, backfill, rebuild
  ///   - column exists, nullable   → backfill (safety), rebuild
  ///   - column exists, NOT NULL   → no-op
  ///
  /// Expected to run inside `onUpgrade`, which sqflite already wraps in a
  /// transaction — no nested `db.transaction` needed here.
  static Future<void> addOccurredAtColumn(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(Record)');
    final occurredAt = columns.firstWhere(
      (c) => c['name'] == 'occurred_at',
      orElse: () => const {},
    );
    final hasColumn = occurredAt.isNotEmpty;
    final isNotNull = hasColumn && (occurredAt['notnull'] as int? ?? 0) == 1;

    if (isNotNull) return;

    if (!hasColumn) {
      await db.execute('ALTER TABLE Record ADD COLUMN occurred_at INTEGER');
    }
    await db.execute(
      'UPDATE Record SET occurred_at = last_updated WHERE occurred_at IS NULL',
    );
    await _rebuildRecordTableWithNotNull(db);
  }

  /// Recreates `Record` with `occurred_at INTEGER NOT NULL`, preserving every
  /// row (via `INSERT ... SELECT`), then reinstates all indexes.
  static Future<void> _rebuildRecordTableWithNotNull(DatabaseExecutor db) async {
    await db.execute('DROP INDEX IF EXISTS idx_record_money_source_id');
    await db.execute('DROP INDEX IF EXISTS idx_record_category_id');
    await db.execute('DROP INDEX IF EXISTS idx_record_type');
    await db.execute('DROP INDEX IF EXISTS idx_record_last_updated');
    await db.execute('DROP INDEX IF EXISTS idx_record_occurred_at');

    await db.execute('''
      CREATE TABLE Record_new (
        record_id INTEGER PRIMARY KEY AUTOINCREMENT,
        money_source_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL DEFAULT 1,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        description TEXT,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        last_updated INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        FOREIGN KEY (money_source_id) REFERENCES MoneySource (source_id),
        FOREIGN KEY (category_id) REFERENCES Category (category_id)
      )
    ''');

    await db.execute('''
      INSERT INTO Record_new (
        record_id, money_source_id, category_id, amount, currency,
        description, type, last_updated, occurred_at
      )
      SELECT record_id, money_source_id, category_id, amount, currency,
             description, type, last_updated, occurred_at
      FROM Record
    ''');

    await db.execute('DROP TABLE Record');
    await db.execute('ALTER TABLE Record_new RENAME TO Record');

    await db.execute('CREATE INDEX idx_record_money_source_id ON Record(money_source_id)');
    await db.execute('CREATE INDEX idx_record_category_id ON Record(category_id)');
    await db.execute('CREATE INDEX idx_record_type ON Record(type)');
    await db.execute('CREATE INDEX idx_record_last_updated ON Record(last_updated)');
    await db.execute('CREATE INDEX idx_record_occurred_at ON Record(occurred_at)');
  }
}
