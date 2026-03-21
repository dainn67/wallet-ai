import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/components/month_divider.dart';

void main() {
  testWidgets('MonthDivider renders label text', (WidgetTester tester) async {
    const testLabel = 'March 2026';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonthDivider(label: testLabel),
        ),
      ),
    );

    // Verify the text is displayed
    expect(find.text(testLabel), findsOneWidget);

    // Verify the styling
    final textWidget = tester.widget<Text>(find.text(testLabel));
    expect(textWidget.style?.fontSize, 12);
    expect(textWidget.style?.fontWeight, FontWeight.w600);
    expect(textWidget.style?.color, const Color(0xFF64748B));
  });

  testWidgets('MonthDivider contains a Divider', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonthDivider(label: 'Test'),
        ),
      ),
    );

    expect(find.byType(Divider), findsOneWidget);
  });
}
