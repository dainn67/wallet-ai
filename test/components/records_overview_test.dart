import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/components/records_overview.dart';
import 'package:wallet_ai/models/models.dart';

void main() {
  testWidgets('RecordsOverview should display the Sources title and Add button',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsOverview(
            totalBalance: 1000,
            totalIncome: 1500,
            totalExpense: 500,
            sources: [
              MoneySource(
                sourceId: 1,
                sourceName: 'Cash',
                amount: 1000,
              ),
            ],
          ),
        ),
      ),
    );

    // Verify that the 'Sources' text is present.
    expect(find.text('Sources'), findsOneWidget);

    // Verify that the Add button (IconButton with Icons.add_rounded) is present.
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('RecordsOverview should display Add button even if sources is empty',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecordsOverview(
            totalBalance: 0,
            totalIncome: 0,
            totalExpense: 0,
            sources: [],
          ),
        ),
      ),
    );

    // Verify that the 'Sources' text is present.
    expect(find.text('Sources'), findsOneWidget);

    // Verify that the Add button is still present.
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
