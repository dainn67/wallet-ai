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

  static const int _dbVersion = 2;

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE MoneySource (
        source_id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_name TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0
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

    // Initial Data
    await db.insert('MoneySource', {'source_name': 'Wallet', 'total': 0});
    await db.insert('MoneySource', {'source_name': 'Bank', 'total': 0});
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE MoneySource ADD COLUMN total REAL NOT NULL DEFAULT 0');
    }
  }

  // Record Management
  Future<int> createRecord(Record record) async {
    try {
      return await database.insert('record', record.toMap());
    } catch (e) {
      print("Error creating record: $e");
      rethrow;
    }
  }

  Future<List<Record>> getAllRecords() async {
    try {
      final List<Map<String, dynamic>> maps = await database.query('record');
      return List.generate(maps.length, (i) => Record.fromMap(maps[i]));
    } catch (e) {
      print("Error fetching records: $e");
      rethrow;
    }
  }

  Future<int> updateRecord(Record record) async {
    try {
      if (record.recordId == null) throw Exception("Record ID cannot be null for update");
      return await database.update('record', record.toMap(), where: 'record_id = ?', whereArgs: [record.recordId]);
    } catch (e) {
      print("Error updating record: $e");
      rethrow;
    }
  }

  Future<int> deleteRecord(int id) async {
    try {
      return await database.delete('record', where: 'record_id = ?', whereArgs: [id]);
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

  Future<int> deleteMoneySource(int id) async {
    try {
      return await database.delete('MoneySource', where: 'source_id = ?', whereArgs: [id]);
    } catch (e) {
      print("Error deleting money source: $e");
      rethrow;
    }
  }
}
