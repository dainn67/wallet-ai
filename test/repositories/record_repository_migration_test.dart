import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('RecordRepository Migration & Hierarchy Tests', () {
    test('Migration from v6 to v7 adds parent_id column', () async {
      // 1. Create a v6 database
      final dbPath = inMemoryDatabasePath;
      var db = await openDatabase(dbPath, version: 6,
          onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE Category (
            category_id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL
          )
        ''');
        await db.insert('Category', {'name': 'Food', 'type': 'expense'});
      });

      // Verify v6 state
      var columns = await db.rawQuery('PRAGMA table_info(Category)');
      expect(columns.any((c) => c['name'] == 'parent_id'), isFalse);
      await db.close();

      // 2. Open with RecordRepository (triggers onUpgrade to v7)
      // We need to use a real file path for migration test if we want to reopen it, 
      // but inMemoryDatabasePath with same name might not work as expected if closed.
      // Let's use a temporary file.
      final path = 'test_migration.db';
      
      // Clean up if exists
      if (await databaseFactory.databaseExists(path)) {
        await databaseFactory.deleteDatabase(path);
      }

      db = await openDatabase(path, version: 6,
          onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE Category (
            category_id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL
          )
        ''');
        await db.insert('Category', {'name': 'Food', 'type': 'expense'});
      });
      await db.close();

      // Now open with version 7 and the actual migration logic
      db = await openDatabase(path, version: 7, onUpgrade: (db, old, newV) async {
        if (old < 7) {
          await db.execute('ALTER TABLE Category ADD COLUMN parent_id INTEGER NOT NULL DEFAULT -1');
        }
      });

      columns = await db.rawQuery('PRAGMA table_info(Category)');
      expect(columns.any((c) => c['name'] == 'parent_id'), isTrue);
      
      final result = await db.query('Category');
      expect(result.first['parent_id'], -1);
      
      await db.close();
      await databaseFactory.deleteDatabase(path);
    });

    test('Category name formatting "Parent - Sub"', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 7,
          onCreate: (Database db, int version) async {
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

        // Seed
        await db.insert('Category', {'category_id': 1, 'name': 'Food', 'type': 'expense', 'parent_id': -1});
        await db.insert('Category', {'category_id': 2, 'name': 'Groceries', 'type': 'expense', 'parent_id': 1});
        await db.insert('MoneySource', {'source_id': 1, 'source_name': 'Wallet', 'amount': 1000});
      });

      RecordRepository.setMockDatabase(db);
      final repository = RecordRepository();

      // 1. Record with sub-category
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 2, // Groceries
        amount: 50.0,
        currency: 'USD',
        description: 'Milk',
        type: 'expense',
      ));

      // 2. Record with parent category
      await repository.createRecord(Record(
        moneySourceId: 1,
        categoryId: 1, // Food
        amount: 100.0,
        currency: 'USD',
        description: 'Dinner',
        type: 'expense',
      ));

      final records = await repository.getAllRecords();
      expect(records.length, 2);
      
      // Order is by last_updated DESC. Since we didn't specify, they might be same or close.
      // Let's check by description.
      final groceriesRecord = records.firstWhere((r) => r.description == 'Milk');
      final foodRecord = records.firstWhere((r) => r.description == 'Dinner');

      expect(groceriesRecord.categoryName, 'Food - Groceries');
      expect(foodRecord.categoryName, 'Food');

      await db.close();
    });
  });
}
