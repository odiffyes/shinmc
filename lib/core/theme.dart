import 'package:material_ui/material_ui.dart';

/// Minimal iOS-like palette (spec §11). Pink is reserved for period data.
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const text = Color(0xFF1C1C1E);
  static const secondaryText = Color(0xFF8E8E93);
  static const separator = Color(0xFFE5E5EA);
  static const sunday = Color(0xFFE5484D);

  /// Actual start date: full, strong pink cell (§3.2).
  static const actualStart = Color(0xFFEC407A);

  /// Other actual period days.
  static const actual = Color(0xFFF7A1BF);

  /// Predicted days: light fill + thin border, so they read differently
  /// from actual days even without colour perception.
  static const predictedFill = Color(0xFFFDEEF3);
  static const predictedBorder = Color(0xFFF5B8CC);
  static const predictedText = Color(0xFFC2185B);
}

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.actualStart,
      surface: AppColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
