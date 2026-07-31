import '../constants/wellness_constants.dart';
import '../models/cycle_data.dart';
import '../models/daily_log.dart';
import '../models/period_log.dart';
import '../utils/cycle_calculator.dart';

/// Local rule-based insights engine — no external AI API required.
///
/// Analyses logged data to generate intelligent, personalised health insights.
class InsightsEngine {
  InsightsEngine._();

  /// Generate all applicable insights from the user's data.
  static List<HealthInsight> generateInsights({
    required List<CycleData> cycleHistory,
    required List<PeriodLog> periodLogs,
    required List<DailyLog> dailyLogs,
    required int cycleLength,
    required int periodLength,
  }) {
    final List<HealthInsight> insights = [];

    // ── Cycle regularity ──
    insights.addAll(_cycleRegularityInsights(cycleHistory));

    // ── Average stats ──
    insights.addAll(_averageInsights(cycleHistory, cycleLength));

    // ── Symptom patterns ──
    insights.addAll(_symptomInsights(periodLogs));

    // ── Mood patterns ──
    insights.addAll(_moodInsights(dailyLogs));

    // ── Hydration / sleep ──
    insights.addAll(_lifestyleInsights(dailyLogs));

    // ── Ovulation ──
    insights.addAll(_ovulationInsights(cycleHistory, cycleLength));

    // ── Fallback if no data ──
    if (insights.isEmpty) {
      insights.add(HealthInsight(
        title: 'Start Logging',
        body: 'Log your period and daily wellness to unlock personalised health insights!',
        icon: '📝',
        category: InsightCategory.general,
      ));
    }

    return insights;
  }

  // ─── CYCLE REGULARITY ─────────────────────

  static List<HealthInsight> _cycleRegularityInsights(List<CycleData> history) {
    final List<HealthInsight> results = [];
    final actual = history.where((c) => !c.predicted).toList();
    if (actual.length < 2) return results;

    final lengths = actual.map((c) => c.cycleLength).toList();
    final variance = _variance(lengths);

    if (variance < 4) {
      results.add(HealthInsight(
        title: 'Regular Cycle',
        body: 'Your cycle has been very regular. Great consistency!',
        icon: '✅',
        category: InsightCategory.cycle,
      ));
    } else if (variance > 10) {
      results.add(HealthInsight(
        title: 'Irregular Cycle',
        body: 'Your cycle length has been varying significantly. Consider speaking to a doctor if this persists.',
        icon: '⚠️',
        category: InsightCategory.cycle,
      ));
    }

    return results;
  }

  // ─── AVERAGES ─────────────────────────────

  static List<HealthInsight> _averageInsights(List<CycleData> history, int settingsCycleLength) {
    final List<HealthInsight> results = [];
    final avgCycle = CycleCalculator.averageCycleLength(history);
    final avgPeriod = CycleCalculator.averagePeriodLength(history);

    if (history.isNotEmpty) {
      results.add(HealthInsight(
        title: 'Your Averages',
        body: 'Average cycle: ${avgCycle.toStringAsFixed(1)} days. Average period: ${avgPeriod.toStringAsFixed(1)} days.',
        icon: '📊',
        category: InsightCategory.cycle,
      ));
    }

    if (avgCycle > 35) {
      results.add(HealthInsight(
        title: 'Long Cycles',
        body: 'Your average cycle is longer than typical (21-35 days). This is sometimes normal but worth monitoring.',
        icon: '📅',
        category: InsightCategory.cycle,
      ));
    }

    return results;
  }

  // ─── SYMPTOM PATTERNS ─────────────────────

