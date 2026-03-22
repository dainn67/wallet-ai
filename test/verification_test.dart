import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:flutter/services.dart';

void main() {
  // Initialize sqflite for ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock home_widget channel
  const MethodChannel channel = MethodChannel('home_widget');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    return null;
  });

  late RecordRepository repository;
  late RecordProvider provider;

  setUp(() async {
    repository = RecordRepository();
    final db = await openDatabase(inMemoryDatabasePath, version: 6,
        onCreate: (db, version) async {
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
      await db.insert('MoneySource', {'source_name': 'Bank', 'amount': 5000});
    });
    RecordRepository.setMockDatabase(db);
    provider = RecordProvider(repository: repository);
    await provider.loadAll();
  });

  group('Balance Verification after Edits', () {
    test('Editing record amount updates source balance correctly', () async {
      // 1. Create a record: Expense 200 from Wallet (initial 1000) -> 800
      final record = Record(
        moneySourceId: 1, // Wallet
        amount: 200,
        currency: 'VND',
        description: 'Lunch',
        type: 'expense',
      );
      await provider.addRecord(record);
      
      expect(provider.moneySources.firstWhere((s) => s.sourceId == 1).amount, 800);

      // 2. Edit record: Change amount to 500 -> Wallet should be 1000 - 500 = 500
      final addedRecord = provider.records.first;
      final updatedRecord = addedRecord.copyWith(amount: 500);
      await provider.updateRecord(updatedRecord);

      expect(provider.moneySources.firstWhere((s) => s.sourceId == 1).amount, 500);
      
      // 3. Edit record: Change to Income 300 -> Wallet should be 1000 + 300 = 1300
      final updatedRecord2 = updatedRecord.copyWith(amount: 300, type: 'income');
      await provider.updateRecord(updatedRecord2);
      
      expect(provider.moneySources.firstWhere((s) => s.sourceId == 1).amount, 1300);
    });

    test('Editing record source updates both sources correctly', () async {
      // 1. Create a record: Expense 200 from Wallet (initial 1000) -> 800. Bank is 5000.
      final record = Record(
        moneySourceId: 1, // Wallet
        amount: 200,
        currency: 'VND',
        description: 'Lunch',
        type: 'expense',
      );
      await provider.addRecord(record);
      
      expect(provider.moneySources.firstWhere((s) => s.sourceId == 1).amount, 800);
      expect(provider.moneySources.firstWhere((s) => s.sourceId == 2).amount, 5000);

      // 2. Edit record: Change source to Bank (ID: 2)
      // Wallet should go back to 1000.
      // Bank should go to 5000 - 200 = 4800.
      final addedRecord = provider.records.first;
      final updatedRecord = addedRecord.copyWith(moneySourceId: 2);
      await provider.updateRecord(updatedRecord);

      expect(provider.moneySources.firstWhere((s) => s.sourceId == 1).amount, 1000);
      expect(provider.moneySources.firstWhere((s) => s.sourceId == 2).amount, 4800);
    });

    test('Deleting record restores balance', () async {
      final record = Record(
        moneySourceId: 1, // Wallet
        amount: 200,
        currency: 'VND',
        description: 'Lunch',
        type: 'expense',
      );
      await provider.addRecord(record);
      expect(provider.moneySources.firstWhere((s) => s.sourceId == 1).amount, 800);

      await provider.deleteRecord(provider.records.first.recordId);
      expect(provider.moneySources.firstWhere((s) => s.sourceId == 1).amount, 1000);
    });
  });
}
