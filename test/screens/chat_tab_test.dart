import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/chat_message.dart';
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';

class MockChatProvider extends Mock implements ChatProvider {}

void main() {
  late MockChatProvider mockChatProvider;

  setUp(() {
    mockChatProvider = MockChatProvider();
    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);
  });

  Widget createChatTab() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<ChatProvider>.value(value: mockChatProvider, child: const ChatTab()),
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
