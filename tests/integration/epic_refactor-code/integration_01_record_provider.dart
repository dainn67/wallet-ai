// Integration Test 01: RecordProvider computed getters and navigateMonth
// Verifies AD-2 (boilerplate extraction) and T3 (computed getters) work correctly.
// Uses in-memory SQLite to avoid side effects.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/providers/record_provider.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('home_widget');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async => null);

  late RecordRepository repository;
  late RecordProvider provider;

  setUp(() async {
    repository = RecordRepository();
    final db = await openDatabase(inMemoryDatabasePath, version: 7,
        onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE Category (
          category_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          parent_id INTEGER NOT NULL DEFAULT -1
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
      await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense', 'parent_id': -1});
      await db.insert('MoneySource', {'source_name': 'Wallet', 'amount': 1000});
    });
    RecordRepository.setMockDatabase(db);
    provider = RecordProvider(repository: repository);
    await provider.loadAll();
  });

  tearDown(() async {
    await RecordRepository().database.close();
  });

  group('T3: RecordProvider computed getters', () {
    test('filteredTotalIncome returns sum of income records', () async {
      await provider.addRecord(Record(
        moneySourceId: 1,
        amount: 300,
        currency: 'VND',
        description: 'Salary',
        type: 'income',
      ));
      await provider.addRecord(Record(
        moneySourceId: 1,
        amount: 100,
        currency: 'VND',
        description: 'Bonus',
        type: 'income',
      ));
      await provider.addRecord(Record(
        moneySourceId: 1,
        amount: 50,
        currency: 'VND',
        description: 'Lunch',
        type: 'expense',
      ));

      expect(provider.filteredTotalIncome, equals(400.0));
    });

    test('filteredTotalExpense returns sum of expense records', () async {
      await provider.addRecord(Record(
        moneySourceId: 1,
        amount: 200,
        currency: 'VND',
        description: 'Salary',
        type: 'income',
      ));
      await provider.addRecord(Record(
        moneySourceId: 1,
        amount: 75,
        currency: 'VND',
        description: 'Lunch',
        type: 'expense',
      ));
      await provider.addRecord(Record(
        moneySourceId: 1,
        amount: 25,
        currency: 'VND',
        description: 'Coffee',
        type: 'expense',
      ));

      expect(provider.filteredTotalExpense, equals(100.0));
    });

    test('totalBalance returns sum of all money sources', () async {
      expect(provider.totalBalance, equals(1000.0));
    });

    test('computed getters return 0 when no records', () {
      expect(provider.filteredTotalIncome, equals(0.0));
      expect(provider.filteredTotalExpense, equals(0.0));
    });
  });

  group('T1+T2: createRecord returns valid ID', () {
    test('createRecord returns positive integer ID', () async {
      final record = Record(
        moneySourceId: 1,
        amount: 100,
        currency: 'VND',
        description: 'Test',
        type: 'expense',
      );
      final id = await provider.createRecord(record);
      expect(id, greaterThan(0));
    });

    test('createRecord does not trigger loadAll (no notifyListeners side effect)', () async {
      // createRecord is a lightweight operation for batch chat use
      // Verify the record is in DB by checking after an explicit loadAll
      final record = Record(
        moneySourceId: 1,
        amount: 50,
        currency: 'VND',
        description: 'Chat record',
        type: 'expense',
      );
      await provider.createRecord(record);
      // provider.records should NOT contain the new record yet (no loadAll called)
      final countBefore = provider.records.length;

      await provider.loadAll();
      // After loadAll, it should appear
      expect(provider.records.length, equals(countBefore + 1));
    });
  });

  group('T2: _performOperation boilerplate (via CRUD methods)', () {
    test('addRecord adds record and reloads state', () async {
      final initialCount = provider.records.length;
      await provider.addRecord(Record(
        moneySourceId: 1,
        amount: 100,
        currency: 'VND',
        description: 'Test',
        type: 'expense',
      ));
      expect(provider.records.length, equals(initialCount + 1));
    });

    test('updateRecord updates existing record', () async {
      await provider.addRecord(Record(
        moneySourceId: 1,
        amount: 100,
        currency: 'VND',
        description: 'Original',
        type: 'expense',
      ));
      final added = provider.records.first;
      await provider.updateRecord(added.copyWith(description: 'Updated'));
      final updated = provider.records.firstWhere((r) => r.recordId == added.recordId);
      expect(updated.description, equals('Updated'));
    });

    test('deleteRecord removes record', () async {
      await provider.addRecord(Record(
        moneySourceId: 1,
        amount: 100,
        currency: 'VND',
        description: 'ToDelete',
        type: 'expense',
      ));
      final countBefore = provider.records.length;
      await provider.deleteRecord(provider.records.first.recordId);
      expect(provider.records.length, equals(countBefore - 1));
    });
  });
}
