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
}
