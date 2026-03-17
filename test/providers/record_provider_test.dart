import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  late RecordProvider recordProvider;
  late MockRecordRepository mockRepository;

  setUp(() {
    mockRepository = MockRecordRepository();
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

      when(() => mockRepository.getAllRecords()).thenAnswer((_) async => mockRecords);
      when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => mockMoneySources);

      await recordProvider.loadAll();

      expect(recordProvider.records.length, 1);
      expect(recordProvider.records[0].amount, 100.0);
      expect(recordProvider.moneySources.length, 1);
      expect(recordProvider.moneySources[0].sourceName, 'Test Source');
    });

    test('loadAll handles error gracefully', () async {
      when(() => mockRepository.getAllRecords()).thenThrow(Exception('DB Error'));
      when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);

      await recordProvider.loadAll();

      expect(recordProvider.isLoading, false);
      expect(recordProvider.records, isEmpty);
    });

    group('filtering and sorting', () {
      final mockRecords = [
        Record(recordId: 1, moneySourceId: 1, amount: 100.0, currency: 'VND', description: 'Exp 1', type: 'expense'),
        Record(recordId: 2, moneySourceId: 2, amount: 200.0, currency: 'VND', description: 'Inc 1', type: 'income'),
        Record(recordId: 3, moneySourceId: 1, amount: 300.0, currency: 'VND', description: 'Inc 2', type: 'income'),
      ];

      setUp(() async {
        when(() => mockRepository.getAllRecords()).thenAnswer((_) async => mockRecords);
        when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
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
  });
}
