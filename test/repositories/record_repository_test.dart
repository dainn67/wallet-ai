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
        CREATE TABLE record (
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
  });
}
