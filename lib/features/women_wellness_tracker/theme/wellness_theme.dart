import 'package:flutter/material.dart';
import '../../../core/colors.dart';

/// Module-specific color tokens and styles for Women Wellness Tracker.
class WellnessTheme {
  // ─── PHASE COLORS ──────────────────────────
  static const Color menstrual = Color(0xFFE8475E);
  static const Color follicular = Color(0xFF7ED8C4);
  static const Color ovulation = Color(0xFFF7A7B8);
  static const Color luteal = Color(0xFFC59BF2);

  // ─── CALENDAR COLORS ───────────────────────
  static const Color periodDay = Color(0xFFE8475E);
  static const Color predictedPeriod = Color(0xFFFFB7A6);
  static const Color fertileDay = Color(0xFF7ED8C4);
  static const Color ovulationDay = Color(0xFF4FC3F7);
  static const Color today = AppColors.primary;

  // ─── GRADIENT PAIRS ────────────────────────
  static const List<Color> dashboardGradient = [
    Color(0xFFE8709A),
    Color(0xFFC59BF2),
  ];

  static const List<Color> periodGradient = [
    Color(0xFFE8475E),
    Color(0xFFF7A7B8),
  ];

  static const List<Color> fertileGradient = [
    Color(0xFF7ED8C4),
    Color(0xFF4FC3F7),
  ];

  static const List<Color> ovulationGradient = [
    Color(0xFF4FC3F7),
    Color(0xFF7ED8C4),
  ];

  // ─── MOOD COLORS ──────────────────────────
  static const Color moodHappy = Color(0xFFFFD54F);
  static const Color moodSad = Color(0xFF90CAF9);
  static const Color moodAngry = Color(0xFFEF5350);
  static const Color moodCalm = Color(0xFF81C784);
  static const Color moodNeutral = Color(0xFFBDBDBD);

  // ─── FLOW COLORS ──────────────────────────
  static const Color flowLight = Color(0xFFF7A7B8);
  static const Color flowMedium = Color(0xFFE8709A);
  static const Color flowHeavy = Color(0xFFE8475E);
  static const Color flowVeryHeavy = Color(0xFFC62828);
  static const Color flowSpotting = Color(0xFFFFCDD2);

  // ─── TEXT STYLES ──────────────────────────
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );

  static const TextStyle bigNumber = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  // ─── DECORATIONS ──────────────────────────

  /// Standard card decoration
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.grey.withOpacity(isDark ? 0.15 : 0.08),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Gradient card decoration
  static BoxDecoration gradientCard(List<Color> colors) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: colors.first.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
