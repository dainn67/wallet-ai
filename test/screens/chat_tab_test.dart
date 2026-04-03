import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/chat_message.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:wallet_ai/services/storage_service.dart';

class MockChatProvider extends Mock implements ChatProvider {}
class MockLocaleProvider extends Mock implements LocaleProvider {}
class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockChatProvider mockChatProvider;
  late MockLocaleProvider mockLocaleProvider;

  setUp(() {
    mockChatProvider = MockChatProvider();
    mockLocaleProvider = MockLocaleProvider();
    
    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);
    when(() => mockChatProvider.suggestedPrompts).thenReturn([]);
    when(() => mockChatProvider.activePromptIndex).thenReturn(null);
    when(() => mockChatProvider.showingActions).thenReturn(false);
    when(() => mockLocaleProvider.translate(any())).thenAnswer((invocation) => invocation.positionalArguments[0]);
  });

  Widget createChatTab() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>.value(value: mockChatProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ChatTab(),
        ),
      ),
    );
  }

  testWidgets('ChatTab displays input area', (tester) async {
    await tester.pumpWidget(createChatTab());

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('ChatTab displays messages from provider', (tester) async {
    final messages = [
      ChatMessage(id: '1', role: ChatRole.user, content: 'Hello', timestamp: DateTime.now()),
      ChatMessage(id: '2', role: ChatRole.assistant, content: 'Hi there! How can I help you?', timestamp: DateTime.now()),
    ];

    when(() => mockChatProvider.messages).thenReturn(messages);

    await tester.pumpWidget(createChatTab());

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Hi there! How can I help you?'), findsOneWidget);
  });

  testWidgets('ChatTab calls sendMessage and clears controller', (tester) async {
    when(() => mockChatProvider.sendMessage(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createChatTab());

    await tester.enterText(find.byType(TextField), 'Test message');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    verify(() => mockChatProvider.sendMessage('Test message')).called(1);
    expect(find.text('Test message'), findsNothing); // Controller cleared
  });

  testWidgets('Send button is disabled when streaming', (tester) async {
    when(() => mockChatProvider.isStreaming).thenReturn(true);

    await tester.pumpWidget(createChatTab());

    final sendButton = tester.widget<GestureDetector>(find.ancestor(of: find.byIcon(Icons.send_rounded), matching: find.byType(GestureDetector)));
    expect(sendButton.onTap, isNull);
  });
}
