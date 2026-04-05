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

  group('suggested_category stream parsing', () {
    test('record with category_id=-1 and valid suggested_category gets non-null suggestedCategory', () async {
      final streamController = StreamController<ChatStreamResponse>();

      when(() => mockChatApiService.streamChat(
        any(),
        conversationId: any(named: 'conversationId'),
        categoryList: any(named: 'categoryList'),
        moneySourceList: any(named: 'moneySourceList'),
      )).thenAnswer((_) => streamController.stream);

      final aiResponse = 'Recorded.\n--//--\n'
          '['
          '  {'
          '    "source_id": 1,'
          '    "category_id": "-1",'
          '    "amount": 50000,'
          '    "description": "Netflix",'
          '    "type": "expense",'
          '    "suggested_category": {'
          '      "name": "Streaming",'
          '      "type": "expense",'
          '      "parent_id": -1,'
          '      "message": "Want to create Streaming?"'
          '    }'
          '  }'
          ']';

      final future = chatProvider.sendMessage('Netflix 50k');
      streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg_sc1'));
      await streamController.close();
      await future;

      final records = chatProvider.messages.last.records;
      expect(records, isNotNull);
      expect(records!.length, 1);
      expect(records.first.categoryId, -1);
      expect(records.first.suggestedCategory, isNotNull);
      expect(records.first.suggestedCategory!.name, 'Streaming');
    });

    test('record with valid category_id has null suggestedCategory', () async {
      final streamController = StreamController<ChatStreamResponse>();

      when(() => mockChatApiService.streamChat(
        any(),
        conversationId: any(named: 'conversationId'),
        categoryList: any(named: 'categoryList'),
        moneySourceList: any(named: 'moneySourceList'),
      )).thenAnswer((_) => streamController.stream);

      final aiResponse = 'Recorded.\n--//--\n'
          '['
          '  {'
          '    "source_id": 1,'
          '    "category_id": 2,'
          '    "amount": 30000,'
          '    "description": "Lunch",'
          '    "type": "expense"'
          '  }'
          ']';

      final future = chatProvider.sendMessage('Lunch 30k');
      streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg_sc2'));
      await streamController.close();
      await future;

      final records = chatProvider.messages.last.records;
      expect(records, isNotNull);
      expect(records!.first.suggestedCategory, isNull);
    });

    test('malformed suggested_category (missing name) produces null suggestedCategory without crash', () async {
      final streamController = StreamController<ChatStreamResponse>();

      when(() => mockChatApiService.streamChat(
        any(),
        conversationId: any(named: 'conversationId'),
        categoryList: any(named: 'categoryList'),
        moneySourceList: any(named: 'moneySourceList'),
      )).thenAnswer((_) => streamController.stream);

      final aiResponse = 'Recorded.\n--//--\n'
          '['
          '  {'
          '    "source_id": 1,'
          '    "category_id": "-1",'
          '    "amount": 20000,'
          '    "description": "Grab",'
          '    "type": "expense",'
          '    "suggested_category": {"type": "expense", "message": "Missing name"}'
          '  }'
          ']';

      final future = chatProvider.sendMessage('Grab 20k');
      streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg_sc3'));
      await streamController.close();
      await future;

      final records = chatProvider.messages.last.records;
      expect(records, isNotNull);
      expect(records!.first.suggestedCategory, isNull);
    });

    test('suggested_category as a string produces null suggestedCategory without crash', () async {
      final streamController = StreamController<ChatStreamResponse>();

      when(() => mockChatApiService.streamChat(
        any(),
        conversationId: any(named: 'conversationId'),
        categoryList: any(named: 'categoryList'),
        moneySourceList: any(named: 'moneySourceList'),
      )).thenAnswer((_) => streamController.stream);

      final aiResponse = 'Recorded.\n--//--\n'
          '['
          '  {'
          '    "source_id": 1,'
          '    "category_id": "-1",'
          '    "amount": 15000,'
          '    "description": "Bus",'
          '    "type": "expense",'
          '    "suggested_category": "bad string value"'
          '  }'
          ']';

      final future = chatProvider.sendMessage('Bus 15k');
      streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg_sc4'));
      await streamController.close();
      await future;

      final records = chatProvider.messages.last.records;
      expect(records, isNotNull);
      expect(records!.first.suggestedCategory, isNull);
    });

    test('mixed batch: valid/null/malformed suggestions parsed correctly — all 3 records saved', () async {
      final streamController = StreamController<ChatStreamResponse>();

      when(() => mockChatApiService.streamChat(
        any(),
        conversationId: any(named: 'conversationId'),
        categoryList: any(named: 'categoryList'),
        moneySourceList: any(named: 'moneySourceList'),
      )).thenAnswer((_) => streamController.stream);

      final aiResponse = 'Recorded 3 items.\n--//--\n'
          '['
          '  {'
          '    "source_id": 1, "category_id": "-1", "amount": 50000,'
          '    "description": "Netflix", "type": "expense",'
          '    "suggested_category": {"name": "Streaming", "type": "expense", "parent_id": -1, "message": "Create?"}'
          '  },'
          '  {'
          '    "source_id": 1, "category_id": "3", "amount": 30000,'
          '    "description": "Lunch", "type": "expense"'
          '  },'
          '  {'
          '    "source_id": 1, "category_id": "-1", "amount": 20000,'
          '    "description": "Grab", "type": "expense",'
          '    "suggested_category": {"type": "expense"}'
          '  }'
          ']';

      final future = chatProvider.sendMessage('3 items');
      streamController.add(ChatStreamResponse(answer: aiResponse, messageId: 'msg_sc5'));
      await streamController.close();
      await future;

      final records = chatProvider.messages.last.records;
      expect(records, isNotNull);
      expect(records!.length, 3);
      expect(records[0].suggestedCategory, isNotNull); // valid suggestion
      expect(records[1].suggestedCategory, isNull);    // normal category_id
      expect(records[2].suggestedCategory, isNull);    // malformed (missing name)
    });
  });
}
