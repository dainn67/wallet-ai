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
          created_at INTEGER NOT NULL,
          FOREIGN KEY (money_source_id) REFERENCES MoneySource (source_id),
          FOREIGN KEY (category_id) REFERENCES Category (category_id)
        )
      ''');

      // Seed initial data
      await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense'}); // ID: 1
    });

    RecordRepository.setMockDatabase(db);
    repository = RecordRepository();
  });

  tearDown(() async {
    await db.close();
  });

  group('Source DB Integration', () {
    test('Integration: createMoneySource with amount > 0 correctly updates tables', () async {
      // 1. Create a new source with initial balance
      final source = MoneySource(sourceName: 'Savings Account', amount: 1250.50);
      final sourceId = await repository.createMoneySource(source);

      // 2. Verify MoneySource table
      final sources = await repository.getAllMoneySources();
      final createdSource = sources.firstWhere((s) => s.sourceId == sourceId);
      expect(createdSource.sourceName, 'Savings Account');
      expect(createdSource.amount, 1250.50);

      // 3. Verify record table (should have an 'income' record for the initial balance)
      final records = await repository.getAllRecords();
      final initialRecord = records.firstWhere((r) => r.moneySourceId == sourceId);
      
      expect(initialRecord.amount, 1250.50);
      expect(initialRecord.type, 'income');
      expect(initialRecord.description, 'Initial Balance');
      expect(initialRecord.categoryId, 1); // Uncategorized
    });

    test('Integration: createMoneySource with amount 0 only creates source', () async {
      // 1. Create a new source with zero balance
      final source = MoneySource(sourceName: 'Empty Wallet', amount: 0);
      final sourceId = await repository.createMoneySource(source);

      // 2. Verify MoneySource table
      final sources = await repository.getAllMoneySources();
      final createdSource = sources.firstWhere((s) => s.sourceId == sourceId);
      expect(createdSource.sourceName, 'Empty Wallet');
      expect(createdSource.amount, 0);

      // 3. Verify record table (should have NO record for this source)
      final records = await repository.getAllRecords();
      final sourceRecords = records.where((r) => r.moneySourceId == sourceId);
      expect(sourceRecords, isEmpty);
    });

    test('Integration: duplicate source names are handled (case insensitive)', () async {
      // 1. Create first source
      await repository.createMoneySource(MoneySource(sourceName: 'Wallet', amount: 100));
      
      // 2. Try to find by name (case insensitive)
      final found = await repository.getMoneySourceByName('WALLET');
      expect(found, isNotNull);
      expect(found!.sourceName, 'Wallet');
    });
  });
}
