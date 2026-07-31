/// User settings for the Women Wellness Tracker module.
class WellnessSettings {
  final int cycleLength; // Default 28
  final int periodLength; // Default 5
  final bool periodReminder;
  final bool ovulationReminder;
  final bool dailyLogReminder;
  final int reminderHour; // 0-23
  final int reminderMinute; // 0-59

  WellnessSettings({
    this.cycleLength = 28,
    this.periodLength = 5,
    this.periodReminder = true,
    this.ovulationReminder = true,
    this.dailyLogReminder = false,
    this.reminderHour = 9,
    this.reminderMinute = 0,
  });

  /// Create from JSON map
  factory WellnessSettings.fromJson(Map<String, dynamic> json) {
    return WellnessSettings(
      cycleLength: json['cycleLength'] as int? ?? 28,
      periodLength: json['periodLength'] as int? ?? 5,
      periodReminder: json['periodReminder'] as bool? ?? true,
      ovulationReminder: json['ovulationReminder'] as bool? ?? true,
      dailyLogReminder: json['dailyLogReminder'] as bool? ?? false,
      reminderHour: json['reminderHour'] as int? ?? 9,
      reminderMinute: json['reminderMinute'] as int? ?? 0,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'cycleLength': cycleLength,
      'periodLength': periodLength,
      'periodReminder': periodReminder,
      'ovulationReminder': ovulationReminder,
      'dailyLogReminder': dailyLogReminder,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
    };
  }

  /// Create a copy with modified fields
  WellnessSettings copyWith({
    int? cycleLength,
    int? periodLength,
    bool? periodReminder,
    bool? ovulationReminder,
    bool? dailyLogReminder,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return WellnessSettings(
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      periodReminder: periodReminder ?? this.periodReminder,
      ovulationReminder: ovulationReminder ?? this.ovulationReminder,
      dailyLogReminder: dailyLogReminder ?? this.dailyLogReminder,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}
