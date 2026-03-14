import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/main.dart';

void main() {
  testWidgets('Smoke Test: App launches and counter increments correctly', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);

    // Tap the '+' icon.
    await tester.tap(find.byIcon(Icons.add));

    // Trigger a frame after the tap.
    await tester.pump();

    // Verify that our counter has incremented to 1.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
