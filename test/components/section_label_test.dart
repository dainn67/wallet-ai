import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/components/section_label.dart';
import 'package:wallet_ai/configs/app_theme.dart';

void main() {
  group('SectionLabel', () {
    testWidgets('renders text uppercased', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionLabel('today'),
          ),
        ),
      );

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('today'), findsNothing);
    });

    testWidgets('text style color is AppColors.onSurfaceVariant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SectionLabel('section'),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.style?.color, equals(AppColors.onSurfaceVariant));
    });
  });
}
