import '../constants/wellness_constants.dart';

/// Represents a single period log entry for a specific date.
class PeriodLog {
  final DateTime date;
  final FlowIntensity? flow;
  final List<SymptomType> symptoms;
  final MoodType? mood;
  final int painLevel; // 0-10
  final String notes;
  final double? temperature;
  final double? weight;

  PeriodLog({
    required this.date,
    this.flow,
    this.symptoms = const [],
    this.mood,
    this.painLevel = 0,
    this.notes = '',
    this.temperature,
    this.weight,
  });

  /// Create from JSON map
  factory PeriodLog.fromJson(Map<String, dynamic> json) {
    return PeriodLog(
      date: DateTime.parse(json['date'] as String),
      flow: json['flow'] != null
          ? FlowIntensity.values[json['flow'] as int]
          : null,
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((s) => SymptomType.values[s as int])
              .toList() ??
          [],
      mood: json['mood'] != null
          ? MoodType.values[json['mood'] as int]
          : null,
      painLevel: json['painLevel'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      temperature: (json['temperature'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'flow': flow?.index,
      'symptoms': symptoms.map((s) => s.index).toList(),
      'mood': mood?.index,
      'painLevel': painLevel,
      'notes': notes,
      'temperature': temperature,
      'weight': weight,
    };
  }

  /// Create a copy with modified fields
  PeriodLog copyWith({
    DateTime? date,
    FlowIntensity? flow,
    List<SymptomType>? symptoms,
    MoodType? mood,
    int? painLevel,
    String? notes,
    double? temperature,
    double? weight,
  }) {
    return PeriodLog(
      date: date ?? this.date,
      flow: flow ?? this.flow,
      symptoms: symptoms ?? this.symptoms,
      mood: mood ?? this.mood,
      painLevel: painLevel ?? this.painLevel,
      notes: notes ?? this.notes,
      temperature: temperature ?? this.temperature,
      weight: weight ?? this.weight,
    );
  }
}
