import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/ai_context_service.dart';
import 'package:wallet_ai/services/storage_service.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

Record makeRecord({
  int recordId = 1,
  int? lastUpdated,
  int moneySourceId = 1,
  int categoryId = 2,
  String? categoryName = 'Food - Dining Out',
  String? sourceName = 'Wallet',
  double amount = 50000,
  String currency = 'VND',
  String description = 'Test record',
  String type = 'expense',
}) {
  return Record(
    recordId: recordId,
    lastUpdated: lastUpdated ?? DateTime.now().millisecondsSinceEpoch,
    moneySourceId: moneySourceId,
    categoryId: categoryId,
    categoryName: categoryName,
    sourceName: sourceName,
    amount: amount,
    currency: currency,
    description: description,
    type: type,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRecordRepository mockRepo;

  setUp(() async {
    mockRepo = MockRecordRepository();
    RecordRepository.setMockInstance(mockRepo);
    SharedPreferences.setMockInitialValues({
      'user_language': 'vi',
      StorageService.keyCurrency: 'VND',
    });
    await StorageService.init();
  });

  tearDown(() {
    RecordRepository.setMockInstance(null);
    AiContextService.setMockInstance(null);
  });

  group('Group 1: Singleton (FR-1)', () {
    test('AiContextService() returns the same instance', () {
      final a = AiContextService();
      final b = AiContextService();
      expect(identical(a, b), isTrue);
    });

    test('setMockInstance overrides the singleton', () {
      final mockService = AiContextService();
      AiContextService.setMockInstance(mockService);
      expect(identical(AiContextService(), mockService), isTrue);
      AiContextService.setMockInstance(null);
    });
  });

  group('Group 2: Category name extraction (FR-2)', () {
    test('extracts sub-category, parent-only, and null correctly', () async {
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => [
            makeRecord(recordId: 1, categoryName: 'Food - Dining Out'),
            makeRecord(recordId: 2, categoryName: 'Transport'),
            makeRecord(recordId: 3, categoryName: null),
          ]);

      final snapshot = await AiContextService().getAiContext();
      final records = snapshot['records'] as List;

      expect(records[0]['category'], 'Dining Out');
      expect(records[1]['category'], 'Transport');
      expect(records[2]['category'], 'Uncategorized');
    });
  });

  group('Group 3: Time-of-day bucketing (FR-3)', () {
    test('assigns correct time-of-day bucket at all 8 boundaries', () async {
      // Use a fixed date to avoid ambiguity. The service uses local time, so we
      // use DateTime(...) which produces local time millis.
      final boundaries = [
        (DateTime(2026, 4, 1, 4, 59), 'Night'),
        (DateTime(2026, 4, 1, 5, 0), 'Morning'),
        (DateTime(2026, 4, 1, 10, 59), 'Morning'),
        (DateTime(2026, 4, 1, 11, 0), 'Afternoon'),
        (DateTime(2026, 4, 1, 16, 59), 'Afternoon'),
        (DateTime(2026, 4, 1, 17, 0), 'Evening'),
        (DateTime(2026, 4, 1, 21, 59), 'Evening'),
        (DateTime(2026, 4, 1, 22, 0), 'Night'),
      ];

      final records = boundaries.asMap().entries.map((e) {
        return makeRecord(
          recordId: e.key + 1,
          lastUpdated: e.value.$1.millisecondsSinceEpoch,
        );
      }).toList();

      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => records);

      final snapshot = await AiContextService().getAiContext(isInitial: true);
      final snapshotRecords = snapshot['records'] as List;

      for (int i = 0; i < boundaries.length; i++) {
        expect(
          snapshotRecords[i]['time_of_day'],
          boundaries[i].$2,
          reason: 'Record $i at ${boundaries[i].$1.hour}:${boundaries[i].$1.minute} '
              'should be ${boundaries[i].$2}',
        );
      }
    });
  });

  group('Group 4: Initial 90-day window (FR-4)', () {
    test('includes records at 89d and 90d ago, excludes 91d ago; period_days=90', () async {
      final now = DateTime.now();
      final r89 = makeRecord(
        recordId: 1,
        lastUpdated: now.subtract(const Duration(days: 89)).millisecondsSinceEpoch,
        description: '89 days ago',
      );
      final r90 = makeRecord(
        recordId: 2,
        lastUpdated: now.subtract(const Duration(days: 90)).millisecondsSinceEpoch,
        description: '90 days ago',
      );
      final r91 = makeRecord(
        recordId: 3,
        lastUpdated: now.subtract(const Duration(days: 91)).millisecondsSinceEpoch,
        description: '91 days ago',
      );

      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => [r89, r90, r91]);

      final snapshot = await AiContextService().getAiContext(isInitial: true);
      final records = snapshot['records'] as List;
      final descriptions = records.map((r) => r['description'] as String).toSet();

      expect(descriptions.contains('89 days ago'), isTrue);
      expect(descriptions.contains('90 days ago'), isTrue);
      expect(descriptions.contains('91 days ago'), isFalse);
      expect((snapshot['summary'] as Map)['period_days'], 90);
    });
  });

  group('Group 5: Daily 24h + 30d summary (FR-5)', () {
    test('only 12h record in records; summary includes 12h and 5d records; period_days=30', () async {
      final now = DateTime.now();
      final r12h = makeRecord(
        recordId: 1,
        lastUpdated: now.subtract(const Duration(hours: 12)).millisecondsSinceEpoch,
        amount: 10000,
        description: '12h ago',
      );
      final r25h = makeRecord(
        recordId: 2,
        lastUpdated: now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch,
        amount: 20000,
        description: '25h ago',
      );
      final r5d = makeRecord(
        recordId: 3,
        lastUpdated: now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
        amount: 30000,
        description: '5d ago',
      );

      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => [r12h, r25h, r5d]);

      final snapshot = await AiContextService().getAiContext(isInitial: false);
      final records = snapshot['records'] as List;
      final summary = snapshot['summary'] as Map;

      // Only 12h record in records window
      expect(records.length, 1);
      expect(records[0]['description'], '12h ago');

      // Summary covers 30d: 12h + 5d records included (25h is outside 30d? No — 25h < 30d)
      // All 3 are within 30 days. The 25h record is within the 30d summary window.
      expect(summary['period_days'], 30);
      expect(summary['total_expense'], 60000.0); // 10k + 20k + 30k
    });

    test('empty window returns empty records and zero totals', () async {
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => []);

      for (final isInitial in [false, true]) {
        final snapshot = await AiContextService().getAiContext(isInitial: isInitial);
        final records = snapshot['records'] as List;
        final summary = snapshot['summary'] as Map;

        expect(records, isEmpty);
        expect(summary['total_income'], 0.0);
        expect(summary['total_expense'], 0.0);
      }
    });
  });

  group('Group 6: Empty dataset (FR-5 edge)', () {
    test('no records in window — records is empty, totals = 0', () async {
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => []);

      final snapshot = await AiContextService().getAiContext();
      final records = snapshot['records'] as List;
      final summary = snapshot['summary'] as Map;

      expect(records, isEmpty);
      expect(summary['total_income'], 0.0);
      expect(summary['total_expense'], 0.0);
    });
  });

  group('Group 7: Summary aggregation (FR-6)', () {
    test('by_category/by_money_source/by_time_of_day count expense only; totals correct', () async {
      final now = DateTime.now();
      // Use a fixed morning hour so time_of_day is deterministic
      final morningMillis = DateTime(now.year, now.month, now.day, 8, 0).millisecondsSinceEpoch;

      final records = [
        // expense: Food - Dining Out / 50k / Wallet
        makeRecord(
          recordId: 1,
          lastUpdated: morningMillis,
          categoryName: 'Food - Dining Out',
          sourceName: 'Wallet',
          amount: 50000,
          type: 'expense',
        ),
        // expense: Transport / 20k / Wallet
        makeRecord(
          recordId: 2,
          lastUpdated: morningMillis,
          categoryName: 'Transport',
          sourceName: 'Wallet',
          amount: 20000,
          type: 'expense',
        ),
        // income: Salary / 500k
        makeRecord(
          recordId: 3,
          lastUpdated: morningMillis,
          categoryName: 'Salary',
          sourceName: 'Bank',
          amount: 500000,
          type: 'income',
        ),
        // expense: Food - Dining Out / 30k / Bank (different source)
        makeRecord(
          recordId: 4,
          lastUpdated: morningMillis,
          categoryName: 'Food - Dining Out',
          sourceName: 'Bank',
          amount: 30000,
          type: 'expense',
        ),
      ];

      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => records);

      final snapshot = await AiContextService().getAiContext(isInitial: true);
      final summary = snapshot['summary'] as Map;

      expect(summary['total_income'], 500000.0);
      expect(summary['total_expense'], 100000.0); // 50k + 20k + 30k

      final byCategory = summary['by_category'] as Map;
      expect(byCategory['Dining Out'], 80000.0); // 50k + 30k expense only
      expect(byCategory['Transport'], 20000.0);
      expect(byCategory.containsKey('Salary'), isFalse); // income excluded

      final byMoneySource = summary['by_money_source'] as Map;
      expect(byMoneySource['Wallet'], 70000.0); // 50k + 20k expense
      expect(byMoneySource['Bank'], 30000.0);   // 30k expense only (not the 500k income)

      final byTimeOfDay = summary['by_time_of_day'] as Map;
      expect(byTimeOfDay['Morning'], 100000.0); // sum of expense at 08:00
      expect(byTimeOfDay.containsKey('Night'), isFalse);
    });
  });

  group('Group 8: Client metadata (FR-7)', () {
    test('sync_type is "daily" for default and "initial" for isInitial=true', () async {
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => []);

      final daily = await AiContextService().getAiContext(isInitial: false);
      final initial = await AiContextService().getAiContext(isInitial: true);

      expect((daily['client_metadata'] as Map)['sync_type'], 'daily');
      expect((initial['client_metadata'] as Map)['sync_type'], 'initial');
    });

    test('metadata contains current_time, timezone, language, currency', () async {
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => []);

      final snapshot = await AiContextService().getAiContext();
      final meta = snapshot['client_metadata'] as Map;

      expect(meta['current_time'], isA<String>());
      expect((meta['current_time'] as String).isNotEmpty, isTrue);
      expect(meta['timezone'], isA<String>());
      expect(meta['language'], 'vi');
      expect(meta['currency'], 'VND');
    });
  });

  group('Group 9: jsonEncode validation', () {
    test('getAiContext output passes jsonEncode without error', () async {
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => [
            makeRecord(),
            makeRecord(recordId: 2, type: 'income', sourceName: null),
          ]);

      final snapshot = await AiContextService().getAiContext();
      expect(() => jsonEncode(snapshot), returnsNormally);
    });

    test('getAiContext(isInitial: true) output passes jsonEncode without error', () async {
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => [makeRecord()]);

      final snapshot = await AiContextService().getAiContext(isInitial: true);
      expect(() => jsonEncode(snapshot), returnsNormally);
    });
  });
}
