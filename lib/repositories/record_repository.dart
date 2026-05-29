import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/services/record_migration_service.dart';
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

  static const int _dbVersion = 10;

  static Future<void> _onCreate(Database db, int version) async {
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
        occurred_at INTEGER NOT NULL,
        FOREIGN KEY (money_source_id) REFERENCES MoneySource (source_id),
        FOREIGN KEY (target_source_id) REFERENCES MoneySource (source_id),
        FOREIGN KEY (category_id) REFERENCES Category (category_id)
      )
    ''');

    await db.execute('CREATE INDEX idx_record_money_source_id ON Record(money_source_id)');
    await db.execute('CREATE INDEX idx_record_target_source_id ON Record(target_source_id)');
    await db.execute('CREATE INDEX idx_record_category_id ON Record(category_id)');
    await db.execute('CREATE INDEX idx_record_type ON Record(type)');
    await db.execute('CREATE INDEX idx_record_last_updated ON Record(last_updated)');
    await db.execute('CREATE INDEX idx_record_occurred_at ON Record(occurred_at)');

    // Initial Data
    await _seedDatabase(db);
  }

  static Future<void> _seedDatabase(Database db) async {
    // Seed Parent Categories (IDs 1-9) — emoji per AD-5 map
    await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense', 'parent_id': -1, 'emoji': '🏷️'}); // 1
    await db.insert('Category', {'name': 'Food', 'type': 'expense', 'parent_id': -1, 'emoji': '🍔'});           // 2
    await db.insert('Category', {'name': 'Transport', 'type': 'expense', 'parent_id': -1, 'emoji': '🚗'});      // 3
    await db.insert('Category', {'name': 'Entertainment', 'type': 'expense', 'parent_id': -1, 'emoji': '🎬'});  // 4
    await db.insert('Category', {'name': 'Salary', 'type': 'income', 'parent_id': -1, 'emoji': '💰'});          // 5
    await db.insert('Category', {'name': 'Rent', 'type': 'expense', 'parent_id': -1, 'emoji': '🏠'});           // 6
    await db.insert('Category', {'name': 'Health', 'type': 'expense', 'parent_id': -1, 'emoji': '🏥'});         // 7
    await db.insert('Category', {'name': 'Shopping', 'type': 'expense', 'parent_id': -1, 'emoji': '🛍️'});      // 8
    await db.insert('Category', {'name': 'Transfer', 'type': 'transfer', 'parent_id': -1, 'emoji': '🔄'});      // 9

    // Seed Sub-Categories — emoji per AD-5 map
    // Food
    await db.insert('Category', {'name': 'Groceries', 'type': 'expense', 'parent_id': 2, 'emoji': '🛒'});
    await db.insert('Category', {'name': 'Dining Out', 'type': 'expense', 'parent_id': 2, 'emoji': '🍽️'});
    // Transport
    await db.insert('Category', {'name': 'Taxi', 'type': 'expense', 'parent_id': 3, 'emoji': '🚕'});
    await db.insert('Category', {'name': 'Fuel', 'type': 'expense', 'parent_id': 3, 'emoji': '⛽'});
    // Entertainment
    await db.insert('Category', {'name': 'Cinema', 'type': 'expense', 'parent_id': 4, 'emoji': '🎥'});
    await db.insert('Category', {'name': 'Streaming', 'type': 'expense', 'parent_id': 4, 'emoji': '📺'});
    // Shopping
    await db.insert('Category', {'name': 'Clothes', 'type': 'expense', 'parent_id': 8, 'emoji': '👕'});
    await db.insert('Category', {'name': 'Electronics', 'type': 'expense', 'parent_id': 8, 'emoji': '📱'});

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
    } else if (oldVersion < 7) {
      await db.execute('ALTER TABLE Category ADD COLUMN parent_id INTEGER NOT NULL DEFAULT -1');
    }
    if (oldVersion < 8) {
      await RecordMigrationService.addOccurredAtColumn(db);
    }
    if (oldVersion < 9) {
      await RecordMigrationService.addTargetSourceIdColumn(db);
      // Seed the Transfer category (idempotent: skip if a row with this name+type already exists)
      final existing = await db.rawQuery(
        "SELECT category_id FROM Category WHERE name = 'Transfer' AND type = 'transfer' LIMIT 1",
      );
      if (existing.isEmpty) {
        await db.insert('Category', {'name': 'Transfer', 'type': 'transfer', 'parent_id': -1});
      }
    }
    if (oldVersion < 10) {
      await RecordMigrationService.addEmojiColumn(db);
    }
  }

  Future<void> _adjustMoneySourceAmount(DatabaseExecutor txn, {required int sourceId, required double delta}) async {
    await txn.rawUpdate(
      'UPDATE MoneySource SET amount = amount + ? WHERE source_id = ?',
      [delta, sourceId],
    );
  }

  /// Applies `record`'s effect on money source balance(s).
  /// Pass `reverse: true` to undo it (used by update/delete).
  Future<void> _applyRecordImpact(
    DatabaseExecutor txn,
    Record record, {
    bool reverse = false,
  }) async {
    final sign = reverse ? -1 : 1;
    switch (record.type) {
      case 'income':
        await _adjustMoneySourceAmount(txn, sourceId: record.moneySourceId, delta: sign * record.amount);
        break;
      case 'expense':
        await _adjustMoneySourceAmount(txn, sourceId: record.moneySourceId, delta: -sign * record.amount);
        break;
      case 'transfer':
        // Debit source, credit target. Reverse flips both.
        await _adjustMoneySourceAmount(txn, sourceId: record.moneySourceId, delta: -sign * record.amount);
        if (record.targetSourceId != null) {
          await _adjustMoneySourceAmount(txn, sourceId: record.targetSourceId!, delta: sign * record.amount);
        }
        break;
    }
  }

  Future<int> createRecord(Record record) async {
    try {
      int insertedId = 0;
      await database.transaction((txn) async {
        insertedId = await txn.insert('Record', record.toMap());
        print("Log: Created record $insertedId (type=${record.type})");
        await _applyRecordImpact(txn, record);
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
        SELECT r.*,
               COALESCE(p.name || ' - ' || c.name, c.name) as category_name,
               ms.source_name,
               tms.source_name as target_source_name
        FROM Record r
        LEFT JOIN Category c ON r.category_id = c.category_id
        LEFT JOIN Category p ON c.parent_id = p.category_id
        LEFT JOIN MoneySource ms ON r.money_source_id = ms.source_id
        LEFT JOIN MoneySource tms ON r.target_source_id = tms.source_id
        ORDER BY r.occurred_at DESC
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
        SELECT r.*,
               COALESCE(p.name || ' - ' || c.name, c.name) as category_name,
               ms.source_name,
               tms.source_name as target_source_name
        FROM Record r
        LEFT JOIN Category c ON r.category_id = c.category_id
        LEFT JOIN Category p ON c.parent_id = p.category_id
        LEFT JOIN MoneySource ms ON r.money_source_id = ms.source_id
        LEFT JOIN MoneySource tms ON r.target_source_id = tms.source_id
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
          SELECT r.*, 
                 COALESCE(p.name || ' - ' || c.name, c.name) as category_name, 
                 ms.source_name
          FROM Record r
          LEFT JOIN Category c ON r.category_id = c.category_id
          LEFT JOIN Category p ON c.parent_id = p.category_id
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

        // 1. Reverse the old impact (handles income/expense/transfer).
        await _applyRecordImpact(txn, existing, reverse: true);
        // 2. Apply the new impact.
        await _applyRecordImpact(txn, record);
        // 3. Update the record data.
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
          SELECT r.*, 
                 COALESCE(p.name || ' - ' || c.name, c.name) as category_name, 
                 ms.source_name
          FROM Record r
          LEFT JOIN Category c ON r.category_id = c.category_id
          LEFT JOIN Category p ON c.parent_id = p.category_id
          LEFT JOIN MoneySource ms ON r.money_source_id = ms.source_id
          WHERE r.record_id = ?
          LIMIT 1
        ''', [id]);

        if (maps.isEmpty) return;

        final existing = Record.fromMap(maps.first);
        // Reverse the impact (income/expense/transfer) before removing the row.
        await _applyRecordImpact(txn, existing, reverse: true);
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
            currency: StorageService().getString(StorageService.keyCurrency) ?? 'USD',
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
      return await database.transaction((txn) async {
        // 1. Delete associated records
        await txn.delete('Record', where: 'money_source_id = ?', whereArgs: [id]);
        // 2. Delete the source
        return await txn.delete('MoneySource', where: 'source_id = ?', whereArgs: [id]);
      });
    } catch (e) {
      print("Error deleting money source: $e");
      rethrow;
    }
  }

  Future<void> resetAllData() async {
    try {
      await database.transaction((txn) async {
        await txn.delete('Record');
        await txn.rawUpdate('UPDATE MoneySource SET amount = 0');
      });
    } catch (e) {
      print("Error resetting all data: $e");
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

  Future<int> createCategory(Category category) async {
    try {
      return await database.insert('Category', category.toMap());
    } catch (e) {
      print("Error creating category: $e");
      rethrow;
    }
  }

  Future<int> updateCategory(Category category) async {
    try {
      if (category.categoryId == 1) {
        throw ArgumentError("Cannot update Uncategorized category");
      }
      return await database.update(
        'Category',
        category.toMap(),
        where: 'category_id = ?',
        whereArgs: [category.categoryId],
      );
    } catch (e) {
      print("Error updating category: $e");
      rethrow;
    }
  }

  /// Updates [category] and, when its `parent_id` is changing to a non-root
  /// value (i.e., it's becoming a sub of someone), moves any current children
  /// of [category] to share the same new parent so the hierarchy stays flat
  /// (single-level). All writes happen in one transaction.
  Future<void> updateCategoryAndReparent({
    required Category category,
    required int oldParentId,
  }) async {
    if (category.categoryId == 1) {
      throw ArgumentError("Cannot update Uncategorized category");
    }
    if (category.categoryId == category.parentId) {
      throw ArgumentError("Category cannot be its own parent");
    }
    await database.transaction((txn) async {
      final newParentId = category.parentId;
      if (newParentId != oldParentId && newParentId != -1) {
        await txn.update(
          'Category',
          {'parent_id': newParentId},
          where: 'parent_id = ?',
          whereArgs: [category.categoryId],
        );
      }
      await txn.update(
        'Category',
        category.toMap(),
        where: 'category_id = ?',
        whereArgs: [category.categoryId],
      );
    });
  }

  Future<int> deleteCategory(int id) async {
    try {
      if (id == 1) {
        throw ArgumentError("Cannot delete Uncategorized category");
      }
      return await database.transaction((txn) async {
        // Step 1: Update Record SET category_id = 1 WHERE category_id = ?
        await txn.update(
          'Record',
          {'category_id': 1},
          where: 'category_id = ?',
          whereArgs: [id],
        );
        // Step 2: DELETE FROM Category WHERE category_id = ?
        return await txn.delete(
          'Category',
          where: 'category_id = ?',
          whereArgs: [id],
        );
      });
    } catch (e) {
      print("Error deleting category: $e");
      rethrow;
    }
  }

  Future<int> getRecordCountByCategoryId(int id) async {
    try {
      final results = await database.rawQuery(
        'SELECT COUNT(*) as count FROM Record WHERE category_id = ?',
        [id],
      );
      return results.first['count'] as int;
    } catch (e) {
      print("Error getting record count by category: $e");
      rethrow;
    }
  }

  Future<Map<int, double>> getCategoryTotals({DateTime? start, DateTime? end}) async {
    try {
      String query = 'SELECT category_id, SUM(amount) as total FROM Record';
      List<dynamic> args = [];
      
      if (start != null && end != null) {
        query += ' WHERE occurred_at >= ? AND occurred_at <= ?';
        args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
      }
      
      query += ' GROUP BY category_id';
      
      final List<Map<String, dynamic>> results = await database.rawQuery(query, args);

      final Map<int, double> totals = {};
      for (var row in results) {
        final id = row['category_id'] as int;
        final total = (row['total'] as num).toDouble();
        totals[id] = total;
      }
      return totals;
    } catch (e) {
      print("Error getting category totals: $e");
      rethrow;
    }
  }
}
