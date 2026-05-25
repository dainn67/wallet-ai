import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/services/record_migration_service.dart';

/// Helpers ----------------------------------------------------------------

/// Build a v9-shaped Category table and seed it with 9 parents + 8 subs.
/// No emoji column — simulates a pre-v10 database.
Future<void> _createV9Schema(Database db) async {
  await db.execute('''
    CREATE TABLE Category (
      category_id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      parent_id INTEGER NOT NULL DEFAULT -1
    )
  ''');

  // Parents (category_id 1–9)
  await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense', 'parent_id': -1}); // 1
  await db.insert('Category', {'name': 'Food',          'type': 'expense', 'parent_id': -1}); // 2
  await db.insert('Category', {'name': 'Transport',     'type': 'expense', 'parent_id': -1}); // 3
  await db.insert('Category', {'name': 'Entertainment', 'type': 'expense', 'parent_id': -1}); // 4
  await db.insert('Category', {'name': 'Salary',        'type': 'income',  'parent_id': -1}); // 5
  await db.insert('Category', {'name': 'Rent',          'type': 'expense', 'parent_id': -1}); // 6
  await db.insert('Category', {'name': 'Health',        'type': 'expense', 'parent_id': -1}); // 7
  await db.insert('Category', {'name': 'Shopping',      'type': 'expense', 'parent_id': -1}); // 8
  await db.insert('Category', {'name': 'Transfer',      'type': 'transfer','parent_id': -1}); // 9

  // Subs
  await db.insert('Category', {'name': 'Groceries',   'type': 'expense', 'parent_id': 2});
  await db.insert('Category', {'name': 'Dining Out',  'type': 'expense', 'parent_id': 2});
  await db.insert('Category', {'name': 'Taxi',        'type': 'expense', 'parent_id': 3});
  await db.insert('Category', {'name': 'Fuel',        'type': 'expense', 'parent_id': 3});
  await db.insert('Category', {'name': 'Cinema',      'type': 'expense', 'parent_id': 4});
  await db.insert('Category', {'name': 'Streaming',   'type': 'expense', 'parent_id': 4});
  await db.insert('Category', {'name': 'Clothes',     'type': 'expense', 'parent_id': 8});
  await db.insert('Category', {'name': 'Electronics', 'type': 'expense', 'parent_id': 8});
}

String? _emojiFor(List<Map<String, Object?>> rows, {int? id, String? name}) {
  final row = id != null
      ? rows.firstWhere((r) => r['category_id'] == id, orElse: () => {})
      : rows.firstWhere((r) => r['name'] == name, orElse: () => {});
  return row['emoji'] as String?;
}

/// Tests ------------------------------------------------------------------

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('RecordMigrationService.addEmojiColumn', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath, version: 1);
      await _createV9Schema(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('v9 → v10: column is added and all seed rows carry AD-5 emoji', () async {
      await RecordMigrationService.addEmojiColumn(db);

      // Verify column exists
      final columns = await db.rawQuery('PRAGMA table_info(Category)');
      expect(columns.any((c) => c['name'] == 'emoji'), isTrue);

      final rows = await db.query('Category');

      // Parents — matched by category_id
      expect(_emojiFor(rows, id: 1), '🏷️'); // Uncategorized
      expect(_emojiFor(rows, id: 2), '🍔'); // Food
      expect(_emojiFor(rows, id: 3), '🚗'); // Transport
      expect(_emojiFor(rows, id: 4), '🎬'); // Entertainment
      expect(_emojiFor(rows, id: 5), '💰'); // Salary
      expect(_emojiFor(rows, id: 6), '🏠'); // Rent
      expect(_emojiFor(rows, id: 7), '🏥'); // Health
      expect(_emojiFor(rows, id: 8), '🛍️'); // Shopping
      expect(_emojiFor(rows, id: 9), '🔄'); // Transfer

      // Subs — matched by name
      expect(_emojiFor(rows, name: 'Groceries'),   '🛒');
      expect(_emojiFor(rows, name: 'Dining Out'),  '🍽️');
      expect(_emojiFor(rows, name: 'Taxi'),        '🚕');
      expect(_emojiFor(rows, name: 'Fuel'),        '⛽');
      expect(_emojiFor(rows, name: 'Cinema'),      '🎥');
      expect(_emojiFor(rows, name: 'Streaming'),   '📺');
      expect(_emojiFor(rows, name: 'Clothes'),     '👕');
      expect(_emojiFor(rows, name: 'Electronics'), '📱');
    });

    test('idempotent: running migration twice leaves values unchanged and does not error', () async {
      await RecordMigrationService.addEmojiColumn(db);

      // Read values after first run
      final rowsAfterFirst = await db.query('Category');
      final foodEmojiAfterFirst = _emojiFor(rowsAfterFirst, id: 2);

      // Second run — must not throw
      await RecordMigrationService.addEmojiColumn(db);

      final rowsAfterSecond = await db.query('Category');
      expect(_emojiFor(rowsAfterSecond, id: 2), foodEmojiAfterFirst);

      // Every row still has its expected emoji
      expect(_emojiFor(rowsAfterSecond, id: 1), '🏷️');
      expect(_emojiFor(rowsAfterSecond, id: 9), '🔄');
    });

    test('user value preserved: WHERE emoji = 🏷️ guard prevents overwriting non-default emoji', () async {
      // Manually add the column and set a custom emoji on category_id = 2 (Food).
      await db.execute("ALTER TABLE Category ADD COLUMN emoji TEXT NOT NULL DEFAULT '🏷️'");
      await db.rawUpdate(
        "UPDATE Category SET emoji = '🚌' WHERE category_id = 2",
      );

      await RecordMigrationService.addEmojiColumn(db);

      final rows = await db.query('Category');
      // category_id = 2 must NOT be touched by the migration.
      expect(_emojiFor(rows, id: 2), '🚌');

      // Other rows should still be backfilled correctly.
      expect(_emojiFor(rows, id: 1), '🏷️');
      expect(_emojiFor(rows, id: 3), '🚗');
    });
  });
}
