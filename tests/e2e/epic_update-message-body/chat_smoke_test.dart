import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/services/services.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';

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

  testWidgets('Chat smoke test: can send message and receive AI response with records', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
              ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ],
            child: const ChatTab(),
          ),
        ),
      ),
    );

    // Initial message
    expect(find.text('Hello! How can I help you today?'), findsOneWidget);

    // Type and send message
    await tester.enterText(find.byType(TextField), 'I spent 50 on lunch');
    await tester.tap(find.byIcon(Icons.send_rounded));
    
    // Pump for streaming
    await tester.pump();
    expect(find.text('I spent 50 on lunch'), findsOneWidget);
    
    // Wait for stream to complete and UI to update
    await tester.pumpAndSettle();

    // Check if AI response text (before delimiter) is displayed
    expect(find.text('Okay, I will record that.'), findsOneWidget);
    
    // Check if record card is displayed with the formatted description
    expect(find.text('Food: Lunch'), findsOneWidget);
    expect(find.text('-50 VND'), findsOneWidget);
    
    // Verify loadAll was called on recordProvider (total 2 times: initial + after creation)
    verify(() => mockRecordRepository.getAllRecords()).called(2);
  });
}
