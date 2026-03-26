import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

/// Smoke test: Uncategorized (ID 1) cannot be deleted or updated
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
    });
    RecordRepository.setMockDatabase(db);
    repository = RecordRepository();
  });

  tearDown(() async {
    await db.close();
  });

  test('Smoke: deleteCategory(1) throws ArgumentError', () async {
    expect(
      () => repository.deleteCategory(1),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('Smoke: updateCategory(1) throws ArgumentError', () async {
    expect(
      () => repository.updateCategory(
        Category(categoryId: 1, name: 'Renamed', type: 'expense'),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('Smoke: Uncategorized still exists after failed delete attempt', () async {
    try {
      await repository.deleteCategory(1);
    } catch (_) {}

    final categories = await repository.getAllCategories();
    expect(categories.any((c) => c.categoryId == 1 && c.name == 'Uncategorized'), isTrue);
  });
}
