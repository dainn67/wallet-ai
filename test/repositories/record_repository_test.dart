import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

/// Helper: build a v10 in-memory DB that mirrors _onCreate + _seedDatabase.
/// Uses singleInstance: false so each call gets a truly independent DB.
Future<Database> _buildV10Db() async {
  return openDatabase(
    inMemoryDatabasePath,
    version: 10,
    singleInstance: false,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE Category (
          category_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          parent_id INTEGER NOT NULL DEFAULT -1,
          emoji TEXT NOT NULL DEFAULT '🏷️'
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
          target_source_id INTEGER,
          category_id INTEGER NOT NULL DEFAULT 1,
          amount REAL NOT NULL,
          currency TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL CHECK(type IN ('income', 'expense', 'transfer')),
          last_updated INTEGER NOT NULL,
          occurred_at INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (money_source_id) REFERENCES MoneySource (source_id),
          FOREIGN KEY (target_source_id) REFERENCES MoneySource (source_id),
          FOREIGN KEY (category_id) REFERENCES Category (category_id)
        )
      ''');

      // Seed parents
      await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense', 'parent_id': -1, 'emoji': '🏷️'}); // 1
      await db.insert('Category', {'name': 'Food',          'type': 'expense', 'parent_id': -1, 'emoji': '🍔'});  // 2
      await db.insert('Category', {'name': 'Transport',     'type': 'expense', 'parent_id': -1, 'emoji': '🚗'});  // 3
      await db.insert('Category', {'name': 'Entertainment', 'type': 'expense', 'parent_id': -1, 'emoji': '🎬'});  // 4
      await db.insert('Category', {'name': 'Salary',        'type': 'income',  'parent_id': -1, 'emoji': '💰'});  // 5
      await db.insert('Category', {'name': 'Rent',          'type': 'expense', 'parent_id': -1, 'emoji': '🏠'});  // 6
      await db.insert('Category', {'name': 'Health',        'type': 'expense', 'parent_id': -1, 'emoji': '🏥'});  // 7
      await db.insert('Category', {'name': 'Shopping',      'type': 'expense', 'parent_id': -1, 'emoji': '🛍️'}); // 8
      await db.insert('Category', {'name': 'Transfer',      'type': 'transfer','parent_id': -1, 'emoji': '🔄'});  // 9
      // Seed subs
      await db.insert('Category', {'name': 'Groceries',   'type': 'expense', 'parent_id': 2, 'emoji': '🛒'});
      await db.insert('Category', {'name': 'Dining Out',  'type': 'expense', 'parent_id': 2, 'emoji': '🍽️'});
      await db.insert('Category', {'name': 'Taxi',        'type': 'expense', 'parent_id': 3, 'emoji': '🚕'});
      await db.insert('Category', {'name': 'Fuel',        'type': 'expense', 'parent_id': 3, 'emoji': '⛽'});
      await db.insert('Category', {'name': 'Cinema',      'type': 'expense', 'parent_id': 4, 'emoji': '🎥'});
      await db.insert('Category', {'name': 'Streaming',   'type': 'expense', 'parent_id': 4, 'emoji': '📺'});
      await db.insert('Category', {'name': 'Clothes',     'type': 'expense', 'parent_id': 8, 'emoji': '👕'});
      await db.insert('Category', {'name': 'Electronics', 'type': 'expense', 'parent_id': 8, 'emoji': '📱'});

      await db.insert('MoneySource', {'source_name': 'Wallet', 'amount': 0});
      await db.insert('MoneySource', {'source_name': 'Bank',   'amount': 0});
    },
  );
}

void main() {
  // Initialize sqflite for ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late RecordRepository repository;

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 9,
        singleInstance: false,
        onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE Category (
          category_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          parent_id INTEGER NOT NULL DEFAULT -1,
          emoji TEXT NOT NULL DEFAULT '🏷️'
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
          target_source_id INTEGER,
          category_id INTEGER NOT NULL DEFAULT 1,
          amount REAL NOT NULL,
          currency TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL CHECK(type IN ('income', 'expense', 'transfer')),
          last_updated INTEGER NOT NULL,
          occurred_at INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (money_source_id) REFERENCES MoneySource (source_id),
          FOREIGN KEY (target_source_id) REFERENCES MoneySource (source_id),
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

    test('updateCategoryAndReparent(top-level → sub) cascades existing children to the new parent', () async {
      // Setup: Food (id 2, root) with two children.
      final lifestyleId = await repository.createCategory(
        Category(name: 'Lifestyle', type: 'expense'),
      );
      final groceriesId = await repository.createCategory(
        Category(name: 'Groceries', type: 'expense', parentId: 2),
      );
      final diningId = await repository.createCategory(
        Category(name: 'Dining', type: 'expense', parentId: 2),
      );

      // Demote Food under Lifestyle.
      await repository.updateCategoryAndReparent(
        category: Category(categoryId: 2, name: 'Food', type: 'expense', parentId: lifestyleId, emoji: '🍔'),
        oldParentId: -1,
      );

      final categories = await repository.getAllCategories();
      Category byId(int id) => categories.firstWhere((c) => c.categoryId == id);

      expect(byId(2).parentId, lifestyleId, reason: 'Food now sub of Lifestyle');
      expect(byId(groceriesId).parentId, lifestyleId, reason: 'Groceries cascaded');
      expect(byId(diningId).parentId, lifestyleId, reason: 'Dining cascaded');
    });

    test('updateCategoryAndReparent(sub → top-level) does not touch other rows', () async {
      // Setup: Food (root), Groceries (sub of Food).
      final groceriesId = await repository.createCategory(
        Category(name: 'Groceries', type: 'expense', parentId: 2),
      );
      final unrelatedId = await repository.createCategory(
        Category(name: 'Transport', type: 'expense'),
      );

      // Promote Groceries to top-level.
      await repository.updateCategoryAndReparent(
        category: Category(categoryId: groceriesId, name: 'Groceries', type: 'expense', parentId: -1, emoji: '🛒'),
        oldParentId: 2,
      );

      final categories = await repository.getAllCategories();
      expect(categories.firstWhere((c) => c.categoryId == groceriesId).parentId, -1);
      expect(categories.firstWhere((c) => c.categoryId == 2).parentId, -1, reason: 'Food untouched');
      expect(categories.firstWhere((c) => c.categoryId == unrelatedId).parentId, -1, reason: 'unrelated untouched');
    });

    test('updateCategoryAndReparent rejects self-as-parent and Uncategorized', () async {
      expect(
        () => repository.updateCategoryAndReparent(
          category: Category(categoryId: 1, name: 'Uncategorized', type: 'expense', parentId: -1),
          oldParentId: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.updateCategoryAndReparent(
          category: Category(categoryId: 2, name: 'Food', type: 'expense', parentId: 2),
          oldParentId: -1,
        ),
        throwsArgumentError,
      );
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

  // --- v10 emoji tests (use a standalone v10 in-memory DB) ---

  group('Category v10 emoji — fresh install', () {
    late Database v10db;

    setUp(() async {
      v10db = await _buildV10Db();
      RecordRepository.setMockDatabase(v10db);
    });

    tearDown(() async {
      await v10db.close();
    });

    test('fresh-install seed: every parent carries the AD-5 emoji', () async {
      final repo = RecordRepository();
      final categories = await repo.getAllCategories();

      String emojiFor(String name) =>
          categories.firstWhere((c) => c.name == name).emoji;

      expect(emojiFor('Uncategorized'), '🏷️');
      expect(emojiFor('Food'),          '🍔');
      expect(emojiFor('Transport'),     '🚗');
      expect(emojiFor('Entertainment'), '🎬');
      expect(emojiFor('Salary'),        '💰');
      expect(emojiFor('Rent'),          '🏠');
      expect(emojiFor('Health'),        '🏥');
      expect(emojiFor('Shopping'),      '🛍️');
      expect(emojiFor('Transfer'),      '🔄');
    });

    test('fresh-install seed: every sub-category carries the AD-5 emoji', () async {
      final repo = RecordRepository();
      final categories = await repo.getAllCategories();

      String emojiFor(String name) =>
          categories.firstWhere((c) => c.name == name).emoji;

      expect(emojiFor('Groceries'),   '🛒');
      expect(emojiFor('Dining Out'),  '🍽️');
      expect(emojiFor('Taxi'),        '🚕');
      expect(emojiFor('Fuel'),        '⛽');
      expect(emojiFor('Cinema'),      '🎥');
      expect(emojiFor('Streaming'),   '📺');
      expect(emojiFor('Clothes'),     '👕');
      expect(emojiFor('Electronics'), '📱');
    });

    test('user-created Category without emoji defaults to 🏷️ on readback', () async {
      final repo = RecordRepository();
      // Insert using raw DB to simulate a Category created without emoji field.
      await v10db.insert('Category', {'name': 'Custom', 'type': 'expense', 'parent_id': -1});
      final categories = await repo.getAllCategories();
      final custom = categories.firstWhere((c) => c.name == 'Custom');
      expect(custom.emoji, '🏷️');
    });
  });
}
