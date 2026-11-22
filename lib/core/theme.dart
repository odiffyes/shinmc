import 'package:material_ui/material_ui.dart';

/// Minimal iOS-like palette (spec §11). Pink is reserved for period data.
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const text = Color(0xFF1C1C1E);
  static const secondaryText = Color(0xFF8E8E93);
  static const separator = Color(0xFFE5E5EA);

  /// Actual period days.
  static const actual = Color(0xFFF06292);

  /// Predicted period days (lighter, never confused with actual).
  static const predicted = Color(0xFFF8BBD0);
}

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.actual,
      surface: AppColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
  );
}
