import '../constants/wellness_constants.dart';
import '../models/cycle_data.dart';
import '../models/period_log.dart';

/// Medically-accepted menstrual cycle calculations.
///
/// Standard medical formula:
/// - Ovulation = cycle length − 14
/// - Fertile window = 5 days before ovulation + ovulation day (6 total)
/// - Phases: menstrual → follicular → ovulation → luteal
class CycleCalculator {
  CycleCalculator._();

  // ─── CURRENT STATE ─────────────────────────

  /// Calculate which day of the current cycle the user is on (1-based).
  /// Returns 0 if no period start date is available.
  static int currentCycleDay(DateTime lastPeriodStart) {
    final today = _normalise(DateTime.now());
    final start = _normalise(lastPeriodStart);
    final diff = today.difference(start).inDays;
    return diff >= 0 ? diff + 1 : 0;
  }

  /// Determine the current cycle phase.
  static CyclePhase currentPhase(DateTime lastPeriodStart, int cycleLength, int periodLength) {
    final day = currentCycleDay(lastPeriodStart);
    if (day <= 0) return CyclePhase.follicular;
    return phaseForDay(day, cycleLength, periodLength);
  }

  /// Get the phase for a specific cycle day.
  static CyclePhase phaseForDay(int day, int cycleLength, int periodLength) {
    if (day <= periodLength) return CyclePhase.menstrual;
    final ovulationDay = cycleLength - 14;
    if (day < ovulationDay - 2) return CyclePhase.follicular;
    if (day <= ovulationDay + 1) return CyclePhase.ovulation;
    return CyclePhase.luteal;
  }

  // ─── PREDICTIONS ───────────────────────────

  /// Predict the next period start date.
  static DateTime nextPeriodDate(DateTime lastPeriodStart, int cycleLength) {
    return _normalise(lastPeriodStart).add(Duration(days: cycleLength));
  }

  /// Days remaining until next period.
  static int daysUntilNextPeriod(DateTime lastPeriodStart, int cycleLength) {
    final next = nextPeriodDate(lastPeriodStart, cycleLength);
    final today = _normalise(DateTime.now());
    return next.difference(today).inDays;
  }

  /// Predict the ovulation date for the current cycle.
  static DateTime ovulationDate(DateTime lastPeriodStart, int cycleLength) {
    final ovDay = cycleLength - 14;
    return _normalise(lastPeriodStart).add(Duration(days: ovDay - 1));
  }

  /// Days until ovulation.
  static int daysUntilOvulation(DateTime lastPeriodStart, int cycleLength) {
    final ov = ovulationDate(lastPeriodStart, cycleLength);
    final today = _normalise(DateTime.now());
    return ov.difference(today).inDays;
  }

  /// Get the fertile window (6 days: 5 before ovulation + ovulation day).
  static DateRange fertileWindow(DateTime lastPeriodStart, int cycleLength) {
    final ov = ovulationDate(lastPeriodStart, cycleLength);
    return DateRange(
      start: ov.subtract(const Duration(days: 5)),
      end: ov,
    );
  }

  /// Predict the next N cycles' start dates.
  static List<DateTime> predictNextCycles(DateTime lastPeriodStart, int cycleLength, {int count = 12}) {
    final List<DateTime> predictions = [];
    var current = _normalise(lastPeriodStart);
    for (int i = 0; i < count; i++) {
      current = current.add(Duration(days: cycleLength));
      predictions.add(current);
    }
    return predictions;
  }

  // ─── AVERAGES ──────────────────────────────

  /// Calculate average cycle length from history.
  static double averageCycleLength(List<CycleData> history) {
    if (history.isEmpty) return 28;
    final actual = history.where((c) => !c.predicted).toList();
    if (actual.isEmpty) return 28;
    final total = actual.fold<int>(0, (sum, c) => sum + c.cycleLength);
    return total / actual.length;
  }

  /// Calculate average period (bleeding) length from history.
  static double averagePeriodLength(List<CycleData> history) {
    if (history.isEmpty) return 5;
    final actual = history.where((c) => !c.predicted).toList();
    if (actual.isEmpty) return 5;
    final total = actual.fold<int>(0, (sum, c) => sum + c.periodLength);
    return total / actual.length;
  }

  /// Prediction confidence based on amount of logged data (0.0 - 1.0).
  static double predictionConfidence(List<CycleData> history) {
    final actual = history.where((c) => !c.predicted).length;
    if (actual == 0) return 0.5; // Default guess
    if (actual >= 6) return 0.96;
    if (actual >= 3) return 0.85;
    return 0.7;
  }

  // ─── CALENDAR HELPERS ─────────────────────

  /// Check if a given date falls within a period (bleeding days).
  static bool isPeriodDay(DateTime date, DateTime lastPeriodStart, int periodLength, int cycleLength) {
    final norm = _normalise(date);
    final start = _normalise(lastPeriodStart);
    final diff = norm.difference(start).inDays;
    if (diff < 0) return false;
    final dayInCycle = diff % cycleLength;
    return dayInCycle < periodLength;
  }

  /// Check if a given date falls within the fertile window.
  static bool isFertileDay(DateTime date, DateTime lastPeriodStart, int cycleLength) {
    final fw = fertileWindow(lastPeriodStart, cycleLength);
    final norm = _normalise(date);
    return !norm.isBefore(fw.start) && !norm.isAfter(fw.end);
  }

  /// Check if a given date is the predicted ovulation day.
  static bool isOvulationDay(DateTime date, DateTime lastPeriodStart, int cycleLength) {
    final ov = ovulationDate(lastPeriodStart, cycleLength);
    return _dateKey(date) == _dateKey(ov);
  }

  /// Get all period days between two dates (for calendar rendering).
  static Set<String> periodDaysBetween(
    DateTime from,
    DateTime to,
    DateTime lastPeriodStart,
    int periodLength,
    int cycleLength,
  ) {
    final Set<String> days = {};
    var current = _normalise(from);
    final end = _normalise(to);
    while (!current.isAfter(end)) {
      if (isPeriodDay(current, lastPeriodStart, periodLength, cycleLength)) {
        days.add(_dateKey(current));
      }
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  /// Get all fertile days between two dates.
  static Set<String> fertileDaysBetween(
    DateTime from,
    DateTime to,
    DateTime lastPeriodStart,
    int cycleLength,
  ) {
    final Set<String> days = {};
    var current = _normalise(from);
    final end = _normalise(to);
    while (!current.isAfter(end)) {
      if (isFertileDay(current, lastPeriodStart, cycleLength)) {
        days.add(_dateKey(current));
      }
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  /// Get set of dates that have period logs.
  static Set<String> loggedPeriodDates(List<PeriodLog> logs) {
    return logs.map((l) => _dateKey(l.date)).toSet();
  }

  // ─── PRIVATE HELPERS ──────────────────────

  static DateTime _normalise(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String _dateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

/// Simple date range helper.
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange({required this.start, required this.end});
}
