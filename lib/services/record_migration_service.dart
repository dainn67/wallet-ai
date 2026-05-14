import 'package:sqflite/sqflite.dart';

/// Handles schema migrations for the `Record` table.
///
/// Kept separate from `RecordRepository` so migration logic can evolve
/// without cluttering the main repository file.
class RecordMigrationService {
  /// Adds `occurred_at INTEGER NOT NULL`, backfilled from `last_updated`.
  ///
  /// SQLite's `ALTER TABLE ADD COLUMN` only accepts constant defaults, so the
  /// column is added with a transient `DEFAULT 0` and the next statement
  /// overwrites every row with its `last_updated` value. Both statements run
  /// inside sqflite's `onUpgrade` transaction — a crash between them rolls
  /// back to v7 and the next launch retries from scratch, so no row ever
  /// persists with `0` or `NULL` as its event time.
  ///
  /// Idempotent: the column-existence check skips the ALTER/UPDATE on
  /// already-migrated DBs; the index uses `IF NOT EXISTS`.
  static Future<void> addOccurredAtColumn(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(Record)');
    final hasColumn = columns.any((c) => c['name'] == 'occurred_at');

    if (!hasColumn) {
      await db.execute(
        'ALTER TABLE Record ADD COLUMN occurred_at INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('UPDATE Record SET occurred_at = last_updated');
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_record_occurred_at ON Record(occurred_at)',
    );
  }

  /// v8 → v9: enables transfer rows.
  ///
  /// Two things change:
  /// 1. Add `target_source_id INTEGER NULL`.
  /// 2. Relax the `CHECK(type IN ('income','expense'))` constraint to allow
  ///    `'transfer'`.
  ///
  /// SQLite cannot `ALTER` a CHECK constraint in place, so the table is
  /// rebuilt: copy → drop → rename. Existing rows keep `target_source_id = NULL`.
  /// Idempotent: skipped entirely if `target_source_id` already exists.
  static Future<void> addTargetSourceIdColumn(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(Record)');
    final hasColumn = columns.any((c) => c['name'] == 'target_source_id');

    if (!hasColumn) {
      await db.execute('''
        CREATE TABLE Record_new (
          record_id INTEGER PRIMARY KEY AUTOINCREMENT,
          money_source_id INTEGER NOT NULL,
          target_source_id INTEGER,
          category_id INTEGER NOT NULL DEFAULT 1,
          amount REAL NOT NULL,
          currency TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL CHECK(type IN ('income', 'expense', 'transfer')),
          last_updated INTEGER NOT NULL,
          occurred_at INTEGER NOT NULL,
          FOREIGN KEY (money_source_id) REFERENCES MoneySource (source_id),
          FOREIGN KEY (target_source_id) REFERENCES MoneySource (source_id),
          FOREIGN KEY (category_id) REFERENCES Category (category_id)
        )
      ''');
      await db.execute('''
        INSERT INTO Record_new (
          record_id, money_source_id, target_source_id, category_id,
          amount, currency, description, type, last_updated, occurred_at
        )
        SELECT
          record_id, money_source_id, NULL, category_id,
          amount, currency, description, type, last_updated, occurred_at
        FROM Record
      ''');
      await db.execute('DROP TABLE Record');
      await db.execute('ALTER TABLE Record_new RENAME TO Record');

      // Recreate indexes — old ones are dropped with the old table.
      await db.execute('CREATE INDEX IF NOT EXISTS idx_record_money_source_id ON Record(money_source_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_record_category_id ON Record(category_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_record_type ON Record(type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_record_last_updated ON Record(last_updated)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_record_occurred_at ON Record(occurred_at)');
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_record_target_source_id ON Record(target_source_id)',
    );
  }
}
