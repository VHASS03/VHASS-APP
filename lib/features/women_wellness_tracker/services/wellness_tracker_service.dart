import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/api_service.dart';
import '../constants/wellness_constants.dart';
import '../models/period_log.dart';
import '../models/daily_log.dart';
import '../models/cycle_data.dart';
import '../models/wellness_settings.dart';

/// Core data service for the Women Wellness Tracker.
///
/// Scoped to the logged-in user via [StorageService.getUserId].
/// Uses SharedPreferences for offline-first storage and automatically
/// syncs with the Node.js backend (/api/wellness).
class WellnessTrackerService {
  WellnessTrackerService._();
  static final WellnessTrackerService _instance = WellnessTrackerService._();
  static WellnessTrackerService get instance => _instance;

  // ─── USER SCOPING ──────────────────────────

  /// Get the current user's ID. Returns empty string if not logged in.
  static Future<String> _userId() async {
    return await StorageService.getUserId() ?? '';
  }

  // ─── BACKEND SYNC ──────────────────────────

  /// Fetch full wellness profile from backend and update local cache.
  static Future<void> fetchFromBackend() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>('/wellness');
      if (response.success && response.data != null && response.data!['data'] != null) {
        final data = response.data!['data'] as Map<String, dynamic>;
        final uid = await _userId();
        if (uid.isEmpty) return;

        final prefs = await SharedPreferences.getInstance();

        // 1. Settings
        final settings = WellnessSettings(
          cycleLength: (data['cycleLength'] as num?)?.toInt() ?? 28,
          periodLength: (data['periodLength'] as num?)?.toInt() ?? 5,
          lastPeriodDate: data['lastPeriodDate'] != null ? DateTime.tryParse(data['lastPeriodDate'] as String) : null,
          healthCondition: data['healthCondition'] ?? 'None',
        );
        await prefs.setString('${WellnessKeys.settings}$uid', jsonEncode(settings.toJson()));
        if (data['setupDone'] == true) {
          await prefs.setBool('${WellnessKeys.onboarded}$uid', true);
        }

        // 2. Period Logs
        if (data['periodLogs'] != null) {
          final List<dynamic> pLogs = data['periodLogs'];
          final parsedPeriodLogs = pLogs.map((e) => PeriodLog.fromJson(e as Map<String, dynamic>)).toList();
          await prefs.setString('${WellnessKeys.periodLogs}$uid', jsonEncode(parsedPeriodLogs.map((l) => l.toJson()).toList()));
        }

        // 3. Daily Logs
        if (data['dailyLogs'] != null) {
          final List<dynamic> dLogs = data['dailyLogs'];
          final parsedDailyLogs = dLogs.map((e) => DailyLog.fromJson(e as Map<String, dynamic>)).toList();
          await prefs.setString('${WellnessKeys.dailyLogs}$uid', jsonEncode(parsedDailyLogs.map((l) => l.toJson()).toList()));
        }

        // 4. Cycle History
        if (data['cycleHistory'] != null) {
          final List<dynamic> cHistory = data['cycleHistory'];
          final parsedCycles = cHistory.map((e) {
            final start = DateTime.parse(e['startDate'] as String);
            final periodLen = (e['periodLength'] as num?)?.toInt() ?? 5;
            final end = e['endDate'] != null
                ? (DateTime.tryParse(e['endDate'] as String) ?? start.add(Duration(days: periodLen)))
                : start.add(Duration(days: periodLen));
            return CycleData(
              startDate: start,
              endDate: end,
              cycleLength: (e['cycleLength'] as num?)?.toInt() ?? 28,
              periodLength: periodLen,
            );
          }).toList();
          await prefs.setString('${WellnessKeys.cycleHistory}$uid', jsonEncode(parsedCycles.map((c) => c.toJson()).toList()));
        }

        print('✅ [WWT] Fetched and updated wellness data from backend');
      }
    } catch (e) {
      print('⚠️ [WWT] Backend fetch failed, falling back to local storage: $e');
    }
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

    // Sync to backend
    try {
      await ApiService.post('/wellness/period-log', {
        'date': log.date.toIso8601String(),
        'endDate': log.endDate?.toIso8601String(),
        'flow': log.flow?.name,
        'symptoms': log.symptoms.map((s) => s.name).toList(),
        'notes': log.notes,
      });
    } catch (e) {
      print('⚠️ [WWT] Async backend period log sync error: $e');
    }
  }

  /// Delete a period log for a specific date.
  static Future<void> deletePeriodLog(DateTime date) async {
    final logs = await getPeriodLogs();
    final dateKey = _dateKey(date);
    logs.removeWhere((l) => _dateKey(l.date) == dateKey);
    await savePeriodLogs(logs);

    // Sync to backend
    try {
      await ApiService.delete('/wellness/period-log/${_dateKey(date)}');
    } catch (e) {
      print('⚠️ [WWT] Async backend period log delete error: $e');
    }
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

    // Sync to backend
    try {
      await ApiService.post('/wellness/daily-log', {
        'date': log.date.toIso8601String(),
        'mood': log.mood?.name,
        'energyLevel': log.energyLevel,
        'symptoms': log.symptoms.map((s) => s.name).toList(),
        'notes': log.notes,
        'waterIntake': log.waterIntakeMl,
      });
    } catch (e) {
      print('⚠️ [WWT] Async backend daily log sync error: $e');
    }
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

    // Sync settings to backend
    try {
      await ApiService.put('/wellness/settings', {
        'cycleLength': settings.cycleLength,
        'periodLength': settings.periodLength,
        'lastPeriodDate': settings.lastPeriodDate?.toIso8601String(),
        'healthCondition': settings.healthCondition,
      });
    } catch (e) {
      print('⚠️ [WWT] Async backend settings sync error: $e');
    }
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

    // Sync onboarding state to backend
    try {
      await ApiService.put('/wellness/settings', {
        'setupDone': value,
      });
    } catch (e) {
      print('⚠️ [WWT] Async backend onboarding sync error: $e');
    }
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

  // ─── ENUM STRING HELPERS ───────────────────

  static FlowIntensity? _parseFlow(dynamic flowVal) {
    if (flowVal == null) return null;
    final str = flowVal.toString().toLowerCase();
    return FlowIntensity.values.firstWhere(
      (e) => e.name == str,
      orElse: () => FlowIntensity.medium,
    );
  }

  static List<SymptomType> _parseSymptoms(dynamic symptomsVal) {
    if (symptomsVal == null || symptomsVal is! List) return [];
    return symptomsVal.map((s) {
      final str = s.toString().toLowerCase();
      return SymptomType.values.firstWhere(
        (e) => e.name.toLowerCase() == str,
        orElse: () => SymptomType.other,
      );
    }).toList();
  }

  static MoodType? _parseMood(dynamic moodVal) {
    if (moodVal == null) return null;
    final str = moodVal.toString().toLowerCase();
    return MoodType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => MoodType.neutral,
    );
  }
}
