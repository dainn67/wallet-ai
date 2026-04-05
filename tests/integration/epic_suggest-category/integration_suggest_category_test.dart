// Phase B Integration Tests — suggest-category epic
// Tier 2: Interface-level tests verifying module boundaries work together.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/category.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/models/suggested_category.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  late MockRecordRepository mockRepo;
  late RecordProvider provider;

  setUp(() {
    mockRepo = MockRecordRepository();
    provider = RecordProvider(mockRepo);

    registerFallbackValue(
      Category(name: 'fallback', type: 'expense', parentId: -1),
    );
  });

  group('[Integration] SuggestedCategory → Record pipeline', () {
    test('IT-01: Record built with suggestedCategory retains field through copyWith (no clear)', () {
      final sc = SuggestedCategory(
        name: 'Streaming',
        type: 'expense',
        parentId: -1,
        message: 'Create Streaming?',
      );

      final original = Record(
        recordId: 1,
        amount: 50000,
        description: 'Netflix',
        categoryId: -1,
        type: 'expense',
        date: DateTime.now(),
        sourceId: 's1',
        suggestedCategory: sc,
      );

      // copyWith without clearSuggestedCategory should preserve the field
      final updated = original.copyWith(categoryId: 5);
      expect(updated.suggestedCategory, isNotNull);
      expect(updated.suggestedCategory!.name, 'Streaming');
      expect(updated.categoryId, 5);
    });

    test('IT-02: Record.fromMap never produces suggestedCategory (transient only)', () {
      final map = {
        'recordId': 1,
        'amount': 50000.0,
        'description': 'Netflix',
        'categoryId': -1,
        'type': 'expense',
        'date': '2026-04-05',
        'sourceId': 's1',
        'suggested_category': {'name': 'Streaming', 'type': 'expense', 'parent_id': -1, 'message': 'Create?'},
      };

      final record = Record.fromMap(map);
      expect(record.suggestedCategory, isNull,
          reason: 'suggested_category must not be persisted or hydrated from DB');
    });
  });

  group('[Integration] RecordProvider.resolveCategoryByNameOrCreate', () {
    test('IT-03: Returns existing categoryId when name+parentId matches (no DB call)', () async {
      // Seed provider with an existing category
      when(() => mockRepo.getCategories()).thenAnswer((_) async => [
            Category(name: 'Streaming', type: 'expense', parentId: -1, categoryId: 12),
          ]);
      when(() => mockRepo.getRecords()).thenAnswer((_) async => []);
      when(() => mockRepo.getSubCategories()).thenAnswer((_) async => []);
      await provider.fetchCategoryRecords();

      // No createCategory should be called
      verifyNever(() => mockRepo.createCategory(any()));

      final id = await provider.resolveCategoryByNameOrCreate('Streaming', 'expense', -1);
      expect(id, 12);
      verifyNever(() => mockRepo.createCategory(any()));
    });

    test('IT-04: Creates new category and returns its id when name not found', () async {
      when(() => mockRepo.getCategories()).thenAnswer((_) async => []);
      when(() => mockRepo.getRecords()).thenAnswer((_) async => []);
      when(() => mockRepo.getSubCategories()).thenAnswer((_) async => []);
      when(() => mockRepo.createCategory(any())).thenAnswer((_) async => 42);
      await provider.fetchCategoryRecords();

      final id = await provider.resolveCategoryByNameOrCreate('NewCat', 'income', -1);
      expect(id, 42);
      verify(() => mockRepo.createCategory(any())).called(1);
    });

    test('IT-05: Falls back to parentId=-1 when given parent does not exist', () async {
      when(() => mockRepo.getCategories()).thenAnswer((_) async => []);
      when(() => mockRepo.getRecords()).thenAnswer((_) async => []);
      when(() => mockRepo.getSubCategories()).thenAnswer((_) async => []);
      when(() => mockRepo.createCategory(any())).thenAnswer((_) async => 99);
      await provider.fetchCategoryRecords();

      // parent_id=999 does not exist in cache → should fall back to -1
      final id = await provider.resolveCategoryByNameOrCreate('SubCat', 'expense', 999);
      expect(id, 99);

      final captured = verify(() => mockRepo.createCategory(captureAny())).captured;
      final createdCategory = captured.first as Category;
      expect(createdCategory.parentId, -1,
          reason: 'parent_id should fall back to -1 when parent not in local cache');
    });

    test('IT-06: Case-insensitive name match reuses existing category', () async {
      when(() => mockRepo.getCategories()).thenAnswer((_) async => [
            Category(name: 'streaming', type: 'expense', parentId: -1, categoryId: 7),
          ]);
      when(() => mockRepo.getRecords()).thenAnswer((_) async => []);
      when(() => mockRepo.getSubCategories()).thenAnswer((_) async => []);
      await provider.fetchCategoryRecords();

      // 'STREAMING' should match 'streaming'
      final id = await provider.resolveCategoryByNameOrCreate('STREAMING', 'expense', -1);
      expect(id, 7);
      verifyNever(() => mockRepo.createCategory(any()));
    });
  });

  group('[Integration] SuggestedCategory clear → UI state', () {
    test('IT-07: Confirm path: copyWith(categoryId: newId, clearSuggestedCategory: true) produces clean record', () {
      final sc = SuggestedCategory(
        name: 'Streaming',
        type: 'expense',
        parentId: -1,
        message: 'Create?',
      );

      final original = Record(
        recordId: 1,
        amount: 50000,
        description: 'Netflix',
        categoryId: -1,
        type: 'expense',
        date: DateTime.now(),
        sourceId: 's1',
        suggestedCategory: sc,
      );

      // Simulate the full confirm path
      const newCategoryId = 12;
      final confirmed = original.copyWith(
        categoryId: newCategoryId,
        clearSuggestedCategory: true,
      );

      expect(confirmed.categoryId, newCategoryId);
      expect(confirmed.suggestedCategory, isNull,
          reason: 'Banner should disappear after confirm');
    });

    test('IT-08: Cancel path: copyWith(clearSuggestedCategory: true) preserves categoryId=-1', () {
      final sc = SuggestedCategory(
        name: 'Streaming',
        type: 'expense',
        parentId: -1,
        message: 'Create?',
      );

      final original = Record(
        recordId: 1,
        amount: 50000,
        description: 'Netflix',
        categoryId: -1,
        type: 'expense',
        date: DateTime.now(),
        sourceId: 's1',
        suggestedCategory: sc,
      );

      // Simulate cancel: clear suggestion, keep categoryId = -1
      final cancelled = original.copyWith(clearSuggestedCategory: true);

      expect(cancelled.categoryId, -1,
          reason: 'Cancel must not change categoryId');
      expect(cancelled.suggestedCategory, isNull,
          reason: 'Banner should disappear after cancel');
    });
  });
}
