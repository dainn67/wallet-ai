import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/services/database_service.dart';
import 'package:wallet_ai/models/money_source.dart';
import 'package:wallet_ai/models/record.dart';

void main() {
  // Initialize sqflite ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseService Tests', () {
    late DatabaseService databaseService;
    late Database db;

    setUp(() async {
      // Create in-memory database
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE MoneySource (
            source_id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_name TEXT NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE record (
            record_id INTEGER PRIMARY KEY AUTOINCREMENT,
            money_source_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            currency TEXT NOT NULL,
            description TEXT,
            type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
            FOREIGN KEY (money_source_id) REFERENCES MoneySource (source_id)
          )
        ''');
          await db.insert('MoneySource', {'source_name': 'Wallet'});
          await db.insert('MoneySource', {'source_name': 'Bank'});
        },
      );

      DatabaseService.setMockDatabase(db);
      databaseService = DatabaseService();
    });

    tearDown(() async {
      await db.close();
    });

    group('MoneySource CRUD', () {
      test('getAllMoneySources returns initial data', () async {
        final sources = await databaseService.getAllMoneySources();
        expect(sources.length, 2);
        expect(sources[0].sourceName, 'Wallet');
        expect(sources[1].sourceName, 'Bank');
      });

      test('createMoneySource inserts a new source', () async {
        final newSource = MoneySource(sourceName: 'Credit Card');
        final id = await databaseService.createMoneySource(newSource);
        expect(id, 3);

        final sources = await databaseService.getAllMoneySources();
        expect(sources.length, 3);
        expect(sources.any((s) => s.sourceName == 'Credit Card'), isTrue);
      });

      test('updateMoneySource updates existing source', () async {
        final sources = await databaseService.getAllMoneySources();
        final sourceToUpdate = sources[0].copyWith(sourceName: 'Cash');
        await databaseService.updateMoneySource(sourceToUpdate);

        final updatedSources = await databaseService.getAllMoneySources();
        expect(updatedSources[0].sourceName, 'Cash');
      });

      test('deleteMoneySource removes a source', () async {
        await databaseService.deleteMoneySource(1);
        final sources = await databaseService.getAllMoneySources();
        expect(sources.length, 1);
        expect(sources[0].sourceName, 'Bank');
      });
    });

    group('Record CRUD', () {
      test('createRecord inserts a new record', () async {
        final record = Record(moneySourceId: 1, amount: 50.0, currency: 'USD', description: 'Lunch', type: 'expense');
        final id = await databaseService.createRecord(record);
        expect(id, 1);

        final records = await databaseService.getAllRecords();
        expect(records.length, 1);
        expect(records[0].description, 'Lunch');
      });

      test('updateRecord updates existing record', () async {
        final record = Record(moneySourceId: 1, amount: 50.0, currency: 'USD', description: 'Lunch', type: 'expense');
        final id = await databaseService.createRecord(record);

        final updatedRecord = Record(recordId: id, moneySourceId: 1, amount: 60.0, currency: 'USD', description: 'Expensive Lunch', type: 'expense');
        await databaseService.updateRecord(updatedRecord);

        final records = await databaseService.getAllRecords();
        expect(records[0].amount, 60.0);
        expect(records[0].description, 'Expensive Lunch');
      });

      test('deleteRecord removes a record', () async {
        final record = Record(moneySourceId: 1, amount: 50.0, currency: 'USD', description: 'Lunch', type: 'expense');
        final id = await databaseService.createRecord(record);

        await databaseService.deleteRecord(id);
        final records = await databaseService.getAllRecords();
        expect(records.isEmpty, isTrue);
      });
    });
  });
}
