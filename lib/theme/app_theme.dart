import 'package:flutter/material.dart';
import '../core/colors.dart';

// Update: Now accepts Brightness
ThemeData appTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: isDark ? AppColors.background : Colors.white,
    fontFamily: 'Inter',
    
    // Using colorScheme ensures system components (buttons, etc.) react correctly
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      surface: isDark ? const Color(0xFF16161E) : Colors.white,
    ),

    // Define Global Text Styles
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: isDark ? Colors.white : Colors.black),
      bodyMedium: TextStyle(color: isDark ? AppColors.textSecondary : Colors.black87),
      titleMedium: TextStyle(color: isDark ? Colors.white : Colors.black),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.background : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black, // Icons & Text color
      elevation: 0,
    ),

    // This ensures cards use the right color automatically
    cardColor: isDark ? const Color(0xFF16161E) : Colors.white,
  );
}