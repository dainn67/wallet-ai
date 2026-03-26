import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

/// Smoke test: Full create category flow via repository
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
      await db.insert('MoneySource', {'source_name': 'Wallet', 'amount': 1000});
    });
    RecordRepository.setMockDatabase(db);
    repository = RecordRepository();
  });

  tearDown(() async {
    await db.close();
  });

  test('Smoke: create category and verify it appears in list', () async {
    // Create a new category
    final id = await repository.createCategory(
      Category(name: 'Shopping', type: 'expense'),
    );
    expect(id, greaterThan(1));

    // Verify it appears in getAllCategories
    final categories = await repository.getAllCategories();
    expect(categories.length, 2); // Uncategorized + Shopping
    expect(categories.any((c) => c.name == 'Shopping'), isTrue);
  });

  test('Smoke: create category and assign records to it', () async {
    final catId = await repository.createCategory(
      Category(name: 'Travel', type: 'expense'),
    );

    // Create a record in the new category
    await repository.createRecord(Record(
      moneySourceId: 1,
      categoryId: catId,
      amount: 250.0,
      currency: 'USD',
      description: 'Flight ticket',
      type: 'expense',
    ));

    // Verify category totals
    final totals = await repository.getCategoryTotals();
    expect(totals[catId], 250.0);

    // Verify record count
    final count = await repository.getRecordCountByCategoryId(catId);
    expect(count, 1);
  });
}
