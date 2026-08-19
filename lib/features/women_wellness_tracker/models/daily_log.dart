import '../constants/wellness_constants.dart';

/// Represents a daily wellness log (not necessarily a period day).
class DailyLog {
  final DateTime date;
  final MoodType? mood;
  final int? energyLevel; // 1-5 or null
  final List<SymptomType> symptoms;
  final int waterIntakeMl; // millilitres
  final double? sleepHours;
  final double? weight;
  final String notes;
  final List<String> medications;

  DailyLog({
    required this.date,
    this.mood,
    this.energyLevel,
    this.symptoms = const [],
    this.waterIntakeMl = 0,
    this.sleepHours,
    this.weight,
    this.notes = '',
    this.medications = const [],
  });

  /// Alias for waterIntakeMl
  int get waterIntake => waterIntakeMl;

  /// Create from JSON map
  factory DailyLog.fromJson(Map<String, dynamic> json) {
    MoodType? parseMood(dynamic val) {
      if (val == null) return null;
      if (val is int && val >= 0 && val < MoodType.values.length) {
        return MoodType.values[val];
      }
      if (val is String) {
        return MoodType.values.firstWhere(
          (e) => e.name.toLowerCase() == val.toLowerCase(),
          orElse: () => MoodType.neutral,
        );
      }
      return null;
    }

    List<SymptomType> parseSymptoms(dynamic val) {
      if (val is! List) return [];
      final result = <SymptomType>[];
      for (final s in val) {
        if (s is int && s >= 0 && s < SymptomType.values.length) {
          result.add(SymptomType.values[s]);
        } else if (s is String) {
          final found = SymptomType.values.where(
            (e) => e.name.toLowerCase() == s.toLowerCase(),
          );
          if (found.isNotEmpty) result.add(found.first);
        }
      }
      return result;
    }

    final rawWater = json['waterIntakeMl'] ?? json['waterIntake'];

    return DailyLog(
      date: DateTime.parse(json['date'] as String),
      mood: parseMood(json['mood']),
      energyLevel: (json['energyLevel'] as num?)?.toInt(),
      symptoms: parseSymptoms(json['symptoms']),
      waterIntakeMl: rawWater != null ? (rawWater as num).toInt() : 0,
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
      'energyLevel': energyLevel,
      'symptoms': symptoms.map((s) => s.index).toList(),
      'waterIntakeMl': waterIntakeMl,
      'waterIntake': waterIntakeMl,
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
    int? energyLevel,
    List<SymptomType>? symptoms,
    int? waterIntakeMl,
    int? energyLevel,
    double? sleepHours,
    double? weight,
    String? notes,
    List<String>? medications,
  }) {
    return DailyLog(
      date: date ?? this.date,
      mood: mood ?? this.mood,
      energyLevel: energyLevel ?? this.energyLevel,
      symptoms: symptoms ?? this.symptoms,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      energyLevel: energyLevel ?? this.energyLevel,
      sleepHours: sleepHours ?? this.sleepHours,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      medications: medications ?? this.medications,
    );
  }
}
