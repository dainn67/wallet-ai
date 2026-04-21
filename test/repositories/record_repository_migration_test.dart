import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/record_migration_service.dart';

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
            occurred_at INTEGER NOT NULL,
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

  group('RecordMigrationService.addOccurredAtColumn', () {
    Future<Database> openV7DbWithSeedRows(String path, List<int> lastUpdatedSeed) async {
      if (await databaseFactory.databaseExists(path)) {
        await databaseFactory.deleteDatabase(path);
      }
      final db = await openDatabase(path, version: 7, onCreate: (db, _) async {
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
            last_updated INTEGER NOT NULL
          )
        ''');
        await db.insert('MoneySource', {'source_id': 1, 'source_name': 'Wallet', 'amount': 0});
        for (final ts in lastUpdatedSeed) {
          await db.insert('Record', {
            'money_source_id': 1,
            'category_id': 1,
            'amount': 10.0,
            'currency': 'USD',
            'description': 'seed $ts',
            'type': 'expense',
            'last_updated': ts,
          });
        }
      });
      return db;
    }

    test('adds occurred_at column and backfills with last_updated', () async {
      final seeded = [1700000000000, 1710000000000, 1720000000000];
      final db = await openV7DbWithSeedRows('test_migration_occurred_at_backfill.db', seeded);

      await RecordMigrationService.addOccurredAtColumn(db);

      final columns = await db.rawQuery('PRAGMA table_info(Record)');
      expect(columns.any((c) => c['name'] == 'occurred_at'), isTrue);

      final rows = await db.query('Record', orderBy: 'last_updated ASC');
      expect(rows.map((r) => r['occurred_at']).toList(), seeded);
      for (final row in rows) {
        expect(row['occurred_at'], row['last_updated']);
        expect(row['occurred_at'], isNot(0));
        expect(row['occurred_at'], isNot(-1));
        expect(row['occurred_at'], isNotNull);
      }

      await db.close();
    });

    test('is idempotent — re-running only fills NULL rows', () async {
      final db = await openV7DbWithSeedRows('test_migration_occurred_at_idempotent.db', [1700000000000]);

      // First run — creates column, backfills.
      await RecordMigrationService.addOccurredAtColumn(db);

      // User edits a record: set occurred_at to a backdated time.
      const backdated = 1699999999999;
      await db.update('Record', {'occurred_at': backdated}, where: 'record_id = ?', whereArgs: [1]);

      // Second run — must NOT overwrite the user's edit.
      await RecordMigrationService.addOccurredAtColumn(db);

      final row = (await db.query('Record', where: 'record_id = 1')).first;
      expect(row['occurred_at'], backdated);

      await db.close();
    });

    test('creates idx_record_occurred_at index', () async {
      final db = await openV7DbWithSeedRows('test_migration_occurred_at_index.db', [1700000000000]);

      await RecordMigrationService.addOccurredAtColumn(db);

      final indexes = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='Record'");
      expect(indexes.any((i) => i['name'] == 'idx_record_occurred_at'), isTrue);

      await db.close();
    });
  });
}