  static List<HealthInsight> _symptomInsights(List<PeriodLog> logs) {
    final List<HealthInsight> results = [];
    if (logs.length < 3) return results;

    // Count symptom frequency
    final Map<SymptomType, int> freq = {};
    for (final log in logs) {
      for (final s in log.symptoms) {
        freq[s] = (freq[s] ?? 0) + 1;
      }
    }

    // Most common symptom
    if (freq.isNotEmpty) {
      final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      results.add(HealthInsight(
        title: 'Most Common Symptom',
        body: '${symptomLabels[top.key]} appears in ${((top.value / logs.length) * 100).round()}% of your period days.',
        icon: '🔍',
        category: InsightCategory.symptoms,
      ));
    }

    // Pain trend
    final painLogs = logs.where((l) => l.painLevel > 0).toList();
    if (painLogs.length >= 3) {
      final avgPain = painLogs.fold<int>(0, (s, l) => s + l.painLevel) / painLogs.length;
      if (avgPain > 6) {
        results.add(HealthInsight(
          title: 'High Pain Levels',
          body: 'Your average pain is ${avgPain.toStringAsFixed(1)}/10. Consider heat therapy, gentle exercise, or consult a doctor.',
          icon: '💊',
          category: InsightCategory.symptoms,
        ));
      }
    }

    return results;
  }

  // ─── MOOD PATTERNS ────────────────────────

  static List<HealthInsight> _moodInsights(List<DailyLog> logs) {
    final List<HealthInsight> results = [];
    final moodLogs = logs.where((l) => l.mood != null).toList();
    if (moodLogs.length < 5) return results;

    final Map<MoodType, int> freq = {};
    for (final log in moodLogs) {
      freq[log.mood!] = (freq[log.mood!] ?? 0) + 1;
    }

    if (freq.isNotEmpty) {
      final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      results.add(HealthInsight(
        title: 'Mood Trend',
        body: 'You\'ve felt ${moodLabels[top.key]?.toLowerCase()} most often (${((top.value / moodLogs.length) * 100).round()}% of logged days).',
        icon: moodEmojis[top.key] ?? '😊',
        category: InsightCategory.mood,
      ));
    }

    return results;
  }

  // ─── LIFESTYLE ────────────────────────────

  static List<HealthInsight> _lifestyleInsights(List<DailyLog> logs) {
    final List<HealthInsight> results = [];
    final waterLogs = logs.where((l) => l.waterIntakeMl > 0).toList();
    final sleepLogs = logs.where((l) => l.sleepHours != null && l.sleepHours! > 0).toList();

    if (waterLogs.length >= 3) {
      final avgWater = waterLogs.fold<int>(0, (s, l) => s + l.waterIntakeMl) / waterLogs.length;
      if (avgWater < 1500) {
        results.add(HealthInsight(
          title: 'Hydration Alert',
          body: 'Your average water intake is ${avgWater.round()}ml. Aim for at least 2000ml/day for better cycle health.',
          icon: '💧',
          category: InsightCategory.lifestyle,
        ));
      }
    }

    if (sleepLogs.length >= 3) {
      final avgSleep = sleepLogs.fold<double>(0, (s, l) => s + l.sleepHours!) / sleepLogs.length;
      if (avgSleep < 7) {
        results.add(HealthInsight(
          title: 'Sleep Pattern',
          body: 'You\'re averaging ${avgSleep.toStringAsFixed(1)} hours of sleep. 7-9 hours is recommended, especially during PMS.',
          icon: '😴',
          category: InsightCategory.lifestyle,
        ));
      }
    }

    return results;
  }

  // ─── OVULATION ────────────────────────────

  static List<HealthInsight> _ovulationInsights(List<CycleData> history, int cycleLength) {
    final List<HealthInsight> results = [];
    if (history.isEmpty) return results;

    final ovDay = cycleLength - 14;
    results.add(HealthInsight(
      title: 'Ovulation Pattern',
      body: 'Based on your cycle, you typically ovulate around Day $ovDay. Track symptoms like clear discharge or mild cramps.',
      icon: '🌟',
      category: InsightCategory.fertility,
    ));

    return results;
  }

  // ─── MATH HELPERS ─────────────────────────

  static double _variance(List<int> values) {
    if (values.length < 2) return 0;
    final mean = values.fold<int>(0, (s, v) => s + v) / values.length;
    final sumSqDiff = values.fold<double>(0, (s, v) => s + (v - mean) * (v - mean));
    return sumSqDiff / values.length;
  }
}

/// A single health insight to display to the user.
class HealthInsight {
  final String title;
  final String body;
  final String icon;
  final InsightCategory category;

  const HealthInsight({
    required this.title,
    required this.body,
    required this.icon,
    required this.category,
  });
}

/// Categories for organising insights.
enum InsightCategory { cycle, symptoms, mood, lifestyle, fertility, general }
