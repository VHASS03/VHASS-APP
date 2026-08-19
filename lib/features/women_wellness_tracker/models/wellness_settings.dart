/// User settings for the Women Wellness Tracker module.
class WellnessSettings {
  final int cycleLength; // Default 28
  final int periodLength; // Default 5
  final DateTime? lastPeriodDate;
  final String healthCondition; // Default 'None'
  final bool periodReminder;
  final bool ovulationReminder;
  final bool dailyLogReminder;
  final int reminderHour; // 0-23
  final int reminderMinute; // 0-59
  final DateTime? lastPeriodDate;
  final String? healthCondition;

  WellnessSettings({
    this.cycleLength = 28,
    this.periodLength = 5,
    this.lastPeriodDate,
    this.healthCondition = 'None',
    this.periodReminder = true,
    this.ovulationReminder = true,
    this.dailyLogReminder = false,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.lastPeriodDate,
    this.healthCondition = 'None',
  });

  /// Create from JSON map
  factory WellnessSettings.fromJson(Map<String, dynamic> json) {
    return WellnessSettings(
      cycleLength: json['cycleLength'] as int? ?? 28,
      periodLength: json['periodLength'] as int? ?? 5,
      lastPeriodDate: json['lastPeriodDate'] != null ? DateTime.tryParse(json['lastPeriodDate'] as String) : null,
      healthCondition: json['healthCondition'] as String? ?? 'None',
      periodReminder: json['periodReminder'] as bool? ?? true,
      ovulationReminder: json['ovulationReminder'] as bool? ?? true,
      dailyLogReminder: json['dailyLogReminder'] as bool? ?? false,
      reminderHour: json['reminderHour'] as int? ?? 9,
      reminderMinute: json['reminderMinute'] as int? ?? 0,
      lastPeriodDate: json['lastPeriodDate'] != null
          ? DateTime.tryParse(json['lastPeriodDate'] as String)
          : null,
      healthCondition: json['healthCondition'] as String? ?? 'None',
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'cycleLength': cycleLength,
      'periodLength': periodLength,
      'lastPeriodDate': lastPeriodDate?.toIso8601String(),
      'healthCondition': healthCondition,
      'periodReminder': periodReminder,
      'ovulationReminder': ovulationReminder,
      'dailyLogReminder': dailyLogReminder,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'lastPeriodDate': lastPeriodDate?.toIso8601String(),
      'healthCondition': healthCondition,
    };
  }

  /// Create a copy with modified fields
  WellnessSettings copyWith({
    int? cycleLength,
    int? periodLength,
    DateTime? lastPeriodDate,
    String? healthCondition,
    bool? periodReminder,
    bool? ovulationReminder,
    bool? dailyLogReminder,
    int? reminderHour,
    int? reminderMinute,
    DateTime? lastPeriodDate,
    String? healthCondition,
  }) {
    return WellnessSettings(
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      lastPeriodDate: lastPeriodDate ?? this.lastPeriodDate,
      healthCondition: healthCondition ?? this.healthCondition,
      periodReminder: periodReminder ?? this.periodReminder,
      ovulationReminder: ovulationReminder ?? this.ovulationReminder,
      dailyLogReminder: dailyLogReminder ?? this.dailyLogReminder,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      lastPeriodDate: lastPeriodDate ?? this.lastPeriodDate,
      healthCondition: healthCondition ?? this.healthCondition,
    );
  }
}
