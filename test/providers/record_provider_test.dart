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
  });
}
