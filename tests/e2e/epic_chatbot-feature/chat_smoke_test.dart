import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/main.dart' as app;
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/screens/chat_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Smoke Test', () {
    testWidgets('Open chat, send message, and see streaming response', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('How can I help you today?'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Type a message
      final message = 'Hello, AI!';
      await tester.enterText(find.byType(TextField), message);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Tap send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Verify user message is added
      expect(find.text(message), findsOneWidget);
      expect(find.text('You'), findsOneWidget);

      // Verify streaming indicator appears
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Wait for AI response (using pump with duration to simulate stream time)
      // Since we use a real/mock service, we wait for it to emit
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify AI message bubble is present
      expect(find.text('AI'), findsOneWidget);
      // We expect some content from the mock/real backend
      // (The actual content depends on the ChatApiService implementation)
    });
  });
}
