import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/services.dart';

class MockRecordRepository extends Mock implements RecordRepository {}
class MockChatApiService extends Mock implements ChatApiService {}

class FakeRecord extends Fake implements Record {}

void main() {
  late MockRecordRepository mockRecordRepository;
  late MockChatApiService mockChatApiService;

  setUpAll(() {
    registerFallbackValue(FakeRecord());
  });

  setUp(() {
    mockRecordRepository = MockRecordRepository();
    mockChatApiService = MockChatApiService();
    
    RecordRepository.setMockInstance(mockRecordRepository);
    ChatApiService.setMockInstance(mockChatApiService);

    when(() => mockRecordRepository.getAllMoneySources()).thenAnswer((_) async => [
      MoneySource(sourceId: 1, sourceName: 'Wallet', amount: 1000),
    ]);
    when(() => mockRecordRepository.getAllCategories()).thenAnswer((_) async => [
      Category(categoryId: 1, name: 'Food', type: 'expense'),
    ]);
    when(() => mockRecordRepository.getAllRecords()).thenAnswer((_) async => []);
    when(() => mockRecordRepository.createRecord(any())).thenAnswer((_) async => 1);
  });

  tearDown(() {
    RecordRepository.setMockInstance(null);
    ChatApiService.setMockInstance(null);
  });

  group('ChatProvider Integration Tests', () {
    test('sendMessage correctly passes context to ChatApiService', () async {
      final recordProvider = RecordProvider(repository: mockRecordRepository);
      await recordProvider.loadAll();
      
      final chatProvider = ChatProvider()..recordProvider = recordProvider;

      when(() => mockChatApiService.streamChat(
        any(),
        conversationId: any(named: 'conversationId'),
        categoryList: any(named: 'categoryList'),
        moneySourceList: any(named: 'moneySourceList'),
      )).thenAnswer((_) => Stream.fromIterable([
        ChatStreamResponse(answer: 'Okay, I will record that.'),
        ChatStreamResponse(answer: '--//--[{"source_id": 1, "category_id": 1, "amount": 50, "category": "Food", "description": "Lunch", "type": "expense"}]'),
      ]));

      await chatProvider.sendMessage('I spent 50 on lunch');

      // Verify ChatApiService was called with correct context
      verify(() => mockChatApiService.streamChat(
        'I spent 50 on lunch',
        conversationId: null,
        categoryList: '1-Food',
        moneySourceList: '1-Wallet',
      )).called(1);
    });

    test('onDone correctly parses IDs and calls RecordProvider.loadAll()', () async {
      final recordProvider = RecordProvider(repository: mockRecordRepository);
      await recordProvider.loadAll();
      
      final chatProvider = ChatProvider()..recordProvider = recordProvider;

      when(() => mockChatApiService.streamChat(
        any(),
        conversationId: any(named: 'conversationId'),
        categoryList: any(named: 'categoryList'),
        moneySourceList: any(named: 'moneySourceList'),
      )).thenAnswer((_) => Stream.fromIterable([
        ChatStreamResponse(answer: 'Okay, I will record that.'),
        ChatStreamResponse(answer: '--//--[{"source_id": 1, "category_id": 1, "amount": 50, "category": "Food", "description": "Lunch", "type": "expense"}]'),
      ]));

      await chatProvider.sendMessage('I spent 50 on lunch');

      // Verify recordRepository.createRecord was called with correct IDs from AI response
      verify(() => mockRecordRepository.createRecord(any(that: predicate<Record>((r) => 
        r.moneySourceId == 1 && r.categoryId == 1 && r.amount == 50.0
      )))).called(1);

      // Verify loadAll was called again after creation
      // Total calls to getAllRecords should be 2 (1 initial + 1 after record creation)
      verify(() => mockRecordRepository.getAllRecords()).called(2);
    });
  });
}
