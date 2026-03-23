import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/storage_service.dart';

class RecordRepository {
  static final RecordRepository _instance = RecordRepository._internal();
  static RecordRepository? _mockInstance;
  static Database? _database;

  factory RecordRepository() => _mockInstance ?? _instance;

  RecordRepository._internal();

  @visibleForTesting
  static void setMockInstance(RecordRepository? instance) {
    _mockInstance = instance;
  }

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

  static const int _dbVersion = 6;

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

    await db.execute('CREATE INDEX idx_record_money_source_id ON Record(money_source_id)');
    await db.execute('CREATE INDEX idx_record_category_id ON Record(category_id)');
    await db.execute('CREATE INDEX idx_record_type ON Record(type)');
    await db.execute('CREATE INDEX idx_record_last_updated ON Record(last_updated)');

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
    if (oldVersion < 6) {
      // User requested fresh start for this version
      await db.execute('DROP TABLE IF EXISTS record'); // Old table name
      await db.execute('DROP TABLE IF EXISTS Record'); // New table name
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

  Future<int> createRecord(Record record) async {
    try {
      int insertedId = 0;
      await database.transaction((txn) async {
        insertedId = await txn.insert('Record', record.toMap());
        print("Log: Created record $insertedId");
        final delta = record.type == 'income' ? record.amount : -record.amount;
        print("Log: Adjusting source ${record.moneySourceId} by delta $delta");
        await _adjustMoneySourceAmount(txn, sourceId: record.moneySourceId, delta: delta);
      });

      return insertedId;
    } catch (e) {
      print("Error creating record: $e");
      rethrow;
    }
  }

  Future<List<Record>> getAllRecords() async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery('''
        SELECT r.*, c.name as category_name, ms.source_name
        FROM Record r
        LEFT JOIN Category c ON r.category_id = c.category_id
        LEFT JOIN MoneySource ms ON r.money_source_id = ms.source_id
        ORDER BY r.last_updated DESC
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
        SELECT r.*, c.name as category_name, ms.source_name
        FROM Record r
        LEFT JOIN Category c ON r.category_id = c.category_id
        LEFT JOIN MoneySource ms ON r.money_source_id = ms.source_id
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
      print("Log: Updating record ${record.recordId}");
      await database.transaction((txn) async {
        // Fetch existing record within the same transaction to ensure consistency
        final maps = await txn.rawQuery('''
          SELECT r.*, c.name as category_name, ms.source_name
          FROM Record r
          LEFT JOIN Category c ON r.category_id = c.category_id
          LEFT JOIN MoneySource ms ON r.money_source_id = ms.source_id
          WHERE r.record_id = ?
          LIMIT 1
        ''', [record.recordId]);

        if (maps.isEmpty) {
           print("Log: Record not found for update: ${record.recordId}");
           throw Exception("Record not found for update: ${record.recordId}");
        }
        final existing = Record.fromMap(maps.first);
        print("Log: Existing record found: ${existing.amount} from source ${existing.moneySourceId}");

        // 1. Reverse the old record's impact on its source
        final oldRevertDelta = existing.type == 'income' ? -existing.amount : existing.amount;
        print("Log: Reverting old impact: delta $oldRevertDelta on source ${existing.moneySourceId}");
        await _adjustMoneySourceAmount(txn, sourceId: existing.moneySourceId, delta: oldRevertDelta);

        // 2. Apply the new record's impact on its source
        final newApplyDelta = record.type == 'income' ? record.amount : -record.amount;
        print("Log: Applying new impact: delta $newApplyDelta on source ${record.moneySourceId}");
        await _adjustMoneySourceAmount(txn, sourceId: record.moneySourceId, delta: newApplyDelta);

        // 3. Update the record data
        await txn.update('Record', record.toMap(), where: 'record_id = ?', whereArgs: [record.recordId]);
      });

      return 1;
    } catch (e) {
      print("Error updating record: $e");
      rethrow;
    }
  }

  Future<int> deleteRecord(int id) async {
    try {
      await database.transaction((txn) async {
        // Fetch existing record within the transaction
        final maps = await txn.rawQuery('''
          SELECT r.*, c.name as category_name, ms.source_name
          FROM Record r
          LEFT JOIN Category c ON r.category_id = c.category_id
          LEFT JOIN MoneySource ms ON r.money_source_id = ms.source_id
          WHERE r.record_id = ?
          LIMIT 1
        ''', [id]);

        if (maps.isEmpty) return;

        final existing = Record.fromMap(maps.first);
        final delta = existing.type == 'income' ? -existing.amount : existing.amount;
        await _adjustMoneySourceAmount(txn, sourceId: existing.moneySourceId, delta: delta);
        await txn.delete('Record', where: 'record_id = ?', whereArgs: [id]);
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
      int sourceId = 0;
      await database.transaction((txn) async {
        sourceId = await txn.insert('MoneySource', source.toMap());
        if (source.amount > 0) {
          final record = Record(
            moneySourceId: sourceId,
            categoryId: 1, // Uncategorized
            amount: source.amount,
            currency: StorageService().getString(StorageService.keyCurrency) ?? 'VND',
            description: 'Initial Balance',
            type: 'income',
          );
          await txn.insert('Record', record.toMap());
        }
      });
      return sourceId;
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
