import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Wellness Service for managing user-specific health data
/// Stores period tracking and health notes per user account
class WellnessService {
  static const String _prefixLastPeriodDate = 'wellness_last_period_';
  static const String _prefixCycleLength = 'wellness_cycle_length_';
  static const String _prefixPeriodLength = 'wellness_period_length_';
  static const String _prefixHealthNotes = 'wellness_health_notes_';

  /// Save last period date for user
  static Future<void> saveLastPeriodDate(String userId, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefixLastPeriodDate$userId',
      date.toIso8601String(),
    );
    print('💾 Saved last period date for user $userId: $date');
  }

  /// Get last period date for user
  static Future<DateTime?> getLastPeriodDate(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString('$_prefixLastPeriodDate$userId');
    if (dateStr != null) {
      final date = DateTime.parse(dateStr);
      print('📖 Retrieved last period date for user $userId: $date');
      return date;
    }
    return null;
  }

  /// Save cycle length for user (default 28 days)
  static Future<void> saveCycleLength(String userId, int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefixCycleLength$userId', days);
    print('💾 Saved cycle length for user $userId: $days days');
  }

  /// Get cycle length for user
  static Future<int> getCycleLength(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefixCycleLength$userId') ?? 28; // Default 28 days
  }

  /// Save period length for user (default 5 days)
  static Future<void> savePeriodLength(String userId, int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefixPeriodLength$userId', days);
    print('💾 Saved period length for user $userId: $days days');
  }

  /// Get period length for user
  static Future<int> getPeriodLength(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefixPeriodLength$userId') ?? 5; // Default 5 days
  }

  /// Save health notes for user
  /// Each note is a map with 'date' (ISO string) and 'note' (text)
  static Future<void> saveHealthNotes(
    String userId,
    List<Map<String, dynamic>> notes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = notes.map((note) {
      return {
        'date': (note['date'] as DateTime).toIso8601String(),
        'note': note['note'] as String,
      };
    }).toList();

    await prefs.setString('$_prefixHealthNotes$userId', jsonEncode(notesJson));
    print('💾 Saved ${notes.length} health notes for user $userId');
  }

  /// Get health notes for user
  static Future<List<Map<String, dynamic>>> getHealthNotes(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final notesStr = prefs.getString('$_prefixHealthNotes$userId');

    if (notesStr != null && notesStr.isNotEmpty) {
      try {
        final List<dynamic> notesJson = jsonDecode(notesStr);
        final notes = notesJson.map((note) {
          return {
            'date': DateTime.parse(note['date'] as String),
            'note': note['note'] as String,
          };
        }).toList();

        print('📖 Retrieved ${notes.length} health notes for user $userId');
        return notes;
      } catch (e) {
        print('❌ Error parsing health notes: $e');
        return [];
      }
    }
    return [];
  }

  /// Add a new health note for user
  static Future<void> addHealthNote(String userId, String noteText) async {
    final notes = await getHealthNotes(userId);
    notes.insert(0, {'date': DateTime.now(), 'note': noteText});
    await saveHealthNotes(userId, notes);
    print('✅ Added new health note for user $userId');
  }

  /// Clear all wellness data for user (used on logout)
  static Future<void> clearUserWellnessData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefixLastPeriodDate$userId');
    await prefs.remove('$_prefixCycleLength$userId');
    await prefs.remove('$_prefixPeriodLength$userId');
    await prefs.remove('$_prefixHealthNotes$userId');
    print('🧹 Cleared wellness data for user $userId');
  }

  /// Load all wellness data for user (called on login)
  static Future<Map<String, dynamic>> loadUserWellnessData(
    String userId,
  ) async {
    final lastPeriodDate =
        await getLastPeriodDate(userId) ??
        DateTime.now().subtract(const Duration(days: 2)); // Default
    final cycleLength = await getCycleLength(userId);
    final periodLength = await getPeriodLength(userId);
    final healthNotes = await getHealthNotes(userId);

    print('📱 Loaded wellness data for user $userId:');
    print('  - Last period: $lastPeriodDate');
    print('  - Cycle length: $cycleLength days');
    print('  - Period length: $periodLength days');
    print('  - Notes count: ${healthNotes.length}');

    return {
      'lastPeriodDate': lastPeriodDate,
      'cycleLength': cycleLength,
      'periodLength': periodLength,
      'healthNotes': healthNotes,
    };
  }

  /// Save all wellness data for user at once
  static Future<void> saveAllWellnessData(
    String userId,
    DateTime lastPeriodDate,
    int cycleLength,
    int periodLength,
    List<Map<String, dynamic>> healthNotes,
  ) async {
    await saveCycleLength(userId, cycleLength);
    await savePeriodLength(userId, periodLength);
    await saveLastPeriodDate(userId, lastPeriodDate);
    await saveHealthNotes(userId, healthNotes);
    print('💾 Saved all wellness data for user $userId');
  }
}
