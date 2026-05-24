import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────
// AppColors
// ──────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryContainer = Color(0xFFEDE9FE);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFF9FAFB);
  static const Color tertiary = Color(0xFFEC4899);
  static const Color neutral = Color(0xFF1F2937);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF9FAFB);
  static const Color outline = Color(0xFFE5E7EB);
  static const Color outlineVariant = Color(0xFFF3F4F6);
  static const Color onSurface = Color(0xFF1F2937);
  static const Color onSurfaceVariant = Color(0xFF6B7280);
  static const Color error = Color(0xFFEF4444);
}

// ──────────────────────────────────────────────────────
// AppSpacing
// ──────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double iconSquare = 40;
}

// ──────────────────────────────────────────────────────
// AppRadius
// ──────────────────────────────────────────────────────
class AppRadius {
  AppRadius._();

  static const double chip = 999;
  static const double pill = 999;
  static const double card = 16;
  static const double tile = 12;
  static const double input = 24;
}

// ──────────────────────────────────────────────────────
// AppElevation
// ──────────────────────────────────────────────────────
class AppElevation {
  AppElevation._();

  static const double none = 0;
  static const double card = 1;
  static const double dialog = 4;
}

// ──────────────────────────────────────────────────────
// AppTypography
// ──────────────────────────────────────────────────────
class AppTypography {
  AppTypography._();

  static TextTheme textTheme() => const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w600,
          fontSize: 57,
          letterSpacing: -0.25,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w600,
          fontSize: 28,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          letterSpacing: 0.25,
        ),
        labelLarge: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w500,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      );
}

// ──────────────────────────────────────────────────────
// AppSemanticColors
// ──────────────────────────────────────────────────────
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.incomeGreen,
    required this.expenseRed,
    required this.transferTint,
    required this.categoryAccents,
  });

  final Color incomeGreen;
  final Color expenseRed;
  final Color transferTint;
  final List<Color> categoryAccents;

  @override
  AppSemanticColors copyWith({
    Color? incomeGreen,
    Color? expenseRed,
    Color? transferTint,
    List<Color>? categoryAccents,
  }) {
    return AppSemanticColors(
      incomeGreen: incomeGreen ?? this.incomeGreen,
      expenseRed: expenseRed ?? this.expenseRed,
      transferTint: transferTint ?? this.transferTint,
      categoryAccents: categoryAccents ?? this.categoryAccents,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other == null) return this;
    final o = other as AppSemanticColors;
    return AppSemanticColors(
      incomeGreen: Color.lerp(incomeGreen, o.incomeGreen, t)!,
      expenseRed: Color.lerp(expenseRed, o.expenseRed, t)!,
      transferTint: Color.lerp(transferTint, o.transferTint, t)!,
      categoryAccents: List.generate(
        categoryAccents.length,
        (i) => Color.lerp(
          categoryAccents[i],
          i < o.categoryAccents.length ? o.categoryAccents[i] : categoryAccents[i],
          t,
        )!,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// AppTheme
// ──────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        fontFamily: 'PlusJakartaSans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          secondary: AppColors.secondary,
          tertiary: AppColors.tertiary,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          outline: AppColors.outline,
          error: AppColors.error,
        ),
        textTheme: AppTypography.textTheme(),
        extensions: const [
          AppSemanticColors(
            incomeGreen: Color(0xFF22C172),
            expenseRed: Color(0xFFEF4444),
            transferTint: AppColors.primary,
            categoryAccents: [
              Color(0xFF8B5CF6), // violet
              Color(0xFF3B82F6), // blue
              Color(0xFFF97316), // orange
              Color(0xFFEC4899), // pink
              Color(0xFF10B981), // emerald
              Color(0xFF64748B), // slate
            ],
          ),
        ],
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.onSurface,
          elevation: AppElevation.none,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primaryContainer,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: AppElevation.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          color: AppColors.surface,
          margin: EdgeInsets.zero,
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          side: const BorderSide(color: AppColors.outline),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          elevation: AppElevation.dialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          backgroundColor: AppColors.surface,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
          ),
        ),
      );
}
