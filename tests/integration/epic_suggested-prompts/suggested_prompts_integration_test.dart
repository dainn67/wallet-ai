// Integration tests for the suggested-prompts epic.
// Tests integration between: ChatProvider parsing <-> SuggestedPromptsBar rendering,
// ChatProvider state <-> widget rebuild, TextEditingController <-> tap callbacks.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/components/suggested_prompts_bar.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/models/record.dart';
import 'package:wallet_ai/models/suggested_prompt.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:wallet_ai/services/services.dart';

class MockChatApiService extends Mock implements ChatApiService {}
class MockRecordProvider extends Mock implements RecordProvider {}
class MockLocaleProvider extends Mock implements LocaleProvider {}

void main() {
  late MockChatApiService mockChatApiService;
  late MockRecordProvider mockRecordProvider;
  late MockLocaleProvider mockLocaleProvider;

  setUp(() {
    mockChatApiService = MockChatApiService();
    mockRecordProvider = MockRecordProvider();
    mockLocaleProvider = MockLocaleProvider();

    ChatApiService.setMockInstance(mockChatApiService);

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
    when(() => mockLocaleProvider.translate(any()))
        .thenAnswer((i) => i.positionalArguments[0]);
  });

  tearDown(() {
    ChatApiService.setMockInstance(null);
  });

  Widget buildChatTab(ChatProvider chatProvider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
      ],
      child: const MaterialApp(home: Scaffold(body: ChatTab())),
    );
  }

  group('Integration: ChatProvider parsing <-> widget rendering', () {
    test('Parsing greeting JSON with suggestedPrompts populates provider state', () async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);

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

      final future = chatProvider.sendMessage('hello');
      streamController.add(ChatStreamResponse(
          answer: 'Chào!--//--{"suggestedPrompts": [{"prompt": "Bánh mì", "actions": ["15k", "20k"]}, {"prompt": "Cà phê", "actions": []}]}',
          messageId: 'msg1'));
      await streamController.close();
      await future;

      // Provider state correctly populated
      expect(chatProvider.suggestedPrompts.length, 2);
      expect(chatProvider.suggestedPrompts[0].prompt, 'Bánh mì');
      expect(chatProvider.suggestedPrompts[0].actions, ['15k', '20k']);
      expect(chatProvider.suggestedPrompts[1].prompt, 'Cà phê');
      expect(chatProvider.suggestedPrompts[1].actions, isEmpty);
      // No active selection after parsing
      expect(chatProvider.activePromptIndex, null);
      expect(chatProvider.showingActions, false);
    });

    test('Parsing record array JSON leaves suggestedPrompts empty (regression)', () async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);

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

      final future = chatProvider.sendMessage('cà phê 20k');
      streamController.add(ChatStreamResponse(
          answer: 'Đã ghi!--//--[{"source_id": 1, "category_id": 1, "amount": 20000, "description": "Cà phê", "type": "expense"}]',
          messageId: 'msg2'));
      await streamController.close();
      await future;

      // suggestedPrompts untouched
      expect(chatProvider.suggestedPrompts, isEmpty);
      // Record was parsed
      expect(chatProvider.messages.last.records?.length, 1);
    });

    test('Malformed JSON does not crash and leaves suggestedPrompts empty', () async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);

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

      final future = chatProvider.sendMessage('hello');
      streamController.add(ChatStreamResponse(
          answer: 'Hi!--//--{not valid json at all',
          messageId: 'msg3'));
      await streamController.close();
      await future;

      expect(chatProvider.suggestedPrompts, isEmpty);
    });
  });

  group('Integration: ChatProvider state <-> SuggestedPromptsBar rebuild', () {
    testWidgets('SuggestedPromptsBar visible when provider has prompts', (tester) async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
      chatProvider.setTestSuggestedPrompts([
        SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
      ]);

      await tester.pumpWidget(buildChatTab(chatProvider));

      expect(find.byType(SuggestedPromptsBar), findsOneWidget);
      expect(find.text('Bánh mì'), findsOneWidget);
    });

    testWidgets('SuggestedPromptsBar hidden when provider has no prompts', (tester) async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);

      await tester.pumpWidget(buildChatTab(chatProvider));

      expect(find.byType(SuggestedPromptsBar), findsNothing);
    });

    testWidgets('selectPrompt updates widget to show action chips', (tester) async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
      chatProvider.setTestSuggestedPrompts([
        SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k', '20k']),
      ]);

      await tester.pumpWidget(buildChatTab(chatProvider));

      // Initially shows prompt chip
      expect(find.text('Bánh mì'), findsOneWidget);
      expect(find.text('15k'), findsNothing);

      // Tap prompt chip
      await tester.tap(find.text('Bánh mì'));
      await tester.pump();

      // Now shows action chips
      expect(find.text('15k'), findsOneWidget);
      expect(find.text('20k'), findsOneWidget);
      expect(chatProvider.showingActions, true);
    });

    testWidgets('selectAction hides action chips and resets widget state', (tester) async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
      chatProvider.setTestSuggestedPrompts([
        SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k', '20k']),
      ]);
      chatProvider.selectPrompt(0);

      await tester.pumpWidget(buildChatTab(chatProvider));

      // Currently showing action chips
      expect(find.text('15k'), findsOneWidget);

      // Tap action chip
      await tester.tap(find.text('15k'));
      await tester.pump();

      // Action chips hidden, no prompt chips either (showingActions=false, bar still visible via prompt list)
      expect(chatProvider.showingActions, false);
    });
  });

  group('Integration: TextEditingController <-> prompt/action tap callbacks', () {
    testWidgets('Tapping prompt chip sets TextField text to prompt value', (tester) async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
      chatProvider.setTestSuggestedPrompts([
        SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
      ]);

      await tester.pumpWidget(buildChatTab(chatProvider));

      // TextField starts empty
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '',
        '',
      );

      // Tap the prompt chip
      await tester.tap(find.text('Bánh mì'));
      await tester.pump();

      // TextField now contains the prompt text
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, 'Bánh mì');
    });

    testWidgets('Tapping action chip appends amount to existing TextField text', (tester) async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
      chatProvider.setTestSuggestedPrompts([
        SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k', '20k']),
      ]);

      await tester.pumpWidget(buildChatTab(chatProvider));

      // Step 1: tap prompt chip
      await tester.tap(find.text('Bánh mì'));
      await tester.pump();

      // TextField = 'Bánh mì'
      final tf1 = tester.widget<TextField>(find.byType(TextField));
      expect(tf1.controller?.text, 'Bánh mì');

      // Step 2: tap action chip '15k'
      await tester.tap(find.text('15k'));
      await tester.pump();

      // TextField = 'Bánh mì 15k'
      final tf2 = tester.widget<TextField>(find.byType(TextField));
      expect(tf2.controller?.text, 'Bánh mì 15k');
    });
  });

  group('Integration: sendMessage <-> prompt list state', () {
    test('sendMessage removes active prompt, others remain', () async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
      chatProvider.setTestSuggestedPrompts([
        SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
        SuggestedPrompt(prompt: 'Cà phê', actions: []),
      ]);
      chatProvider.selectPrompt(0);

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

      final future = chatProvider.sendMessage('Bánh mì 15k');
      streamController.add(ChatStreamResponse(answer: 'Đã ghi!', messageId: 'msg5'));
      await streamController.close();
      await future;

      expect(chatProvider.suggestedPrompts.length, 1);
      expect(chatProvider.suggestedPrompts.first.prompt, 'Cà phê');
      expect(chatProvider.activePromptIndex, null);
      expect(chatProvider.showingActions, false);
    });

    test('sendMessage with last prompt clears list entirely', () async {
      final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
      chatProvider.setTestSuggestedPrompts([
        SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
      ]);
      chatProvider.selectPrompt(0);

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

      final future = chatProvider.sendMessage('Bánh mì 15k');
      streamController.add(ChatStreamResponse(answer: 'Đã ghi!', messageId: 'msg6'));
      await streamController.close();
      await future;

      expect(chatProvider.suggestedPrompts, isEmpty);
      expect(chatProvider.activePromptIndex, null);
    });
  });
}
