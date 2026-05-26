import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/components/category_widget.dart';
import 'package:wallet_ai/models/models.dart';

Widget _wrap(Category category) {
  return MaterialApp(
    home: Scaffold(
      body: CategoryWidget(
        category: category,
        total: 100.0,
        typeLabel: 'Expense',
      ),
    ),
  );
}

void main() {
  group('CategoryWidget emoji rendering', () {
    testWidgets('renders leading emoji Text when emoji is 🍔', (WidgetTester tester) async {
      final category = Category(
        categoryId: 1,
        name: 'Food',
        type: 'expense',
        emoji: '🍔',
      );
      await tester.pumpWidget(_wrap(category));

      expect(find.text('🍔'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_outward_rounded), findsNothing);
    });

    testWidgets('renders leading emoji Text when emoji is 🏷️', (WidgetTester tester) async {
      final category = Category(
        categoryId: 2,
        name: 'Misc',
        type: 'expense',
        emoji: '🏷️',
      );
      await tester.pumpWidget(_wrap(category));

      expect(find.text('🏷️'), findsOneWidget);
    });

    testWidgets('emoji appears left of the category name', (WidgetTester tester) async {
      final category = Category(
        categoryId: 3,
        name: 'Travel',
        type: 'income',
        emoji: '🍔',
      );
      await tester.pumpWidget(_wrap(category));

      final emojiPos = tester.getTopLeft(find.text('🍔'));
      final namePos = tester.getTopLeft(find.text('Travel'));
      expect(emojiPos.dx, lessThan(namePos.dx));
    });
  });
}
