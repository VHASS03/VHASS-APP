import '../constants/wellness_constants.dart';

/// Represents a single period log entry for a specific date.
class PeriodLog {
  final DateTime date;
  final DateTime? endDate;
  final FlowIntensity? flow;
  final List<SymptomType> symptoms;
  final MoodType? mood;
  final int painLevel; // 0-10
  final String notes;
  final double? temperature;
  final double? weight;

  PeriodLog({
    required this.date,
    this.endDate,
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
    FlowIntensity? parseFlow(dynamic val) {
      if (val == null) return null;
      if (val is int && val >= 0 && val < FlowIntensity.values.length) {
        return FlowIntensity.values[val];
      }
      if (val is String) {
        return FlowIntensity.values.firstWhere(
          (e) => e.name.toLowerCase() == val.toLowerCase(),
          orElse: () => FlowIntensity.medium,
        );
      }
      return null;
    }

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

    return PeriodLog(
      date: DateTime.parse(json['date'] as String),
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
      flow: parseFlow(json['flow']),
      symptoms: parseSymptoms(json['symptoms']),
      mood: parseMood(json['mood']),
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
      'endDate': endDate?.toIso8601String(),
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
    DateTime? endDate,
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
      endDate: endDate ?? this.endDate,
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
