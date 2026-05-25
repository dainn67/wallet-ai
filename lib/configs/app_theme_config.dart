import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const primary = Color(0xFF8B5CF6);
  static const secondary = Color(0xFFF9FAFB);
  static const tertiary = Color(0xFFEC4899);
  static const neutral = Color(0xFF1F2937);

  // Derived surface / text tokens
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF9FAFB);
  static const onSurface = Color(0xFF1F2937);
  static const onSurfaceVariant = Color(0xFF6B7280);
  static const outline = Color(0xFFE5E7EB);

  // Semantic
  static const incomeGreen = Color(0xFF22C172);
  static const expenseRed = Color(0xFFEF4444);
}

abstract final class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.tertiary,
      onSecondary: Colors.white,
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.secondary,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      error: Color(0xFFEF4444),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'PlusJakartaSans',
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'PlusJakartaSans',
        ),
        iconTheme: IconThemeData(color: AppColors.onSurface),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary),
          shape: StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondary,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle: TextStyle(color: AppColors.onSurface, fontFamily: 'PlusJakartaSans'),
        side: BorderSide(color: AppColors.outline),
        shape: StadiumBorder(),
      ),
    );
  }
}
