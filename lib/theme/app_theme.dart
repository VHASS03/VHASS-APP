import 'package:flutter/material.dart';
import '../core/colors.dart';

ThemeData appTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor:
        isDark ? AppColors.background : AppColors.backgroundLight,
    fontFamily: 'Inter',

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.lavender,
      surface: isDark ? const Color(0xFF1E1828) : AppColors.backgroundLight,
    ),

    textTheme: TextTheme(
      bodyLarge: TextStyle(color: isDark ? Colors.white : const Color(0xFF3A2D45)),
      bodyMedium: TextStyle(
          color: isDark ? AppColors.textSecondary : const Color(0xFF6B5A7A)),
      titleMedium: TextStyle(color: isDark ? Colors.white : const Color(0xFF3A2D45)),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor:
          isDark ? AppColors.background : AppColors.backgroundLight,
      foregroundColor: isDark ? Colors.white : const Color(0xFF3A2D45),
      elevation: 0,
    ),

    cardColor: isDark ? AppColors.card : AppColors.cardLight,
  );
}