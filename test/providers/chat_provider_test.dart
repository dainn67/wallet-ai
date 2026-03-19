import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/services.dart';

class MockChatApiService extends Mock implements ChatApiService {}
class MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  late ChatProvider chatProvider;
  late MockChatApiService mockChatApiService;
  late MockRecordRepository mockRecordRepository;

  setUp(() {
    mockChatApiService = MockChatApiService();
    mockRecordRepository = MockRecordRepository();

    ChatApiService.setMockInstance(mockChatApiService);
    RecordRepository.setMockInstance(mockRecordRepository);

    chatProvider = ChatProvider();
    
    // Default mocks
    registerFallbackValue(Record(
      moneySourceId: 1,
      amount: 0,
      currency: 'VND',
      description: '',
      type: 'expense',
    ));
    
    when(() => mockRecordRepository.createRecord(any())).thenAnswer((_) async => 1);
  });

  tearDown(() {
    ChatApiService.setMockInstance(null);
    RecordRepository.setMockInstance(null);
  });

  test('sendMessage parses records with IDs and fallbacks correctly', () async {
    final streamController = StreamController<ChatStreamResponse>();
    
    when(() => mockChatApiService.streamChat(
      any(),
      conversationId: any(named: 'conversationId'),
      categoryList: any(named: 'categoryList'),
      moneySourceList: any(named: 'moneySourceList'),
    )).thenAnswer((_) => streamController.stream);

    final aiResponse = 'I have recorded your expense.\n--//--\n'
        '['
        '  {'
        '    "source_id": 2,'
        '    "category_id": 3,'
        '    "amount": 50000,'
        '    "category": "Food",'
        '    "description": "Lunch",'
        '    "type": "expense"'
        '  },'
        '  {'
        '    "source_id": null,'
        '    "category_id": "invalid",'
        '    "amount": 10000,'
        '    "description": "Bus ticket",'
        '    "type": "expense"'
        '  }'
        ']';

    // Start sending message
    final future = chatProvider.sendMessage('I spent 50k on lunch and 10k on bus');

    // Simulate AI stream
    streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg1'));
    await streamController.close();

    await future;

    // Verify first record
    verify(() => mockRecordRepository.createRecord(any(
      that: predicate<Record>((r) => 
        r.moneySourceId == 2 && 
        r.categoryId == 3 && 
        r.amount == 50000 && 
        r.description == 'Food: Lunch' &&
        r.type == 'expense'
      )
    ))).called(1);

    // Verify second record (fallbacks)
    verify(() => mockRecordRepository.createRecord(any(
      that: predicate<Record>((r) => 
        r.moneySourceId == 1 && 
        r.categoryId == 1 && 
        r.amount == 10000 && 
        r.description == 'Bus ticket' &&
        r.type == 'expense'
      )
    ))).called(1);

    expect(chatProvider.messages.last.records?.length, 2);
  });
}
