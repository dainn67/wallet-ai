import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/main.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';

void main() {
  testWidgets('HomeScreen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that HomeScreen is displayed.
    expect(find.byType(HomeScreen), findsOneWidget);
    
    // Verify that ChatTab is the default tab.
    expect(find.byType(ChatTab), findsOneWidget);
    
    // Verify app title.
    expect(find.text('Wallet AI'), findsOneWidget);
    expect(find.text('Always active'), findsOneWidget);
  });
}
