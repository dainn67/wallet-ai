import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

void main() {
  // Initialize sqflite for ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late RecordRepository repository;

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 5,
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

      // Seed initial data
      await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense'}); // ID: 1
      await db.insert('Category', {'name': 'Food', 'type': 'expense'}); // ID: 2
      await db.insert('MoneySource', {'source_name': 'Wallet', 'amount': 1000}); // ID: 1
    });

    RecordRepository.setMockDatabase(db);
    repository = RecordRepository();
  });

  tearDown(() async {
    await db.close();
  });

  group('RecordRepository JOIN tests', () {
    test('getAllRecords returns records with category names', () async {
      // Insert a record with category_id 2 (Food)
      final record = Record(
        recordId: 100,
        moneySourceId: 1,
        categoryId: 2,
        amount: 50.0,
        currency: 'VND',
        description: 'Lunch',
        type: 'expense',
        lastUpdated: 1000,
      );
      await repository.createRecord(record);

      // Fetch all records
      final records = await repository.getAllRecords();

      expect(records.length, 1);
      expect(records[0].recordId, 100);
      expect(records[0].categoryId, 2);
      expect(records[0].categoryName, 'Food');
    });

    test('getRecordById returns record with category name', () async {
      // Insert a record with category_id 2 (Food)
      final record = Record(
        recordId: 101,
        moneySourceId: 1,
        categoryId: 2,
        amount: 30.0,
        currency: 'VND',
        description: 'Snack',
        type: 'expense',
        lastUpdated: 2000,
      );
      await repository.createRecord(record);

      // Fetch record by id
      final fetchedRecord = await repository.getRecordById(101);

      expect(fetchedRecord, isNotNull);
      expect(fetchedRecord!.recordId, 101);
      expect(fetchedRecord.categoryId, 2);
      expect(fetchedRecord.categoryName, 'Food');
    });

    test('record with default category (Uncategorized)', () async {
      // Insert a record without specifying categoryId (defaults to 1)
      final record = Record(
        recordId: 102,
        moneySourceId: 1,
        amount: 10.0,
        currency: 'VND',
        description: 'Something',
        type: 'expense',
        lastUpdated: 3000,
      );
      await repository.createRecord(record);

      final fetchedRecord = await repository.getRecordById(102);

      expect(fetchedRecord, isNotNull);
      expect(fetchedRecord!.categoryId, 1);
      expect(fetchedRecord.categoryName, 'Uncategorized');
    });
  });

  group('MoneySource Management', () {
    test('createMoneySource creates source and initial balance record when amount > 0', () async {
      final source = MoneySource(sourceName: 'Savings', amount: 500.0);
      final sourceId = await repository.createMoneySource(source);

      // Verify source was created
      final fetchedSource = (await repository.getAllMoneySources()).firstWhere((s) => s.sourceId == sourceId);
      expect(fetchedSource.sourceName, 'Savings');
      expect(fetchedSource.amount, 500.0);

      // Verify record was created
      final records = await repository.getAllRecords();
      final initialRecord = records.firstWhere((r) => r.moneySourceId == sourceId);
      expect(initialRecord.amount, 500.0);
      expect(initialRecord.type, 'income');
      expect(initialRecord.description, 'Initial Balance');
    });

    test('createMoneySource only creates source when amount is 0', () async {
      final source = MoneySource(sourceName: 'Empty', amount: 0);
      final sourceId = await repository.createMoneySource(source);

      // Verify source was created
      final fetchedSource = (await repository.getAllMoneySources()).firstWhere((s) => s.sourceId == sourceId);
      expect(fetchedSource.amount, 0);

      // Verify no record was created for this source
      final records = await repository.getAllRecords();
      final sourceRecords = records.where((r) => r.moneySourceId == sourceId);
      expect(sourceRecords, isEmpty);
    });

    test('deleteMoneySource deletes source and all associated records', () async {
      // 1. Setup: Create a source and some records
      final source = MoneySource(sourceName: 'Temporary Bank', amount: 1000.0);
      final sourceId = await repository.createMoneySource(source);

      // Add another record to this source
      await repository.createRecord(Record(
        moneySourceId: sourceId,
        amount: 200.0,
        currency: 'VND',
        description: 'Dinner',
        type: 'expense',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      ));

      // Verify setup
      var sources = await repository.getAllMoneySources();
      expect(sources.any((s) => s.sourceId == sourceId), isTrue);
      
      var records = await repository.getAllRecords();
      var sourceRecords = records.where((r) => r.moneySourceId == sourceId);
      expect(sourceRecords.length, 2); // Initial balance + Dinner

      // 2. Execute Delete
      await repository.deleteMoneySource(sourceId);

      // 3. Verify Result
      sources = await repository.getAllMoneySources();
      expect(sources.any((s) => s.sourceId == sourceId), isFalse);

      records = await repository.getAllRecords();
      sourceRecords = records.where((r) => r.moneySourceId == sourceId);
      expect(sourceRecords, isEmpty);
    });
  });

  group('Category Management', () {
    test('createCategory creates a new category', () async {
      final category = Category(name: 'Education', type: 'expense');
      final id = await repository.createCategory(category);
      expect(id, 3); // Uncategorized (1), Food (2), Education (3)

      final categories = await repository.getAllCategories();
      expect(categories.length, 3);
      expect(categories.any((c) => c.name == 'Education'), isTrue);
    });

    test('updateCategory updates an existing category', () async {
      final category = Category(categoryId: 2, name: 'Dining', type: 'expense');
      await repository.updateCategory(category);

      final categories = await repository.getAllCategories();
      final updated = categories.firstWhere((c) => c.categoryId == 2);
      expect(updated.name, 'Dining');
    });

    test('updateCategory(1) throws ArgumentError', () async {
      final category = Category(categoryId: 1, name: 'Changed', type: 'expense');
      expect(() => repository.updateCategory(category), throwsArgumentError);
    });

    test('deleteCategory(1) throws ArgumentError', () async {
      expect(() => repository.deleteCategory(1), throwsArgumentError);
    });

    test('deleteCategory moves records to ID 1 and deletes category (5 records)', () async {
      // 1. Setup: Category (ID 2: Food) and 5 records
      for (int i = 0; i < 5; i++) {
        await repository.createRecord(Record(
          moneySourceId: 1,
          categoryId: 2,
          amount: 10.0 + i,
          currency: 'VND',
          description: 'Record $i',
          type: 'expense',
          lastUpdated: 1000 + i,
        ));
      }

      // Verify records are in Category 2
      var records = await repository.getAllRecords();
      expect(records.where((r) => r.categoryId == 2).length, 5);

      // 2. Execute deleteCategory(2)
      await repository.deleteCategory(2);

      // 3. Verify category 2 is gone
      final categories = await repository.getAllCategories();
      expect(categories.any((c) => c.categoryId == 2), isFalse);

      // 4. Verify records are moved to Category 1
      records = await repository.getAllRecords();
      expect(records.where((r) => r.categoryId == 2).length, 0);
      expect(records.where((r) => r.categoryId == 1).length, 5);
    });

    test('getRecordCountByCategoryId returns correct count', () async {
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 2,
        amount: 10.0,
        currency: 'USD',
        description: 'Test 1',
        type: 'expense',
      ));
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 2,
        amount: 20.0,
        currency: 'USD',
        description: 'Test 2',
        type: 'expense',
      ));

      final count = await repository.getRecordCountByCategoryId(2);
      expect(count, 2);

      final emptyCount = await repository.getRecordCountByCategoryId(1);
      expect(emptyCount, 0);
    });

    test('getCategoryTotals returns correct sums', () async {
      // Category 1: 0 records
      // Category 2: 100 + 50 = 150
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 2,
        amount: 100.0,
        currency: 'USD',
        description: 'Test 3',
        type: 'expense',
      ));
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 2,
        amount: 50.0,
        currency: 'USD',
        description: 'Test 4',
        type: 'expense',
      ));

      // Category 3: 200
      await repository.createCategory(Category(name: 'New', type: 'income')); // ID: 3
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 3,
        amount: 200.0,
        currency: 'USD',
        description: 'Test 5',
        type: 'income',
      ));

      final totals = await repository.getCategoryTotals();
      expect(totals[2], 150.0);
      expect(totals[3], 200.0);
      expect(totals[1], isNull); // No records for category 1
    });
  });

  group('resetAllData', () {
    test('resetAllData deletes all records and resets source amounts', () async {
      // 1. Setup: Ensure we have some data
      // Add a money source (ID: 1 already exists from setUp, but let's add another)
      final sourceId = await repository.createMoneySource(MoneySource(sourceName: 'Test Bank', amount: 1000.0));
      
      // Add a record
      await repository.createRecord(Record(
        moneySourceId: sourceId,
        amount: 200.0,
        currency: 'VND',
        description: 'Test Expense',
        type: 'expense',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      ));

      // Verify current state
      var sources = await repository.getAllMoneySources();
      expect(sources.length, 2); // Wallet (from setUp) and Test Bank
      
      var records = await repository.getAllRecords();
      expect(records.length, greaterThan(0));

      // 2. Execute Reset
      await repository.resetAllData();

      // 3. Verify Result
      records = await repository.getAllRecords();
      expect(records, isEmpty);

      sources = await repository.getAllMoneySources();
      expect(sources.length, 2);
      for (var source in sources) {
        expect(source.amount, 0.0);
      }
    });
  });
}
