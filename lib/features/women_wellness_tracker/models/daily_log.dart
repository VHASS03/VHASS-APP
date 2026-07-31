import '../constants/wellness_constants.dart';

/// Represents a daily wellness log (not necessarily a period day).
class DailyLog {
  final DateTime date;
  final MoodType? mood;
  final List<SymptomType> symptoms;
  final int waterIntakeMl; // millilitres
  final double? sleepHours;
  final double? weight;
  final String notes;
  final List<String> medications;

  DailyLog({
    required this.date,
    this.mood,
    this.symptoms = const [],
    this.waterIntakeMl = 0,
    this.sleepHours,
    this.weight,
    this.notes = '',
    this.medications = const [],
  });

  /// Create from JSON map
  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      date: DateTime.parse(json['date'] as String),
      mood: json['mood'] != null
          ? MoodType.values[json['mood'] as int]
          : null,
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((s) => SymptomType.values[s as int])
              .toList() ??
          [],
      waterIntakeMl: json['waterIntakeMl'] as int? ?? 0,
      sleepHours: (json['sleepHours'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      notes: json['notes'] as String? ?? '',
      medications: (json['medications'] as List<dynamic>?)
              ?.map((m) => m as String)
              .toList() ??
          [],
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'mood': mood?.index,
      'symptoms': symptoms.map((s) => s.index).toList(),
      'waterIntakeMl': waterIntakeMl,
      'sleepHours': sleepHours,
      'weight': weight,
      'notes': notes,
      'medications': medications,
    };
  }

  /// Create a copy with modified fields
  DailyLog copyWith({
    DateTime? date,
    MoodType? mood,
    List<SymptomType>? symptoms,
    int? waterIntakeMl,
    double? sleepHours,
    double? weight,
    String? notes,
    List<String>? medications,
  }) {
    return DailyLog(
      date: date ?? this.date,
      mood: mood ?? this.mood,
      symptoms: symptoms ?? this.symptoms,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      sleepHours: sleepHours ?? this.sleepHours,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      medications: medications ?? this.medications,
    );
  }
}
