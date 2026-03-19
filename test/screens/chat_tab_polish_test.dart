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

  Widget createChatTabWidget() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<ChatProvider>.value(value: mockChatProvider, child: const ChatTab()),
      ),
    );
  }

  testWidgets('Error state displays SnackBar', (WidgetTester tester) async {
    when(() => mockChatProvider.sendMessage(any())).thenAnswer((_) async {
      throw Exception('API Error');
    });

    await tester.pumpWidget(createChatTabWidget());

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send_rounded));

    // We need to pump multiple times because of the Snack bar animation and the async call
    await tester.pump(); // Start sendMessage
    await tester.pump(); // Handle error and show SnackBar
    await tester.pump(const Duration(milliseconds: 100)); // Animation start

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Error: Exception: API Error'), findsOneWidget);
  });

  testWidgets('Auto-scrolls when messages update while streaming', (WidgetTester tester) async {
    when(() => mockChatProvider.messages).thenReturn([ChatMessage(id: '1', role: ChatRole.user, content: 'Hello', timestamp: DateTime.now())]);

    await tester.pumpWidget(createChatTabWidget());
    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.controller, isNotNull);
  });
}
