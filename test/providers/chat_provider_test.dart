import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/providers/locale_provider.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/services/services.dart';

class MockChatApiService extends Mock implements ChatApiService {}
class MockRecordProvider extends Mock implements RecordProvider {}

void main() {
  late ChatProvider chatProvider;
  late MockChatApiService mockChatApiService;
  late MockRecordProvider mockRecordProvider;

  setUp(() {
    mockChatApiService = MockChatApiService();
    mockRecordProvider = MockRecordProvider();

    ChatApiService.setMockInstance(mockChatApiService);

    chatProvider = ChatProvider(recordProvider: mockRecordProvider);

    // Default mocks
    registerFallbackValue(Record(
      moneySourceId: 1,
      amount: 0,
      currency: 'VND',
      description: '',
      type: 'expense',
    ));

    when(() => mockRecordProvider.createRecord(any())).thenAnswer((_) async => 1);
    when(() => mockRecordProvider.loadAll()).thenAnswer((_) async {});
    when(() => mockRecordProvider.categories).thenReturn([]);
    when(() => mockRecordProvider.moneySources).thenReturn([]);
  });

  tearDown(() {
    ChatApiService.setMockInstance(null);
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
    verify(() => mockRecordProvider.createRecord(any(
      that: predicate<Record>((r) => 
        r.moneySourceId == 2 && 
        r.categoryId == 3 && 
        r.amount == 50000 && 
        r.description == 'Food: Lunch' &&
        r.type == 'expense'
      )
    ))).called(1);

    // Verify second record (fallbacks)
    verify(() => mockRecordProvider.createRecord(any(
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

  test('greeting with suggestedPrompts JSON populates suggestedPrompts', () async {
    final streamController = StreamController<ChatStreamResponse>();

    when(() => mockChatApiService.streamChat(
      any(),
      conversationId: any(named: 'conversationId'),
      categoryList: any(named: 'categoryList'),
      moneySourceList: any(named: 'moneySourceList'),
      language: any(named: 'language'),
      currency: any(named: 'currency'),
      pattern: any(named: 'pattern'),
    )).thenAnswer((_) => streamController.stream);

    final aiResponse = 'Chào mừng bạn trở lại!--//--{"suggestedPrompts": [{"prompt": "Bánh mì", "actions": ["15k", "20k"]}]}';

    final future = chatProvider.sendMessage('hello');

    streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg2'));
    await streamController.close();

    await future;

    expect(chatProvider.suggestedPrompts.length, 1);
    expect(chatProvider.suggestedPrompts.first.prompt, 'Bánh mì');
    expect(chatProvider.suggestedPrompts.first.actions, ['15k', '20k']);
  });

  test('greeting with record array does not populate suggestedPrompts', () async {
    final streamController = StreamController<ChatStreamResponse>();

    when(() => mockChatApiService.streamChat(
      any(),
      conversationId: any(named: 'conversationId'),
      categoryList: any(named: 'categoryList'),
      moneySourceList: any(named: 'moneySourceList'),
      language: any(named: 'language'),
      currency: any(named: 'currency'),
      pattern: any(named: 'pattern'),
    )).thenAnswer((_) => streamController.stream);

    final aiResponse = 'I recorded it.\n--//--\n'
        '[{"source_id": 1, "category_id": 1, "amount": 10000, "description": "Coffee", "type": "expense"}]';

    final future = chatProvider.sendMessage('coffee 10k');

    streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg3'));
    await streamController.close();

    await future;

    expect(chatProvider.suggestedPrompts, isEmpty);
    expect(chatProvider.messages.last.records?.length, 1);
  });

  test('greeting with no delimiter leaves suggestedPrompts empty', () async {
    final streamController = StreamController<ChatStreamResponse>();

    when(() => mockChatApiService.streamChat(
      any(),
      conversationId: any(named: 'conversationId'),
      categoryList: any(named: 'categoryList'),
      moneySourceList: any(named: 'moneySourceList'),
      language: any(named: 'language'),
      currency: any(named: 'currency'),
      pattern: any(named: 'pattern'),
    )).thenAnswer((_) => streamController.stream);

    final aiResponse = 'Hello! How can I help you today?';

    final future = chatProvider.sendMessage('hi');

    streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg4'));
    await streamController.close();

    await future;

    expect(chatProvider.suggestedPrompts, isEmpty);
  });

  test('malformed suggestedPrompts JSON leaves suggestedPrompts empty and does not crash', () async {
    final streamController = StreamController<ChatStreamResponse>();

    when(() => mockChatApiService.streamChat(
      any(),
      conversationId: any(named: 'conversationId'),
      categoryList: any(named: 'categoryList'),
      moneySourceList: any(named: 'moneySourceList'),
      language: any(named: 'language'),
      currency: any(named: 'currency'),
      pattern: any(named: 'pattern'),
    )).thenAnswer((_) => streamController.stream);

    final aiResponse = 'Hi!--//--{"suggestedPrompts": 123}';

    final future = chatProvider.sendMessage('hello');

    streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg5'));
    await streamController.close();

    await future;

    expect(chatProvider.suggestedPrompts, isEmpty);
  });

  test('selectPrompt with non-empty actions sets activePromptIndex and showingActions true', () async {
    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k', '20k']),
      SuggestedPrompt(prompt: 'Cà phê', actions: []),
    ]);

    chatProvider.selectPrompt(0);

    expect(chatProvider.activePromptIndex, 0);
    expect(chatProvider.showingActions, true);
  });

  test('selectPrompt with empty actions sets activePromptIndex but showingActions false', () async {
    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
      SuggestedPrompt(prompt: 'Cà phê', actions: []),
    ]);

    chatProvider.selectPrompt(1);

    expect(chatProvider.activePromptIndex, 1);
    expect(chatProvider.showingActions, false);
  });

  test('selectAction sets showingActions to false, activePromptIndex unchanged', () async {
    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
    ]);
    chatProvider.selectPrompt(0);
    expect(chatProvider.showingActions, true);

    chatProvider.selectAction();

    expect(chatProvider.showingActions, false);
    expect(chatProvider.activePromptIndex, 0);
  });

  test('sendMessage with active prompt removes prompt and resets indices', () async {
    final streamController = StreamController<ChatStreamResponse>();

    when(() => mockChatApiService.streamChat(
      any(),
      conversationId: any(named: 'conversationId'),
      categoryList: any(named: 'categoryList'),
      moneySourceList: any(named: 'moneySourceList'),
      language: any(named: 'language'),
      currency: any(named: 'currency'),
      pattern: any(named: 'pattern'),
    )).thenAnswer((_) => streamController.stream);

    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
      SuggestedPrompt(prompt: 'Cà phê', actions: []),
    ]);
    chatProvider.selectPrompt(0);

    final future = chatProvider.sendMessage('Bánh mì 15k');
    streamController.add(ChatStreamResponse(answer: 'OK', messageId: 'msg7'));
    await streamController.close();
    await future;

    expect(chatProvider.suggestedPrompts.length, 1);
    expect(chatProvider.suggestedPrompts.first.prompt, 'Cà phê');
    expect(chatProvider.activePromptIndex, null);
    expect(chatProvider.showingActions, false);
  });

  test('sendMessage without active prompt leaves suggestedPrompts unchanged', () async {
    final streamController = StreamController<ChatStreamResponse>();

    when(() => mockChatApiService.streamChat(
      any(),
      conversationId: any(named: 'conversationId'),
      categoryList: any(named: 'categoryList'),
      moneySourceList: any(named: 'moneySourceList'),
      language: any(named: 'language'),
      currency: any(named: 'currency'),
      pattern: any(named: 'pattern'),
    )).thenAnswer((_) => streamController.stream);

    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Grab', actions: ['25k']),
    ]);

    final future = chatProvider.sendMessage('Grab 25k');
    streamController.add(ChatStreamResponse(answer: 'OK', messageId: 'msg8'));
    await streamController.close();
    await future;

    expect(chatProvider.suggestedPrompts.length, 1);
  });

  test('sendMessage with last active prompt results in empty suggestedPrompts', () async {
    final streamController = StreamController<ChatStreamResponse>();

    when(() => mockChatApiService.streamChat(
      any(),
      conversationId: any(named: 'conversationId'),
      categoryList: any(named: 'categoryList'),
      moneySourceList: any(named: 'moneySourceList'),
      language: any(named: 'language'),
      currency: any(named: 'currency'),
      pattern: any(named: 'pattern'),
    )).thenAnswer((_) => streamController.stream);

    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
    ]);
    chatProvider.selectPrompt(0);

    final future = chatProvider.sendMessage('Bánh mì 15k');
    streamController.add(ChatStreamResponse(answer: 'OK', messageId: 'msg9'));
    await streamController.close();
    await future;

    expect(chatProvider.suggestedPrompts, isEmpty);
    expect(chatProvider.activePromptIndex, null);
  });

  test('sendMessage with empty content and active prompt still removes prompt', () async {
    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
    ]);
    chatProvider.selectPrompt(0);

    await chatProvider.sendMessage('');

    expect(chatProvider.suggestedPrompts, isEmpty);
    expect(chatProvider.activePromptIndex, null);
  });

  test('empty suggestedPrompts array leaves suggestedPrompts as empty list', () async {
    final streamController = StreamController<ChatStreamResponse>();

    when(() => mockChatApiService.streamChat(
      any(),
      conversationId: any(named: 'conversationId'),
      categoryList: any(named: 'categoryList'),
      moneySourceList: any(named: 'moneySourceList'),
      language: any(named: 'language'),
      currency: any(named: 'currency'),
      pattern: any(named: 'pattern'),
    )).thenAnswer((_) => streamController.stream);

    final aiResponse = 'Welcome!--//--{"suggestedPrompts": []}';

    final future = chatProvider.sendMessage('hello');

    streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg6'));
    await streamController.close();

    await future;

    expect(chatProvider.suggestedPrompts, isEmpty);
  });
}
