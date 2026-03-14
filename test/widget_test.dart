import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/main.dart';
import 'package:wallet_ai/screens/chat_screen.dart';

void main() {
  testWidgets('ChatScreen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that ChatScreen is displayed.
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Wallet AI Chat'), findsOneWidget);
    expect(find.text('How can I help you today?'), findsOneWidget);
  });
}
