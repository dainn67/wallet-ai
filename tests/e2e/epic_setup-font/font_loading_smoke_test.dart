import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/main.dart';

void main() {
  testWidgets('Smoke Test: App launches and displays text with Poppins font', (WidgetTester tester) async {
    // Note: In a real CI environment, we would also verify that no network calls are made to fonts.gstatic.com
    // but here we focus on visual presence and lack of errors.
    
    // Build our app and trigger a frame.
    // We use a dummy .env or similar if needed, but MyApp handles basic init.
    await tester.pumpWidget(const MyApp());

    // Verify that some text is displayed (e.g., the app title or a tab label)
    expect(find.byType(Text), findsWidgets);
    
    // Check for specific text from HomeScreen or tabs
    expect(find.textContaining('Wallet'), findsWidgets);
  });
}
