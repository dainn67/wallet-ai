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

      // Emoji text is present
      expect(find.text('🍔'), findsOneWidget);

      // Direction icon is still present (complementary signal)
      expect(find.byIcon(Icons.arrow_outward_rounded), findsOneWidget);
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

    testWidgets('emoji Text appears before the direction icon in the Row', (WidgetTester tester) async {
      final category = Category(
        categoryId: 3,
        name: 'Travel',
        type: 'income',
        emoji: '🍔',
      );
      await tester.pumpWidget(_wrap(category));

      final emojiText = find.text('🍔');
      final directionIcon = find.byIcon(Icons.call_received_rounded);

      expect(emojiText, findsOneWidget);
      expect(directionIcon, findsOneWidget);

      // The emoji widget should appear before (left of) the direction icon.
      final emojiPos = tester.getTopLeft(emojiText);
      final iconPos = tester.getTopLeft(directionIcon);
      expect(emojiPos.dx, lessThan(iconPos.dx));
    });
  });
}
