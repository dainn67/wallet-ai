// Phase B Integration Tests — suggest-category epic
// Tier 2: Interface-level tests verifying module boundaries work together.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/category.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/models/suggested_category.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

class CategoryFake extends Fake implements Category {}

Record _makeRecord({int categoryId = -1, SuggestedCategory? sc}) => Record(
      recordId: 1,
      amount: 50000,
      description: 'Netflix',
      categoryId: categoryId,
      type: 'expense',
      moneySourceId: 1,
      currency: 'VND',
      suggestedCategory: sc,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRecordRepository mockRepo;
  late RecordProvider provider;

  setUpAll(() {
    // Suppress home_widget MethodChannel calls
    const channel = MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    registerFallbackValue(CategoryFake());
  });

  setUp(() {
    mockRepo = MockRecordRepository();
    // Stub getCategoryTotals (called internally by loadAll)
    when(() => mockRepo.getCategoryTotals()).thenAnswer((_) async => <int, double>{});
    provider = RecordProvider(repository: mockRepo);
  });

  group('[Integration] SuggestedCategory → Record pipeline', () {
    test('IT-01: copyWith (no clear) preserves suggestedCategory', () {
      final sc = SuggestedCategory(
        name: 'Streaming',
        type: 'expense',
        parentId: -1,
        message: 'Create Streaming?',
      );

      final original = _makeRecord(categoryId: -1, sc: sc);
      final updated = original.copyWith(categoryId: 5);

      expect(updated.suggestedCategory, isNotNull);
      expect(updated.suggestedCategory!.name, 'Streaming');
      expect(updated.categoryId, 5);
    });

    test('IT-02: Record.fromMap never produces suggestedCategory (transient only)', () {
      final map = {
        'record_id': 1,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'money_source_id': 1,
        'category_id': -1,
        'amount': 50000.0,
        'currency': 'VND',
        'description': 'Netflix',
        'type': 'expense',
      };

      final record = Record.fromMap(map);
      expect(record.suggestedCategory, isNull,
          reason: 'suggested_category must not be hydrated from DB map');
    });
  });

  group('[Integration] RecordProvider.resolveCategoryByNameOrCreate', () {
    test('IT-03: Returns existing categoryId when name+parentId matches (no createCategory call)',
        () async {
      when(() => mockRepo.getAllCategories()).thenAnswer((_) async => [
            Category(name: 'Streaming', type: 'expense', parentId: -1, categoryId: 12),
          ]);
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => []);
      when(() => mockRepo.getAllMoneySources()).thenAnswer((_) async => []);
      await provider.loadAll();

      final id = await provider.resolveCategoryByNameOrCreate('Streaming', 'expense', -1);

      expect(id, 12);
      verifyNever(() => mockRepo.createCategory(any()));
    });

    test('IT-04: Creates new category and returns its id when name not found', () async {
      when(() => mockRepo.getAllCategories()).thenAnswer((_) async => []);
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => []);
      when(() => mockRepo.getAllMoneySources()).thenAnswer((_) async => []);
      when(() => mockRepo.createCategory(any())).thenAnswer((_) async => 42);
      // loadAll is called after createCategory too
      await provider.loadAll();

      final id = await provider.resolveCategoryByNameOrCreate('NewCat', 'income', -1);

      expect(id, 42);
      verify(() => mockRepo.createCategory(any())).called(1);
    });

    test('IT-05: Falls back to parentId=-1 when given parent does not exist in cache', () async {
      when(() => mockRepo.getAllCategories()).thenAnswer((_) async => []);
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => []);
      when(() => mockRepo.getAllMoneySources()).thenAnswer((_) async => []);
      when(() => mockRepo.createCategory(any())).thenAnswer((_) async => 99);
      await provider.loadAll();

      await provider.resolveCategoryByNameOrCreate('SubCat', 'expense', 999);

      final captured = verify(() => mockRepo.createCategory(captureAny())).captured;
      final created = captured.first as Category;
      expect(created.parentId, -1,
          reason: 'Should fall back to top-level when parent_id not found in cache');
    });

    test('IT-06: Case-insensitive name match reuses existing category', () async {
      when(() => mockRepo.getAllCategories()).thenAnswer((_) async => [
            Category(name: 'streaming', type: 'expense', parentId: -1, categoryId: 7),
          ]);
      when(() => mockRepo.getAllRecords()).thenAnswer((_) async => []);
      when(() => mockRepo.getAllMoneySources()).thenAnswer((_) async => []);
      await provider.loadAll();

      final id = await provider.resolveCategoryByNameOrCreate('STREAMING', 'expense', -1);

      expect(id, 7);
      verifyNever(() => mockRepo.createCategory(any()));
    });
  });

  group('[Integration] Confirm / Cancel state transitions', () {
    test('IT-07: Confirm path produces correct record state', () {
      final sc = SuggestedCategory(
        name: 'Streaming',
        type: 'expense',
        parentId: -1,
        message: 'Create?',
      );

      final original = _makeRecord(categoryId: -1, sc: sc);
      final confirmed = original.copyWith(categoryId: 12, clearSuggestedCategory: true);

      expect(confirmed.categoryId, 12);
      expect(confirmed.suggestedCategory, isNull);
    });

    test('IT-08: Cancel path keeps categoryId=-1 and clears suggestion', () {
      final sc = SuggestedCategory(
        name: 'Streaming',
        type: 'expense',
        parentId: -1,
        message: 'Create?',
      );

      final original = _makeRecord(categoryId: -1, sc: sc);
      final cancelled = original.copyWith(clearSuggestedCategory: true);

      expect(cancelled.categoryId, -1);
      expect(cancelled.suggestedCategory, isNull);
    });
  });
}
