import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/configs/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light() returns non-null ThemeData', () {
      final theme = AppTheme.light();
      expect(theme, isNotNull);
    });

    testWidgets('AppSemanticColors is non-null inside MaterialApp', (tester) async {
      AppSemanticColors? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              captured = Theme.of(context).extension<AppSemanticColors>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, isNotNull);
    });
  });

  group('AppSemanticColors', () {
    const semanticColors = AppSemanticColors(
      incomeGreen: Color(0xFF22C172),
      expenseRed: Color(0xFFEF4444),
      transferTint: AppColors.primary,
      categoryAccents: [
        Color(0xFF8B5CF6),
        Color(0xFF3B82F6),
        Color(0xFFF97316),
        Color(0xFFEC4899),
        Color(0xFF10B981),
        Color(0xFF64748B),
      ],
    );

    test('incomeGreen equals Color(0xFF22C172)', () {
      expect(semanticColors.incomeGreen, equals(const Color(0xFF22C172)));
    });

    test('expenseRed equals Color(0xFFEF4444)', () {
      expect(semanticColors.expenseRed, equals(const Color(0xFFEF4444)));
    });

    test('copyWith mutates incomeGreen correctly', () {
      final mutated = semanticColors.copyWith(incomeGreen: Colors.red);
      expect(mutated.incomeGreen, equals(Colors.red));
    });

    test('copyWith preserves unchanged fields', () {
      final mutated = semanticColors.copyWith(incomeGreen: Colors.red);
      expect(mutated.expenseRed, equals(semanticColors.expenseRed));
      expect(mutated.transferTint, equals(semanticColors.transferTint));
    });

    test('lerp with null other returns this', () {
      final result = semanticColors.lerp(null, 0.5);
      expect(result.incomeGreen, equals(semanticColors.incomeGreen));
      expect(result.expenseRed, equals(semanticColors.expenseRed));
    });

    test('lerp at t=0.0 returns fields matching a', () {
      const targetIncomeGreen = Color(0xFF0000FF);
      const targetExpenseRed = Color(0xFF00FF00);
      const other = AppSemanticColors(
        incomeGreen: targetIncomeGreen,
        expenseRed: targetExpenseRed,
        transferTint: Color(0xFFFF6600),
        categoryAccents: [
          Color(0xFFFF0000),
          Color(0xFF0000FF),
          Color(0xFF00FF00),
          Color(0xFFFFFF00),
          Color(0xFF800080),
          Color(0xFF008080),
        ],
      );
      final result = semanticColors.lerp(other, 0.0);
      expect(result.incomeGreen, equals(semanticColors.incomeGreen));
      expect(result.expenseRed, equals(semanticColors.expenseRed));
    });

    test('lerp at t=1.0 returns fields matching b', () {
      const targetIncomeGreen = Color(0xFF0000FF);
      const targetExpenseRed = Color(0xFF00FF00);
      const other = AppSemanticColors(
        incomeGreen: targetIncomeGreen,
        expenseRed: targetExpenseRed,
        transferTint: Color(0xFFFF6600),
        categoryAccents: [
          Color(0xFFFF0000),
          Color(0xFF0000FF),
          Color(0xFF00FF00),
          Color(0xFFFFFF00),
          Color(0xFF800080),
          Color(0xFF008080),
        ],
      );
      final result = semanticColors.lerp(other, 1.0);
      expect(result.incomeGreen, equals(targetIncomeGreen));
      expect(result.expenseRed, equals(targetExpenseRed));
    });
  });

  group('AppColors tokens', () {
    test('primary equals Color(0xFF8B5CF6)', () {
      expect(AppColors.primary, equals(const Color(0xFF8B5CF6)));
    });

    test('tertiary equals Color(0xFFEC4899)', () {
      expect(AppColors.tertiary, equals(const Color(0xFFEC4899)));
    });
  });

  group('AppSpacing constants', () {
    test('lg equals 16', () {
      expect(AppSpacing.lg, equals(16));
    });
  });

  group('AppRadius constants', () {
    test('card equals 16', () {
      expect(AppRadius.card, equals(16));
    });

    test('pill equals 999', () {
      expect(AppRadius.pill, equals(999));
    });
  });
}
