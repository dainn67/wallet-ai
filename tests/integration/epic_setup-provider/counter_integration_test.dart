import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/main.dart';
import 'package:wallet_ai/providers/counter_provider.dart';

void main() {
  testWidgets(
    'Integration Test: MultiProvider provides CounterProvider to MyHomePage',
    (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that the CounterProvider is in the widget tree.
      final counterProvider = tester
          .element(find.byType(MyHomePage))
          .read<CounterProvider>();
      expect(counterProvider, isNotNull);
      expect(counterProvider.count, 0);

      // Tap the '+' icon and trigger a frame.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Verify that the provider state and UI are updated.
      expect(counterProvider.count, 1);
      expect(find.text('1'), findsOneWidget);
    },
  );
}
