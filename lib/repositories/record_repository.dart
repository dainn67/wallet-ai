import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wallet_ai/models/models.dart';

class RecordRepository {
  static final RecordRepository _instance = RecordRepository._internal();
  static Database? _database;

  factory RecordRepository() => _instance;

  RecordRepository._internal();

  @visibleForTesting
  static void setMockDatabase(Database db) {
    _database = db;
  }

  Database get database {
    if (_database == null) {
      throw Exception("RecordRepository must be initialized before use.");
    }
    return _database!;
  }

  /// Must be initialized in main before runApp
  static Future<void> init() async {
    if (_database != null) return;

    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'data.db');

      // Check if the database exists
      final exists = await databaseExists(path);

      if (!exists) {
        // Copy from assets
        try {
          await Directory(dirname(path)).create(recursive: true);
          ByteData data = await rootBundle.load(join('assets', 'database', 'data.db'));
          List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await File(path).writeAsBytes(bytes, flush: true);
        } catch (e) {
          debugPrint("Log: Initializing new database as asset data.db was not found or could not be loaded: $e");
        }
      } else {
        debugPrint("Database already exists at $path");
      }

      _database = await openDatabase(path, version: _dbVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
    } catch (e) {
      debugPrint("Error initializing database: $e");
      rethrow;
    }
  }

  static const int _dbVersion = 5;

  static Future<void> _onCreate(Database db, int version) async {
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

    await db.execute('CREATE INDEX idx_record_money_source_id ON record(money_source_id)');
    await db.execute('CREATE INDEX idx_record_category_id ON record(category_id)');
    await db.execute('CREATE INDEX idx_record_type ON record(type)');
    await db.execute('CREATE INDEX idx_record_created_at ON record(created_at)');

    // Initial Data
    await _seedDatabase(db);
  }

  static Future<void> _seedDatabase(Database db) async {
    // Seed Categories
    await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense'}); // ID: 1
    await db.insert('Category', {'name': 'Food', 'type': 'expense'});
    await db.insert('Category', {'name': 'Transport', 'type': 'expense'});
    await db.insert('Category', {'name': 'Entertainment', 'type': 'expense'});
    await db.insert('Category', {'name': 'Salary', 'type': 'income'});
    await db.insert('Category', {'name': 'Rent', 'type': 'expense'});
    await db.insert('Category', {'name': 'Health', 'type': 'expense'});

    // Seed MoneySources
    await db.insert('MoneySource', {'source_name': 'Wallet', 'amount': 0});
    await db.insert('MoneySource', {'source_name': 'Bank', 'amount': 0});
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE record ADD COLUMN created_at INTEGER');
      await db.execute('''
        UPDATE record
        SET created_at =
          CASE
            WHEN record_id IS NOT NULL AND record_id > 1000000000000 THEN record_id
            ELSE CAST(strftime('%s','now') AS INTEGER) * 1000
          END
        WHERE created_at IS NULL
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_record_money_source_id ON record(money_source_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_record_type ON record(type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_record_created_at ON record(created_at)');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE MoneySource ADD COLUMN amount REAL NOT NULL DEFAULT 0');
      await db.execute('UPDATE MoneySource SET amount = COALESCE(amount, 0)');
    }
    if (oldVersion < 5) {
      // User requested fresh start for this version
      await db.execute('DROP TABLE IF EXISTS record');
      await db.execute('DROP TABLE IF EXISTS MoneySource');
      await db.execute('DROP TABLE IF EXISTS Category');
      await _onCreate(db, newVersion);
    }
  }

  Future<void> _adjustMoneySourceAmount(DatabaseExecutor txn, {required int sourceId, required double delta}) async {
    await txn.rawUpdate(
      'UPDATE MoneySource SET amount = amount + ? WHERE source_id = ?',
      [delta, sourceId],
    );
  }

  // Record Management
  Future<int> createRecord(Record record) async {
    try {
      await database.transaction((txn) async {
        await txn.insert('record', record.toMap());
        final delta = record.type == 'income' ? record.amount : -record.amount;
        await _adjustMoneySourceAmount(txn, sourceId: record.moneySourceId, delta: delta);
      });

      return record.recordId;
    } catch (e) {
      print("Error creating record: $e");
      rethrow;
    }
  }

  Future<List<Record>> getAllRecords() async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery('''
        SELECT r.*, c.name as category_name
        FROM record r
        LEFT JOIN Category c ON r.category_id = c.category_id
        ORDER BY r.created_at DESC
      ''');
      return List.generate(maps.length, (i) => Record.fromMap(maps[i]));
    } catch (e) {
      print("Error fetching records: $e");
      rethrow;
    }
  }

  Future<Record?> getRecordById(int id) async {
    try {
      final maps = await database.rawQuery('''
        SELECT r.*, c.name as category_name
        FROM record r
        LEFT JOIN Category c ON r.category_id = c.category_id
        WHERE r.record_id = ?
        LIMIT 1
      ''', [id]);
      if (maps.isEmpty) return null;
      return Record.fromMap(maps.first);
    } catch (e) {
      print("Error fetching record by id: $e");
      return null;
    }
  }

  Future<int> updateRecord(Record record) async {
    try {
      final existing = await getRecordById(record.recordId);
      if (existing == null) throw Exception("Record not found for update: ${record.recordId}");

      await database.transaction((txn) async {
        final oldSigned = existing.type == 'income' ? existing.amount : -existing.amount;
        final newSigned = record.type == 'income' ? record.amount : -record.amount;
        final delta = newSigned - oldSigned;
        await _adjustMoneySourceAmount(txn, sourceId: record.moneySourceId, delta: delta);
        await txn.update('record', record.toMap(), where: 'record_id = ?', whereArgs: [record.recordId]);
      });

      return 1;
    } catch (e) {
      print("Error updating record: $e");
      rethrow;
    }
  }

  Future<int> deleteRecord(int id) async {
    try {
      final existing = await getRecordById(id);
      if (existing == null) return 0;

      await database.transaction((txn) async {
        final delta = existing.type == 'income' ? -existing.amount : existing.amount;
        await _adjustMoneySourceAmount(txn, sourceId: existing.moneySourceId, delta: delta);
        await txn.delete('record', where: 'record_id = ?', whereArgs: [id]);
      });

      return 1;
    } catch (e) {
      print("Error deleting record: $e");
      rethrow;
    }
  }

  // MoneySource Management
  Future<int> createMoneySource(MoneySource source) async {
    try {
      return await database.insert('MoneySource', source.toMap());
    } catch (e) {
      print("Error creating money source: $e");
      rethrow;
    }
  }

  Future<List<MoneySource>> getAllMoneySources() async {
    try {
      final List<Map<String, dynamic>> maps = await database.query('MoneySource');
      return List.generate(maps.length, (i) => MoneySource.fromMap(maps[i]));
    } catch (e) {
      print("Error fetching money sources: $e");
      rethrow;
    }
  }

  Future<MoneySource?> getMoneySourceByName(String name) async {
    try {
      final List<Map<String, dynamic>> maps = await database.query(
        'MoneySource',
        where: 'LOWER(source_name) = ?',
        whereArgs: [name.toLowerCase()],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return MoneySource.fromMap(maps.first);
    } catch (e) {
      print("Error fetching money source by name: $e");
      return null;
    }
  }

  Future<int> updateMoneySource(MoneySource source) async {
    try {
      if (source.sourceId == null) throw Exception("Source ID cannot be null for update");
      return await database.update('MoneySource', source.toMap(), where: 'source_id = ?', whereArgs: [source.sourceId]);
    } catch (e) {
      print("Error updating money source: $e");
      rethrow;
    }
  }

  Future<void> setMoneySourceAmount({required int sourceId, required double amount}) async {
    await database.update('MoneySource', {'amount': amount}, where: 'source_id = ?', whereArgs: [sourceId]);
  }

  Future<void> adjustMoneySourceAmount({required int sourceId, required double delta}) async {
    await _adjustMoneySourceAmount(database, sourceId: sourceId, delta: delta);
  }

  Future<int> deleteMoneySource(int id) async {
    try {
      return await database.delete('MoneySource', where: 'source_id = ?', whereArgs: [id]);
    } catch (e) {
      print("Error deleting money source: $e");
      rethrow;
    }
  }

  // Category Management
  Future<List<Category>> getAllCategories() async {
    try {
      final List<Map<String, dynamic>> maps = await database.query('Category');
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      print("Error fetching categories: $e");
      rethrow;
    }
  }
}
