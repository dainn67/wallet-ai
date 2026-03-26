import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

/// Integration test: Category CRUD end-to-end through repository
/// Verifies create → read → update → delete flows and data integrity
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
      await db.insert('Category', {'name': 'Food', 'type': 'expense'});
      await db.insert('MoneySource', {'source_name': 'Wallet', 'amount': 1000});
    });
    RecordRepository.setMockDatabase(db);
    repository = RecordRepository();
  });

  tearDown(() async {
    await db.close();
  });

  test('Integration: full CRUD cycle - create, read, update, delete category', () async {
    // CREATE
    final catId = await repository.createCategory(
      Category(name: 'Transport', type: 'expense'),
    );
    expect(catId, 3);

    // READ
    var categories = await repository.getAllCategories();
    expect(categories.length, 3);
    expect(categories.any((c) => c.name == 'Transport'), isTrue);

    // UPDATE
    await repository.updateCategory(
      Category(categoryId: catId, name: 'Travel', type: 'expense'),
    );
    categories = await repository.getAllCategories();
    expect(categories.firstWhere((c) => c.categoryId == catId).name, 'Travel');

    // DELETE
    await repository.deleteCategory(catId);
    categories = await repository.getAllCategories();
    expect(categories.any((c) => c.categoryId == catId), isFalse);
    expect(categories.length, 2); // Back to Uncategorized + Food
  });

  test('Integration: delete category with records moves all to Uncategorized and verifies totals', () async {
    // Create records in Food category (ID 2)
    for (int i = 0; i < 3; i++) {
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 2,
        amount: 100.0,
        currency: 'USD',
        description: 'Meal $i',
        type: 'expense',
      ));
    }

    // Verify totals before delete
    var totals = await repository.getCategoryTotals();
    expect(totals[2], 300.0);

    // Delete Food category
    await repository.deleteCategory(2);

    // All records should now be in Uncategorized
    final records = await repository.getAllRecords();
    expect(records.length, 3);
    for (final r in records) {
      expect(r.categoryId, 1);
    }

    // Totals should now be under Uncategorized
    totals = await repository.getCategoryTotals();
    expect(totals[1], 300.0);
    expect(totals[2], isNull); // Food category no longer has records
  });

  test('Integration: getCategoryTotals aggregates across multiple categories', () async {
    // Create a new category
    final incomeId = await repository.createCategory(
      Category(name: 'Salary', type: 'income'),
    );

    // Add expense records to Food
    await repository.createRecord(Record(
      moneySourceId: 1,
      categoryId: 2,
      amount: 50.0,
      currency: 'USD',
      description: 'Lunch',
      type: 'expense',
    ));
    await repository.createRecord(Record(
      moneySourceId: 1,
      categoryId: 2,
      amount: 75.0,
      currency: 'USD',
      description: 'Dinner',
      type: 'expense',
    ));

    // Add income record to Salary
    await repository.createRecord(Record(
      moneySourceId: 1,
      categoryId: incomeId,
      amount: 3000.0,
      currency: 'USD',
      description: 'Monthly salary',
      type: 'income',
    ));

    final totals = await repository.getCategoryTotals();
    expect(totals[2], 125.0); // Food: 50 + 75
    expect(totals[incomeId], 3000.0); // Salary
    expect(totals[1], isNull); // Uncategorized: no records
  });

  test('Integration: record count by category is accurate through operations', () async {
    // Initially no records in any category
    expect(await repository.getRecordCountByCategoryId(1), 0);
    expect(await repository.getRecordCountByCategoryId(2), 0);

    // Add 3 records to Food
    for (int i = 0; i < 3; i++) {
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 2,
        amount: 10.0,
        currency: 'USD',
        description: 'Item $i',
        type: 'expense',
      ));
    }

    expect(await repository.getRecordCountByCategoryId(2), 3);

    // Delete Food category → records move to Uncategorized
    await repository.deleteCategory(2);
    expect(await repository.getRecordCountByCategoryId(1), 3);
  });
}
