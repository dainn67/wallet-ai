import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

/// Smoke test: Delete category and verify records move to Uncategorized
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late RecordRepository repository;

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE Category (
          category_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE MoneySource (
          source_id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_name TEXT NOT NULL,
          amount REAL NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE Record (
          record_id INTEGER PRIMARY KEY AUTOINCREMENT,
          money_source_id INTEGER NOT NULL,
          category_id INTEGER NOT NULL DEFAULT 1,
          amount REAL NOT NULL,
          currency TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
          last_updated INTEGER NOT NULL,
          FOREIGN KEY (money_source_id) REFERENCES MoneySource (source_id),
          FOREIGN KEY (category_id) REFERENCES Category (category_id)
        )
      ''');
      await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense'});
      await db.insert('Category', {'name': 'Coffee', 'type': 'expense'});
      await db.insert('MoneySource', {'source_name': 'Wallet', 'amount': 5000});
    });
    RecordRepository.setMockDatabase(db);
    repository = RecordRepository();
  });

  tearDown(() async {
    await db.close();
  });

  test('Smoke: delete category moves all records to Uncategorized', () async {
    // Create 5 records in Coffee category (ID 2)
    for (int i = 0; i < 5; i++) {
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 2,
        amount: 50.0 + i,
        currency: 'USD',
        description: 'Coffee $i',
        type: 'expense',
      ));
    }

    // Verify records are in category 2
    var count = await repository.getRecordCountByCategoryId(2);
    expect(count, 5);

    // Delete category 2
    await repository.deleteCategory(2);

    // Category should be gone
    final categories = await repository.getAllCategories();
    expect(categories.any((c) => c.categoryId == 2), isFalse);

    // All 5 records should now be in Uncategorized (ID 1)
    final records = await repository.getAllRecords();
    expect(records.length, 5);
    for (final r in records) {
      expect(r.categoryId, 1, reason: 'Record ${r.recordId} should be in Uncategorized');
    }
  });
}
