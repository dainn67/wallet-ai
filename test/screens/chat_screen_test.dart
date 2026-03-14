import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/chat_message.dart';
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/screens/chat_screen.dart';

class MockChatProvider extends Mock implements ChatProvider {}

void main() {
  late MockChatProvider mockChatProvider;

  setUp(() {
    mockChatProvider = MockChatProvider();
    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);
  });

  Widget createChatScreen() {
    return MaterialApp(
      home: ChangeNotifierProvider<ChatProvider>.value(
        value: mockChatProvider,
        child: const ChatScreen(),
      ),
    );
  }

  testWidgets('ChatScreen displays welcome message when empty', (tester) async {
    await tester.pumpWidget(createChatScreen());

    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('ChatScreen displays messages from provider', (tester) async {
    final messages = [
      ChatMessage(
        id: '1',
        role: ChatRole.user,
        content: 'Hello',
        timestamp: DateTime.now(),
      ),
      ChatMessage(
        id: '2',
        role: ChatRole.assistant,
        content: 'Hi there! How can I help you?',
        timestamp: DateTime.now(),
      ),
    ];

    when(() => mockChatProvider.messages).thenReturn(messages);

    await tester.pumpWidget(createChatScreen());

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Hi there! How can I help you?'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
  });

  testWidgets('ChatScreen calls sendMessage and clears controller', (tester) async {
    when(() => mockChatProvider.sendMessage(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createChatScreen());

    await tester.enterText(find.byType(TextField), 'Test message');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    verify(() => mockChatProvider.sendMessage('Test message')).called(1);
    expect(find.text('Test message'), findsNothing); // Controller cleared
  });

  testWidgets('Send button is disabled when streaming', (tester) async {
    when(() => mockChatProvider.isStreaming).thenReturn(true);

    await tester.pumpWidget(createChatScreen());

    final sendButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.send),
        matching: find.byType(IconButton),
      ),
    );
    expect(sendButton.onPressed, isNull);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
