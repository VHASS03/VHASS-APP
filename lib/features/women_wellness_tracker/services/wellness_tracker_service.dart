import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/storage_service.dart';
import '../constants/wellness_constants.dart';
import '../models/period_log.dart';
import '../models/daily_log.dart';
import '../models/cycle_data.dart';
import '../models/wellness_settings.dart';

/// Core data service for the Women Wellness Tracker.
///
/// All data is scoped to the logged-in user via [StorageService.getUserId].
/// Uses SharedPreferences for offline-first storage, following the same
/// pattern as the existing [WellnessService].
class WellnessTrackerService {
  WellnessTrackerService._();
  static final WellnessTrackerService _instance = WellnessTrackerService._();
  static WellnessTrackerService get instance => _instance;

  // ─── USER SCOPING ──────────────────────────

  /// Get the current user's ID. Returns empty string if not logged in.
  static Future<String> _userId() async {
    return await StorageService.getUserId() ?? '';
  }

  // ─── PERIOD LOGS ───────────────────────────

  /// Get all period logs for the current user.
  static Future<List<PeriodLog>> getPeriodLogs() async {
    final uid = await _userId();
    if (uid.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${WellnessKeys.periodLogs}$uid');
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => PeriodLog.fromJson(e)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      print('❌ [WWT] Error parsing period logs: $e');
      return [];
    }
  }

  /// Save all period logs for the current user.
  static Future<void> savePeriodLogs(List<PeriodLog> logs) async {
    final uid = await _userId();
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(logs.map((l) => l.toJson()).toList());
    await prefs.setString('${WellnessKeys.periodLogs}$uid', json);
  }

  /// Add or update a period log for a specific date.
  static Future<void> upsertPeriodLog(PeriodLog log) async {
    final logs = await getPeriodLogs();
    final dateKey = _dateKey(log.date);
    logs.removeWhere((l) => _dateKey(l.date) == dateKey);
    logs.add(log);
    await savePeriodLogs(logs);
  }

  /// Delete a period log for a specific date.
  static Future<void> deletePeriodLog(DateTime date) async {
    final logs = await getPeriodLogs();
    final dateKey = _dateKey(date);
    logs.removeWhere((l) => _dateKey(l.date) == dateKey);
    await savePeriodLogs(logs);
  }

  /// Get period log for a specific date.
  static Future<PeriodLog?> getPeriodLogForDate(DateTime date) async {
    final logs = await getPeriodLogs();
    final dateKey = _dateKey(date);
    try {
      return logs.firstWhere((l) => _dateKey(l.date) == dateKey);
    } catch (_) {
      return null;
    }
  }

  // ─── DAILY LOGS ────────────────────────────

  /// Get all daily logs for the current user.
  static Future<List<DailyLog>> getDailyLogs() async {
    final uid = await _userId();
    if (uid.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${WellnessKeys.dailyLogs}$uid');
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => DailyLog.fromJson(e)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      print('❌ [WWT] Error parsing daily logs: $e');
      return [];
    }
  }

  /// Save all daily logs for the current user.
  static Future<void> saveDailyLogs(List<DailyLog> logs) async {
    final uid = await _userId();
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(logs.map((l) => l.toJson()).toList());
    await prefs.setString('${WellnessKeys.dailyLogs}$uid', json);
  }

  /// Add or update a daily log for a specific date.
  static Future<void> upsertDailyLog(DailyLog log) async {
    final logs = await getDailyLogs();
    final dateKey = _dateKey(log.date);
    logs.removeWhere((l) => _dateKey(l.date) == dateKey);
    logs.add(log);
    await saveDailyLogs(logs);
  }

  /// Get daily log for a specific date.
  static Future<DailyLog?> getDailyLogForDate(DateTime date) async {
    final logs = await getDailyLogs();
    final dateKey = _dateKey(date);
    try {
      return logs.firstWhere((l) => _dateKey(l.date) == dateKey);
    } catch (_) {
      return null;
    }
  }

  // ─── CYCLE HISTORY ─────────────────────────

  /// Get all cycle history for the current user.
  static Future<List<CycleData>> getCycleHistory() async {
    final uid = await _userId();
    if (uid.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${WellnessKeys.cycleHistory}$uid');
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => CycleData.fromJson(e)).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
    } catch (e) {
      print('❌ [WWT] Error parsing cycle history: $e');
      return [];
    }
  }

  /// Save cycle history.
  static Future<void> saveCycleHistory(List<CycleData> cycles) async {
    final uid = await _userId();
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(cycles.map((c) => c.toJson()).toList());
    await prefs.setString('${WellnessKeys.cycleHistory}$uid', json);
  }

  /// Add a new cycle record.
  static Future<void> addCycle(CycleData cycle) async {
    final cycles = await getCycleHistory();
    cycles.add(cycle);
    await saveCycleHistory(cycles);
  }

  // ─── SETTINGS ──────────────────────────────

  /// Get user wellness settings.
  static Future<WellnessSettings> getSettings() async {
    final uid = await _userId();
    if (uid.isEmpty) return WellnessSettings();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${WellnessKeys.settings}$uid');
    if (raw == null || raw.isEmpty) return WellnessSettings();
    try {
      return WellnessSettings.fromJson(jsonDecode(raw));
    } catch (e) {
      print('❌ [WWT] Error parsing settings: $e');
      return WellnessSettings();
    }
  }

  /// Save user wellness settings.
  static Future<void> saveSettings(WellnessSettings settings) async {
    final uid = await _userId();
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${WellnessKeys.settings}$uid',
      jsonEncode(settings.toJson()),
    );
  }

  // ─── ONBOARDING ────────────────────────────

  /// Check if the user has completed onboarding.
  static Future<bool> isOnboarded() async {
    final uid = await _userId();
    if (uid.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${WellnessKeys.onboarded}$uid') ?? false;
  }

  /// Mark onboarding as complete.
  static Future<void> setOnboarded(bool value) async {
    final uid = await _userId();
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${WellnessKeys.onboarded}$uid', value);
  }

  // ─── DATA MANAGEMENT ──────────────────────

  /// Clear all wellness tracker data for the current user.
  static Future<void> clearAllData() async {
    final uid = await _userId();
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${WellnessKeys.periodLogs}$uid');
    await prefs.remove('${WellnessKeys.dailyLogs}$uid');
    await prefs.remove('${WellnessKeys.cycleHistory}$uid');
    await prefs.remove('${WellnessKeys.settings}$uid');
    await prefs.remove('${WellnessKeys.onboarded}$uid');
    print('🧹 [WWT] Cleared all wellness tracker data for user $uid');
  }

  // ─── HELPERS ───────────────────────────────

  /// Normalize a DateTime to date-only string key (yyyy-MM-dd).
  static String _dateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
