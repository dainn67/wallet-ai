import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

/// Integration test: RecordRepository <-> RecordProvider CRUD propagation
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late RecordRepository repository;
  late RecordProvider provider;

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
    provider = RecordProvider(repository: repository);
  });

  tearDown(() async {
    await db.close();
  });

  test('Integration: loadAll populates categories from repository', () async {
    await provider.loadAll();

    expect(provider.categories.length, 2);
    expect(provider.categories.any((c) => c.name == 'Uncategorized'), isTrue);
    expect(provider.categories.any((c) => c.name == 'Food'), isTrue);
  });

  test('Integration: createCategory updates provider state', () async {
    await provider.loadAll();
    expect(provider.categories.length, 2);

    await provider.createCategory(Category(name: 'Transport', type: 'expense'));
    // Provider should reload after create
    expect(provider.categories.length, 3);
    expect(provider.categories.any((c) => c.name == 'Transport'), isTrue);
  });

  test('Integration: deleteCategory updates provider state and moves records', () async {
    await provider.loadAll();

    // Add records to Food category (ID 2)
    await provider.addRecord(Record(
      moneySourceId: 1,
      categoryId: 2,
      amount: 30.0,
      currency: 'USD',
      description: 'Lunch',
      type: 'expense',
    ));

    // Delete Food category
    await provider.deleteCategory(2);

    // Food should be gone
    expect(provider.categories.any((c) => c.categoryId == 2), isFalse);

    // Record should be in Uncategorized now
    final records = provider.records;
    for (final r in records) {
      if (r.description == 'Lunch') {
        expect(r.categoryId, 1);
      }
    }
  });

  test('Integration: getCategoryTotal returns correct sum after operations', () async {
    // Add records to Food category
    await repository.createRecord(Record(
      moneySourceId: 1,
      categoryId: 2,
      amount: 100.0,
      currency: 'USD',
      description: 'Dinner',
      type: 'expense',
    ));
    await repository.createRecord(Record(
      moneySourceId: 1,
      categoryId: 2,
      amount: 50.0,
      currency: 'USD',
      description: 'Snack',
      type: 'expense',
    ));

    await provider.loadAll();

    final total = provider.getCategoryTotal(2);
    expect(total, 150.0);
  });
}
