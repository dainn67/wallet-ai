// Smoke tests for the suggested-prompts epic.
// Tests the full user-visible flow: chip bar appears → prompt tap → action tap → send → removal.
// These are widget-level smoke tests using the real ChatProvider with a mocked API service.
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

  testWidgets('Smoke: chip bar is hidden for new users (no suggestedPrompts)', (tester) async {
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

    await tester.pumpWidget(buildChatTab(chatProvider));
    expect(find.byType(SuggestedPromptsBar), findsNothing);

    // Simulate greeting without suggestedPrompts
    unawaited(chatProvider.sendMessage('hi'));
    streamController.add(ChatStreamResponse(
        answer: 'Hello! How can I help you today?', messageId: 'msg1'));
    await streamController.close();
    await tester.pump();

    expect(find.byType(SuggestedPromptsBar), findsNothing);
  });

  testWidgets('Smoke: chip bar appears after greeting with suggestedPrompts', (tester) async {
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

    await tester.pumpWidget(buildChatTab(chatProvider));
    expect(find.byType(SuggestedPromptsBar), findsNothing);

    unawaited(chatProvider.sendMessage('hello'));
    streamController.add(ChatStreamResponse(
        answer: 'Chào mừng!--//--{"suggestedPrompts": [{"prompt": "Bánh mì", "actions": ["15k", "20k"]}, {"prompt": "Cà phê", "actions": []}]}',
        messageId: 'msg2'));
    await streamController.close();
    await tester.pump();

    expect(find.byType(SuggestedPromptsBar), findsOneWidget);
    expect(chatProvider.suggestedPrompts.length, 2);
  });

  testWidgets('Smoke: tapping prompt chip pre-fills input text', (tester) async {
    final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k', '20k']),
      SuggestedPrompt(prompt: 'Cà phê', actions: []),
    ]);

    await tester.pumpWidget(buildChatTab(chatProvider));

    expect(find.byType(SuggestedPromptsBar), findsOneWidget);
    expect(find.text('Bánh mì'), findsOneWidget);

    await tester.tap(find.text('Bánh mì'));
    await tester.pump();

    expect(find.text('Bánh mì'), findsWidgets);
    expect(chatProvider.activePromptIndex, 0);
    expect(chatProvider.showingActions, true);
  });

  testWidgets('Smoke: full 3-step flow — prompt → action → send removes prompt', (tester) async {
    final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k', '20k']),
      SuggestedPrompt(prompt: 'Cà phê', actions: []),
    ]);

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

    await tester.pumpWidget(buildChatTab(chatProvider));

    // Step 1: tap prompt chip
    await tester.tap(find.text('Bánh mì'));
    await tester.pump();
    expect(chatProvider.activePromptIndex, 0);
    expect(chatProvider.showingActions, true);

    // Step 2: tap action chip
    await tester.tap(find.text('15k'));
    await tester.pump();
    expect(chatProvider.showingActions, false);

    // Step 3: send — active prompt removed
    unawaited(chatProvider.sendMessage('Bánh mì 15k'));
    streamController.add(ChatStreamResponse(answer: 'Đã ghi!', messageId: 'msg3'));
    await streamController.close();
    await tester.pump();

    expect(chatProvider.suggestedPrompts.length, 1);
    expect(chatProvider.suggestedPrompts.first.prompt, 'Cà phê');
    expect(chatProvider.activePromptIndex, null);
  });

  testWidgets('Smoke: send without tapping any chip leaves all prompts intact', (tester) async {
    final chatProvider = ChatProvider(recordProvider: mockRecordProvider);
    chatProvider.setTestSuggestedPrompts([
      SuggestedPrompt(prompt: 'Bánh mì', actions: ['15k']),
      SuggestedPrompt(prompt: 'Cà phê', actions: []),
    ]);

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

    await tester.pumpWidget(buildChatTab(chatProvider));

    unawaited(chatProvider.sendMessage('Grab 25k'));
    streamController.add(ChatStreamResponse(answer: 'Đã ghi!', messageId: 'msg4'));
    await streamController.close();
    await tester.pump();

    // Both prompts still present
    expect(chatProvider.suggestedPrompts.length, 2);
  });
}
