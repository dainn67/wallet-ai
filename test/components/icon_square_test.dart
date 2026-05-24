import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/components/icon_square.dart';
import 'package:wallet_ai/configs/app_theme.dart';

void main() {
  group('IconSquare', () {
    testWidgets('renders a Container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IconSquare(
              icon: Icons.home,
              tint: Color(0xFF8B5CF6),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsWidgets);
    });

    test('default size property equals AppSpacing.iconSquare', () {
      const widget = IconSquare(
        icon: Icons.home,
        tint: Color(0xFF8B5CF6),
      );

      expect(widget.size, equals(AppSpacing.iconSquare));
      expect(widget.size, equals(40.0));
    });

    testWidgets('light tint uses full tint color for icon', (tester) async {
      const lightTint = Colors.yellow;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IconSquare(
              icon: Icons.star,
              tint: lightTint,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, equals(lightTint));
    });
  });
}
