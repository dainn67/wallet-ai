import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/components/record_widget.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:intl/intl.dart';

void main() {
  group('RecordWidget Tests', () {
    final testDate = DateTime(2026, 3, 21);
    final testRecord = Record(
      recordId: 1,
      createdAt: testDate.millisecondsSinceEpoch,
      moneySourceId: 1,
      categoryName: 'Food',
      sourceName: 'Cash',
      amount: 50.0,
      currency: 'USD',
      description: 'Lunch at Cafe',
      type: 'expense',
    );

    testWidgets('renders correct date text for a given timestamp', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordWidget(record: testRecord),
          ),
        ),
      );

      final formattedDate = DateFormat('dd/MM/yyyy').format(testDate);
      expect(find.text(formattedDate), findsOneWidget);
    });

    testWidgets('widget styling (font size/color) matches spec', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordWidget(record: testRecord),
          ),
        ),
      );

      final formattedDate = DateFormat('dd/MM/yyyy').format(testDate);
      final dateText = find.text(formattedDate);
      
      final textWidget = tester.widget<Text>(dateText);
      expect(textWidget.style?.fontSize, 10);
      expect(textWidget.style?.color, const Color(0xFF64748B));
      expect(textWidget.style?.fontFamily, isNull);
    });

    testWidgets('renders description and subtitle correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordWidget(record: testRecord),
          ),
        ),
      );

      expect(find.text('Lunch at Cafe'), findsOneWidget);
      expect(find.text('Food • Cash'), findsOneWidget);
    });
  });
}
