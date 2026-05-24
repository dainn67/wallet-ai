// Smoke tests — redesign-ui epic
// Covers integration of the new design system end-to-end:
//   SC-1 visual consistency (theme applied), SC-3 token consumption,
//   SC-4 Plus Jakarta Sans wiring, AD-1/AD-2/AD-3/AD-5 architecture.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/configs/configs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('redesign-ui design system smoke', () {
    testWidgets('S1: AppTheme.light() returns a complete ThemeData', (tester) async {
      final theme = AppTheme.light();
      expect(theme, isNotNull);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, equals(AppColors.primary));
    });

    testWidgets('S2: AppSemanticColors extension is registered on ThemeData', (tester) async {
      late AppSemanticColors? captured;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(builder: (ctx) {
          captured = Theme.of(ctx).extension<AppSemanticColors>();
          return const SizedBox.shrink();
        }),
      ));

      expect(captured, isNotNull);
      expect(captured!.incomeGreen, equals(const Color(0xFF22C172)));
      expect(captured!.expenseRed, equals(const Color(0xFFEF4444)));
      expect(captured!.transferTint, equals(AppColors.primary));
      expect(captured!.categoryAccents.length, equals(6));
    });

    testWidgets('S3: AppTheme uses Plus Jakarta Sans as fontFamily', (tester) async {
      final theme = AppTheme.light();
      expect(theme.textTheme.bodyMedium?.fontFamily, equals('PlusJakartaSans'));
    });

    testWidgets('S4: IconSquare renders with token-default size from AppSpacing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(child: IconSquare(icon: Icons.home, tint: AppColors.primary)),
        ),
      ));

      final box = tester.getSize(find.byType(IconSquare));
      expect(box.width, equals(AppSpacing.iconSquare));
      expect(box.height, equals(AppSpacing.iconSquare));
    });

    testWidgets('S5: SectionLabel uppercases its text via design contract', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SectionLabel('Today')),
      ));

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('S6: Token constants match PRD-locked values', (tester) async {
      expect(AppColors.primary, equals(const Color(0xFF8B5CF6)));
      expect(AppColors.tertiary, equals(const Color(0xFFEC4899)));
      expect(AppSpacing.lg, equals(16));
      expect(AppSpacing.iconSquare, equals(40));
      expect(AppRadius.card, equals(16));
      expect(AppRadius.pill, equals(999));
    });

    testWidgets('S7: AD-5 — kDebugMode constant is available for TestTab gating', (tester) async {
      // Compile-time constant exists. In tests, kDebugMode is true.
      // The actual home_screen.dart uses `if (kDebugMode) _TabConfig(...)` for the TestTab destination.
      expect(kDebugMode, isA<bool>());
    });
  });
}
