// Integration tests — RecordProvider.getRecordsForCategory
// Covers: FR-1 (union filter), FR-4 (occurredAt sort), Gap #2 from Phase A
// Tests the parent-union risk identified in PRD risk table: "parent-union query
// returns wrong records" with 0, 1, and multiple subs.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/models/models.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

class _RecordFake extends Fake implements Record {}
class _MoneySourceFake extends Fake implements MoneySource {}
class _CategoryFake extends Fake implements Category {}

int _ms(int year, int month, int day, [int hour = 12]) =>
    DateTime(year, month, day, hour).millisecondsSinceEpoch;

final _march2026 = DateTimeRange(
  start: DateTime(2026, 3, 1),
  end: DateTime(2026, 3, 31, 23, 59, 59),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const homeWidgetChannel = MethodChannel('home_widget');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (_) async => null);
    registerFallbackValue(_RecordFake());
    registerFallbackValue(_MoneySourceFake());
    registerFallbackValue(_CategoryFake());
  });

  late RecordProvider provider;
  late MockRecordRepository repo;

  setUp(() {
    repo = MockRecordRepository();
    when(() => repo.getCategoryTotals()).thenAnswer((_) async => <int, double>{});
    provider = RecordProvider(repository: repo);
  });

  // ── Records used across tests ──
  final recordParentCat10 = Record(
    recordId: 1, moneySourceId: 1, categoryId: 10,
    amount: 200000, currency: 'VND', description: 'Parent direct',
    type: 'expense', occurredAt: _ms(2026, 3, 15),
  );
  final recordSub11 = Record(
    recordId: 2, moneySourceId: 1, categoryId: 11,
    amount: 150000, currency: 'VND', description: 'Groceries',
    type: 'expense', occurredAt: _ms(2026, 3, 20),
  );
  final recordSub12 = Record(
    recordId: 3, moneySourceId: 1, categoryId: 12,
    amount: 80000, currency: 'VND', description: 'Dining',
    type: 'expense', occurredAt: _ms(2026, 3, 10),
  );
  final recordOtherCat20 = Record(
    recordId: 4, moneySourceId: 1, categoryId: 20,
    amount: 500000, currency: 'VND', description: 'Salary',
    type: 'income', occurredAt: _ms(2026, 3, 1),
  );
  final recordOldDate = Record(
    recordId: 5, moneySourceId: 1, categoryId: 10,
    amount: 100000, currency: 'VND', description: 'February record',
    type: 'expense', occurredAt: _ms(2026, 2, 28),
  );

  // Seed private _records via loadAll mock
  Future<void> seedRecords(RecordProvider p, List<Record> records) async {
    when(() => repo.getAllRecords()).thenAnswer((_) async => records);
    when(() => repo.getAllMoneySources()).thenAnswer((_) async => []);
    when(() => repo.getAllCategories()).thenAnswer((_) async => []);
    await p.loadAll();
  }

  group('getRecordsForCategory — scoping', () {
    test('P1: parent with no subs — returns only parent-direct records', () async {
      await seedRecords(provider, [recordParentCat10, recordOtherCat20]);

      final result = provider.getRecordsForCategory([10], _march2026);

      expect(result, hasLength(1));
      expect(result.first.recordId, 1);
    });

    test('P2: parent with 1 sub — returns parent-direct + sub records', () async {
      await seedRecords(provider, [recordParentCat10, recordSub11, recordOtherCat20]);

      final result = provider.getRecordsForCategory([10, 11], _march2026);

      expect(result, hasLength(2));
      expect(result.map((r) => r.recordId), containsAll([1, 2]));
    });

    test('P3: parent with multiple subs — returns union of parent + all subs', () async {
      await seedRecords(provider, [
        recordParentCat10, recordSub11, recordSub12, recordOtherCat20,
      ]);

      final result = provider.getRecordsForCategory([10, 11, 12], _march2026);

      expect(result, hasLength(3));
      expect(result.map((r) => r.recordId), containsAll([1, 2, 3]));
    });

    test('P4: other-category records excluded from union result', () async {
      await seedRecords(provider, [
        recordParentCat10, recordSub11, recordOtherCat20,
      ]);

      final result = provider.getRecordsForCategory([10, 11], _march2026);

      final ids = result.map((r) => r.recordId).toList();
      expect(ids, isNot(contains(4))); // recordOtherCat20 excluded
    });

    test('P5: sub-tap — scoped to single sub only, no parent-direct records', () async {
      await seedRecords(provider, [recordParentCat10, recordSub11, recordSub12]);

      final result = provider.getRecordsForCategory([11], _march2026);

      expect(result, hasLength(1));
      expect(result.first.recordId, 2);
    });
  });

  group('getRecordsForCategory — date range filtering', () {
    test('R1: records outside the range are excluded', () async {
      await seedRecords(provider, [recordParentCat10, recordOldDate]);

      final result = provider.getRecordsForCategory([10], _march2026);

      // recordParentCat10 is in March, recordOldDate is February
      expect(result, hasLength(1));
      expect(result.first.recordId, 1);
    });

    test('R2: null range returns all records for the categoryIds (no date filter)', () async {
      await seedRecords(provider, [recordParentCat10, recordOldDate]);
      // Override selectedDateRange: provider.selectedDateRange is set on init;
      // pass null explicitly to bypass it
      final result = provider.getRecordsForCategory([10], null);

      // Both recordParentCat10 (March) and recordOldDate (Feb) are in cat 10
      expect(result, hasLength(2));
    });
  });

  group('getRecordsForCategory — sort order (FR-4)', () {
    test('Sort1: records returned in occurredAt DESC order', () async {
      await seedRecords(provider, [
        recordParentCat10, // March 15
        recordSub11,       // March 20 (newest)
        recordSub12,       // March 10 (oldest)
      ]);

      final result = provider.getRecordsForCategory([10, 11, 12], _march2026);

      expect(result.length, 3);
      // Newest first: Mar 20 → Mar 15 → Mar 10
      expect(result[0].recordId, 2); // March 20
      expect(result[1].recordId, 1); // March 15
      expect(result[2].recordId, 3); // March 10
    });
  });

  group('filteredRecords sort order (FR-4 — Records tab)', () {
    test('Sort2: filteredRecords sorted occurredAt DESC', () async {
      await seedRecords(provider, [
        recordSub12,       // March 10 (older recordId=3, but earlier date)
        recordParentCat10, // March 15 (recordId=1)
        recordSub11,       // March 20 (newest)
      ]);
      provider.selectedDateRange = _march2026;

      final filtered = provider.filteredRecords;

      // Verify descending occurredAt regardless of recordId order
      for (int i = 0; i < filtered.length - 1; i++) {
        expect(
          filtered[i].occurredAt,
          greaterThanOrEqualTo(filtered[i + 1].occurredAt),
          reason: 'filteredRecords[$i].occurredAt should be >= [${i + 1}]',
        );
      }
    });

    test('Sort3: editing a record (no occurredAt change) does not change sort position', () async {
      // recordParentCat10 is March 15, recordSub11 is March 20
      await seedRecords(provider, [recordParentCat10, recordSub11]);
      provider.selectedDateRange = _march2026;

      final before = provider.filteredRecords.map((r) => r.recordId).toList();

      // Simulate edit: update description only — occurredAt unchanged
      when(() => repo.updateRecord(any())).thenAnswer((_) async => 1);
      final edited = Record(
        recordId: recordParentCat10.recordId,
        moneySourceId: recordParentCat10.moneySourceId,
        categoryId: recordParentCat10.categoryId,
        amount: recordParentCat10.amount,
        currency: recordParentCat10.currency,
        description: 'Edited description',
        type: recordParentCat10.type,
        occurredAt: recordParentCat10.occurredAt, // unchanged
      );
      await provider.updateRecord(edited);

      final after = provider.filteredRecords.map((r) => r.recordId).toList();
      expect(after, equals(before), reason: 'Position should not change when occurredAt is not edited');
    });
  });
}
