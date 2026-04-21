import 'package:sqflite/sqflite.dart';

/// Handles schema migrations for the `Record` table.
///
/// Kept separate from `RecordRepository` so migration logic can evolve
/// without cluttering the main repository file.
class RecordMigrationService {
  /// Adds `occurred_at` and backfills from `last_updated` for existing rows.
  ///
  /// Idempotent: safe to re-run if a previous attempt was interrupted — the
  /// backfill only touches rows where `occurred_at IS NULL`. Expected to be
  /// called from inside `onUpgrade`, which sqflite already wraps in a
  /// transaction — no nested `db.transaction` needed here.
  static Future<void> addOccurredAtColumn(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(Record)');
    final hasColumn = columns.any((c) => c['name'] == 'occurred_at');

    if (!hasColumn) {
      await db.execute('ALTER TABLE Record ADD COLUMN occurred_at INTEGER');
    }
    await db.execute(
      'UPDATE Record SET occurred_at = last_updated WHERE occurred_at IS NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_record_occurred_at ON Record(occurred_at)',
    );
  }
}
