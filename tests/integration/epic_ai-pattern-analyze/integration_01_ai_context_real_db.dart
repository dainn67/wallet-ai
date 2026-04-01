// Integration Test 01: AiContextService with real RecordRepository
// Tests the full data pipeline from SQLite records → snapshot using in-memory DB.
// Verifies category name JOIN format matches _extractCategoryName() logic.
// Uses sqflite_common_ffi for in-memory database — no mocking of repository.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/ai_context_service.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Open in-memory DB and inject via setMockDatabase
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 7,
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
            type TEXT NOT NULL CHECK(type IN ('income','expense')),
            last_updated INTEGER NOT NULL
          )
        ''');

        // Seed categories: parent + sub
        await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense', 'parent_id': -1}); // 1
        await db.insert('Category', {'name': 'Food', 'type': 'expense', 'parent_id': -1});           // 2
        await db.insert('Category', {'name': 'Transport', 'type': 'expense', 'parent_id': -1});      // 3
        await db.insert('Category', {'name': 'Salary', 'type': 'income', 'parent_id': -1});          // 4
        await db.insert('Category', {'name': 'Dining Out', 'type': 'expense', 'parent_id': 2});      // 5
        await db.insert('Category', {'name': 'Taxi', 'type': 'expense', 'parent_id': 3});            // 6

        // Seed money sources
        await db.insert('MoneySource', {'source_name': 'Wallet', 'amount': 0}); // 1
        await db.insert('MoneySource', {'source_name': 'Bank', 'amount': 0});   // 2
      },
    );

    RecordRepository.setMockDatabase(db);

    SharedPreferences.setMockInitialValues({
      'user_language': 'vi',
      'user_currency': 'VND',
    });
    await StorageService.init();
  });

  tearDown(() {
    RecordRepository.setMockInstance(null);
  });

  group('Integration: Real DB → buildSnapshot() (FR-2, FR-6)', () {
    test('sub-category name extracted correctly from JOIN', () async {
      // Insert record with sub-category "Dining Out" (parent: Food)
      final repo = RecordRepository();
      await repo.database.insert('Record', {
        'money_source_id': 1,
        'category_id': 5, // Dining Out (parent: Food)
        'amount': 45000,
        'currency': 'VND',
        'description': 'Phở bò',
        'type': 'expense',
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });

      final snapshot = await AiContextService().buildSnapshot();
      final records = snapshot['records'] as List;

      expect(records, hasLength(1));
      expect(records[0]['category'], equals('Dining Out'),
          reason: 'Sub-category name should be "Dining Out", not "Food - Dining Out"');
      expect(records[0]['money_source'], equals('Wallet'));
      expect(records[0]['description'], equals('Phở bò'));
      expect(records[0]['type'], equals('expense'));
    });

    test('parent-only category name used directly', () async {
      final repo = RecordRepository();
      await repo.database.insert('Record', {
        'money_source_id': 1,
        'category_id': 3, // Transport (parent category, no sub)
        'amount': 35000,
        'currency': 'VND',
        'description': 'Grab ride',
        'type': 'expense',
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });

      final snapshot = await AiContextService().buildSnapshot();
      final records = snapshot['records'] as List;

      expect(records.first['category'], equals('Transport'),
          reason: 'Parent category should use its own name');
    });

    test('income record appears in total_income but not in by_category (FR-6)', () async {
      final repo = RecordRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      // Add expense
      await repo.database.insert('Record', {
        'money_source_id': 1, 'category_id': 5, 'amount': 50000,
        'currency': 'VND', 'description': 'Lunch', 'type': 'expense', 'last_updated': now,
      });
      // Add income
      await repo.database.insert('Record', {
        'money_source_id': 2, 'category_id': 4, 'amount': 15000000,
        'currency': 'VND', 'description': 'Salary', 'type': 'income', 'last_updated': now,
      });

      final snapshot = await AiContextService().buildSnapshot();
      final summary = snapshot['summary'] as Map<String, dynamic>;

      expect(summary['total_expense'], equals(50000));
      expect(summary['total_income'], equals(15000000));

      final byCategory = summary['by_category'] as Map<String, dynamic>;
      expect(byCategory.containsKey('Salary'), isFalse,
          reason: 'Income category should NOT appear in by_category');
      expect(byCategory.containsKey('Dining Out'), isTrue);
    });

    test('snapshot is valid JSON (NFR-3)', () async {
      final repo = RecordRepository();
      await repo.database.insert('Record', {
        'money_source_id': 1, 'category_id': 5, 'amount': 45000,
        'currency': 'VND', 'description': 'Coffee', 'type': 'expense',
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });

      final snapshot = await AiContextService().buildSnapshot();
      expect(() => jsonEncode(snapshot), returnsNormally,
          reason: 'Snapshot with real DB data must be JSON-serializable');
    });
  });

  group('Integration: Date window filtering (FR-4, FR-5)', () {
    test('initial snapshot excludes records older than 90 days', () async {
      final repo = RecordRepository();
      final now = DateTime.now();
      final withinWindow = now.subtract(const Duration(days: 89)).millisecondsSinceEpoch;
      final outsideWindow = now.subtract(const Duration(days: 91)).millisecondsSinceEpoch;

      await repo.database.insert('Record', {
        'money_source_id': 1, 'category_id': 5, 'amount': 10000,
        'currency': 'VND', 'description': 'Recent', 'type': 'expense',
        'last_updated': withinWindow,
      });
      await repo.database.insert('Record', {
        'money_source_id': 1, 'category_id': 5, 'amount': 99999,
        'currency': 'VND', 'description': 'Old record', 'type': 'expense',
        'last_updated': outsideWindow,
      });

      final snapshot = await AiContextService().buildSnapshot(isInitial: true);
      final records = snapshot['records'] as List;

      expect(records, hasLength(1));
      expect(records[0]['description'], equals('Recent'));
      expect(records[0]['description'], isNot('Old record'));
    });

    test('daily snapshot only includes records from last 24 hours', () async {
      final repo = RecordRepository();
      final now = DateTime.now();
      final within24h = now.subtract(const Duration(hours: 12)).millisecondsSinceEpoch;
      final beyond24h = now.subtract(const Duration(hours: 36)).millisecondsSinceEpoch;

      await repo.database.insert('Record', {
        'money_source_id': 1, 'category_id': 5, 'amount': 45000,
        'currency': 'VND', 'description': 'Today', 'type': 'expense',
        'last_updated': within24h,
      });
      await repo.database.insert('Record', {
        'money_source_id': 1, 'category_id': 3, 'amount': 20000,
        'currency': 'VND', 'description': 'Yesterday', 'type': 'expense',
        'last_updated': beyond24h,
      });

      final snapshot = await AiContextService().buildSnapshot();
      final records = snapshot['records'] as List;

      expect(records, hasLength(1));
      expect(records[0]['description'], equals('Today'));

      // Summary still covers 30 days — both records counted
      final summary = snapshot['summary'] as Map<String, dynamic>;
      expect(summary['total_expense'], equals(65000),
          reason: 'Summary covers 30 days — both records should be counted');
    });
  });

  group('Integration: Client metadata (FR-7)', () {
    test('language and currency come from StorageService', () async {
      final snapshot = await AiContextService().buildSnapshot();
      final meta = snapshot['client_metadata'] as Map<String, dynamic>;

      expect(meta['language'], equals('vi'));
      expect(meta['currency'], equals('VND'));
    });
  });
}
