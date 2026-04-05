import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

class RecordFake extends Fake implements Record {}
class MoneySourceFake extends Fake implements MoneySource {}
class CategoryFake extends Fake implements Category {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('home_widget');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null;
    });
    registerFallbackValue(RecordFake());
    registerFallbackValue(MoneySourceFake());
    registerFallbackValue(CategoryFake());
  });

  late RecordProvider recordProvider;
  late MockRecordRepository mockRepository;

  setUp(() {
    mockRepository = MockRecordRepository();
    when(() => mockRepository.getCategoryTotals()).thenAnswer((_) async => <int, double>{});
    recordProvider = RecordProvider(repository: mockRepository);
  });

  group('RecordProvider', () {
    test('initial state is correct', () {
      expect(recordProvider.records, isEmpty);
      expect(recordProvider.moneySources, isEmpty);
      expect(recordProvider.isLoading, false);
    });

    test('loadAll sets isLoading to true then false', () async {
      when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
      when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
      when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);

      final future = recordProvider.loadAll();
      expect(recordProvider.isLoading, true);

      await future;
      expect(recordProvider.isLoading, false);
    });

    test('loadAll populates records and moneySources from repository', () async {
      final mockRecords = [
        Record(recordId: 1, moneySourceId: 1, amount: 100.0, currency: 'VND', description: 'Test', type: 'expense'),
      ];
      final mockMoneySources = [
        MoneySource(sourceId: 1, sourceName: 'Test Source'),
      ];
      final mockCategories = [
        Category(categoryId: 1, name: 'Food', type: 'expense'),
      ];

      when(() => mockRepository.getAllRecords()).thenAnswer((_) async => mockRecords);
      when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => mockMoneySources);
      when(() => mockRepository.getAllCategories()).thenAnswer((_) async => mockCategories);

      await recordProvider.loadAll();

      expect(recordProvider.records.length, 1);
      expect(recordProvider.records[0].amount, 100.0);
      expect(recordProvider.moneySources.length, 1);
      expect(recordProvider.moneySources[0].sourceName, 'Test Source');
      expect(recordProvider.categories.length, 1);
      expect(recordProvider.categories[0].name, 'Food');
    });

    test('loadAll handles error gracefully', () async {
      when(() => mockRepository.getAllRecords()).thenThrow(Exception('DB Error'));
      when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
      when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);

      await recordProvider.loadAll();

      expect(recordProvider.isLoading, false);
      expect(recordProvider.records, isEmpty);
    });

    group('CRUD operations', () {
      test('addRecord adds to internal list and calls repository', () async {
        final newRecord = Record(moneySourceId: 1, categoryId: 1, amount: 50.0, currency: 'VND', description: 'New', type: 'expense');
        when(() => mockRepository.createRecord(newRecord)).thenAnswer((_) async => 10);
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => [newRecord.copyWith(recordId: 10)]);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);

        await recordProvider.addRecord(newRecord);

        expect(recordProvider.records.length, 1);
        expect(recordProvider.records[0].recordId, 10);
        verify(() => mockRepository.createRecord(newRecord)).called(1);
      });

      test('updateRecord updates internal list and calls repository', () async {
        final initialRecord = Record(recordId: 1, moneySourceId: 1, categoryId: 1, amount: 100.0, currency: 'VND', description: 'Old', type: 'expense');
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => [initialRecord]);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
        await recordProvider.loadAll();

        final updatedRecord = initialRecord.copyWith(amount: 150.0);
        when(() => mockRepository.updateRecord(any())).thenAnswer((_) async => 1);

        // We also need to mock loadAll results for the reload after update
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => [updatedRecord]);

        await recordProvider.updateRecord(updatedRecord);

        expect(recordProvider.records[0].amount, 150.0);
        verify(() => mockRepository.updateRecord(any())).called(1);
      });

      test('deleteRecord removes from internal list and calls repository', () async {
        final recordToDelete = Record(recordId: 1, moneySourceId: 1, categoryId: 1, amount: 100.0, currency: 'VND', description: 'Delete me', type: 'expense');
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => [recordToDelete]);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
        await recordProvider.loadAll();

        when(() => mockRepository.deleteRecord(1)).thenAnswer((_) async => 1);
        // Mock that after deletion, getAllRecords returns empty
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);

        await recordProvider.deleteRecord(1);

        expect(recordProvider.records, isEmpty);
        verify(() => mockRepository.deleteRecord(1)).called(1);
      });

      test('addMoneySource adds to internal list and calls repository', () async {
        final newSource = MoneySource(sourceName: 'New Bank');
        when(() => mockRepository.createMoneySource(newSource)).thenAnswer((_) async => 5);
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => [newSource.copyWith(sourceId: 5)]);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);

        await recordProvider.addMoneySource(newSource);

        expect(recordProvider.moneySources.length, 1);
        expect(recordProvider.moneySources[0].sourceId, 5);
        verify(() => mockRepository.createMoneySource(newSource)).called(1);
      });

      test('updateMoneySource updates internal list and calls repository', () async {
        final initialSource = MoneySource(sourceId: 1, sourceName: 'Old Bank');
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => [initialSource]);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
        await recordProvider.loadAll();

        final updatedSource = initialSource.copyWith(sourceName: 'New Bank');
        when(() => mockRepository.updateMoneySource(updatedSource)).thenAnswer((_) async => 1);

        await recordProvider.updateMoneySource(updatedSource);

        expect(recordProvider.moneySources[0].sourceName, 'New Bank');
        verify(() => mockRepository.updateMoneySource(updatedSource)).called(1);
      });

      test('deleteMoneySource removes from internal list and calls repository', () async {
        final sourceToDelete = MoneySource(sourceId: 1, sourceName: 'Delete me');
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => [sourceToDelete]);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
        await recordProvider.loadAll();

        when(() => mockRepository.deleteMoneySource(1)).thenAnswer((_) async => 1);
        // Mock that after deletion, getAllMoneySources returns empty
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);

        await recordProvider.deleteMoneySource(1);

        expect(recordProvider.moneySources, isEmpty);
        verify(() => mockRepository.deleteMoneySource(1)).called(1);
        verify(() => mockRepository.getAllMoneySources()).called(2); // Initial load + after delete
      });

      test('CRUD methods reload data on error', () async {
        when(() => mockRepository.createRecord(any())).thenThrow(Exception('DB Error'));
        // For reload
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);

        final record = Record(moneySourceId: 1, categoryId: 1, amount: 50.0, currency: 'VND', description: 'New', type: 'expense');
        await recordProvider.addRecord(record);

        verify(() => mockRepository.getAllRecords()).called(1);
        verify(() => mockRepository.getAllMoneySources()).called(1);
        verify(() => mockRepository.getAllCategories()).called(1);
      });

      test('resetAllData sets isLoading and calls repository', () async {
        when(() => mockRepository.resetAllData()).thenAnswer((_) async => {});
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);

        final future = recordProvider.resetAllData();
        expect(recordProvider.isLoading, true);

        await future;
        expect(recordProvider.isLoading, false);
        verify(() => mockRepository.resetAllData()).called(1);
        verify(() => mockRepository.getAllRecords()).called(1);
      });
    });

    group('filtering and sorting', () {
      final mockRecords = [
        Record(recordId: 1, moneySourceId: 1, categoryId: 1, amount: 100.0, currency: 'VND', description: 'Exp 1', type: 'expense'),
        Record(recordId: 2, moneySourceId: 2, categoryId: 2, amount: 200.0, currency: 'VND', description: 'Inc 1', type: 'income'),
        Record(recordId: 3, moneySourceId: 1, categoryId: 1, amount: 300.0, currency: 'VND', description: 'Inc 2', type: 'income'),
      ];

      setUp(() async {
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => mockRecords);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
        await recordProvider.loadAll();
      });

      test('filteredRecords returns all records sorted by recordId descending by default', () {
        final filtered = recordProvider.filteredRecords;
        expect(filtered.length, 3);
        expect(filtered[0].recordId, 3);
        expect(filtered[1].recordId, 2);
        expect(filtered[2].recordId, 1);
      });

      test('filtering by moneySourceId returns correct records', () {
        recordProvider.selectedSourceId = 1;
        final filtered = recordProvider.filteredRecords;
        expect(filtered.length, 2);
        expect(filtered.every((r) => r.moneySourceId == 1), isTrue);
      });

      test('filtering by type returns correct records', () {
        recordProvider.selectedType = 'income';
        final filtered = recordProvider.filteredRecords;
        expect(filtered.length, 2);
        expect(filtered.every((r) => r.type == 'income'), isTrue);
      });

      test('filtering by both moneySourceId and type returns correct records', () {
        recordProvider.selectedSourceId = 1;
        recordProvider.selectedType = 'income';
        final filtered = recordProvider.filteredRecords;
        expect(filtered.length, 1);
        expect(filtered[0].recordId, 3);
      });

      test('clearFilters resets all filters', () {
        recordProvider.selectedSourceId = 1;
        recordProvider.selectedType = 'income';
        recordProvider.clearFilters();

        expect(recordProvider.selectedSourceId, isNull);
        expect(recordProvider.selectedType, isNull);
        expect(recordProvider.filteredRecords.length, 3);
      });

      test('filtering 1000+ records is instantaneous', () async {
        final thousandRecords = List.generate(1000, (i) => Record(
          recordId: i,
          moneySourceId: i % 5,
          amount: i.toDouble(),
          currency: 'VND',
          description: 'Record $i',
          type: i % 2 == 0 ? 'income' : 'expense',
        ));

        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => thousandRecords);
        await recordProvider.loadAll();

        final stopwatch = Stopwatch()..start();
        
        recordProvider.selectedSourceId = 1;
        recordProvider.selectedType = 'income';
        final filtered = recordProvider.filteredRecords;
        
        stopwatch.stop();

        expect(filtered.length, 100); // 1000 / 5 / 2 = 100
        expect(stopwatch.elapsedMilliseconds, lessThan(16));
        print('Filtering 1000 records took: ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    group('hierarchical categories', () {
      final mockCategories = [
        Category(categoryId: 1, name: 'Food', type: 'expense', parentId: -1),
        Category(categoryId: 2, name: 'Transport', type: 'expense', parentId: -1),
        Category(categoryId: 3, name: 'Pizza', type: 'expense', parentId: 1),
        Category(categoryId: 4, name: 'Burger', type: 'expense', parentId: 1),
        Category(categoryId: 5, name: 'Bus', type: 'expense', parentId: 2),
      ];

      setUp(() async {
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => mockCategories);
        await recordProvider.loadAll();
      });

      test('getSubCategories returns correct children', () {
        final foodSubs = recordProvider.getSubCategories(1);
        expect(foodSubs.length, 2);
        expect(foodSubs.any((c) => c.name == 'Pizza'), isTrue);
        expect(foodSubs.any((c) => c.name == 'Burger'), isTrue);

        final transportSubs = recordProvider.getSubCategories(2);
        expect(transportSubs.length, 1);
        expect(transportSubs[0].name, 'Bus');

        final emptySubs = recordProvider.getSubCategories(3);
        expect(emptySubs, isEmpty);
      });

      test('getCategoryName returns "Parent - Child" for sub-categories', () {
        expect(recordProvider.getCategoryName(1), 'Food');
        expect(recordProvider.getCategoryName(3), 'Food - Pizza');
        expect(recordProvider.getCategoryName(5), 'Transport - Bus');
        expect(recordProvider.getCategoryName(99), 'Unknown');
      });
    });

    group('resolveCategoryByNameOrCreate', () {
      final baseCategories = [
        Category(categoryId: 1, name: 'Food', type: 'expense', parentId: -1),
        Category(categoryId: 2, name: 'Transport', type: 'expense', parentId: -1),
        Category(categoryId: 3, name: 'Pizza', type: 'expense', parentId: 1),
      ];

      setUp(() async {
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => baseCategories);
        await recordProvider.loadAll();
      });

      test('creates new category when name not in cache, returns positive id', () async {
        final newCategory = Category(categoryId: 10, name: 'Streaming', type: 'expense', parentId: -1);
        when(() => mockRepository.createCategory(any())).thenAnswer((_) async => 10);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [...baseCategories, newCategory]);

        final result = await recordProvider.resolveCategoryByNameOrCreate('Streaming', 'expense', -1);

        expect(result, 10);
        verify(() => mockRepository.createCategory(any())).called(1);
      });

      test('returns existing categoryId without calling createCategory (exact match)', () async {
        final result = await recordProvider.resolveCategoryByNameOrCreate('Food', 'expense', -1);

        expect(result, 1);
        verifyNever(() => mockRepository.createCategory(any()));
      });

      test('case-insensitive match returns existing categoryId without creating', () async {
        final result = await recordProvider.resolveCategoryByNameOrCreate('food', 'expense', -1);

        expect(result, 1);
        verifyNever(() => mockRepository.createCategory(any()));
      });

      test('creates sub-category under valid parentId', () async {
        when(() => mockRepository.createCategory(any())).thenAnswer((_) async => 20);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [
          ...baseCategories,
          Category(categoryId: 20, name: 'Burger', type: 'expense', parentId: 1),
        ]);

        final result = await recordProvider.resolveCategoryByNameOrCreate('Burger', 'expense', 1);

        expect(result, 20);
        final captured = verify(() => mockRepository.createCategory(captureAny())).captured;
        final createdCategory = captured.first as Category;
        expect(createdCategory.parentId, 1);
      });

      test('falls back to parentId=-1 when parentId not found in cache', () async {
        when(() => mockRepository.createCategory(any())).thenAnswer((_) async => 30);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [
          ...baseCategories,
          Category(categoryId: 30, name: 'NewCat', type: 'expense', parentId: -1),
        ]);

        final result = await recordProvider.resolveCategoryByNameOrCreate('NewCat', 'expense', 999);

        expect(result, 30);
        final captured = verify(() => mockRepository.createCategory(captureAny())).captured;
        final createdCategory = captured.first as Category;
        expect(createdCategory.parentId, -1);
      });

      test('second call with same name returns same id (reuse, no duplicate create)', () async {
        // First call: not in cache, creates
        final afterCreate = [...baseCategories, Category(categoryId: 40, name: 'Streaming', type: 'expense', parentId: -1)];
        when(() => mockRepository.createCategory(any())).thenAnswer((_) async => 40);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => afterCreate);

        final first = await recordProvider.resolveCategoryByNameOrCreate('Streaming', 'expense', -1);
        // Second call: now in cache (categories refreshed after first call)
        final second = await recordProvider.resolveCategoryByNameOrCreate('Streaming', 'expense', -1);

        expect(first, 40);
        expect(second, 40);
        verify(() => mockRepository.createCategory(any())).called(1); // only once
      });

      test('returns null and does not rethrow when createCategory throws', () async {
        when(() => mockRepository.createCategory(any())).thenThrow(Exception('DB error'));

        final result = await recordProvider.resolveCategoryByNameOrCreate('Broken', 'expense', -1);

        expect(result, isNull);
      });

      test('cache is refreshed after creating a new category', () async {
        final newCat = Category(categoryId: 50, name: 'Streaming', type: 'expense', parentId: -1);
        when(() => mockRepository.createCategory(any())).thenAnswer((_) async => 50);
        when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [...baseCategories, newCat]);

        await recordProvider.resolveCategoryByNameOrCreate('Streaming', 'expense', -1);

        expect(recordProvider.categories.any((c) => c.name == 'Streaming'), isTrue);
      });
    });
  });
}
