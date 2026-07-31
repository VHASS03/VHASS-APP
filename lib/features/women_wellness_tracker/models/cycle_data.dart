/// Represents a completed menstrual cycle.
class CycleData {
  final DateTime startDate;
  final DateTime endDate; // Last day of period bleeding
  final int cycleLength; // Total days from this start to next start
  final int periodLength; // Days of bleeding
  final bool predicted; // Whether this was auto-predicted

  CycleData({
    required this.startDate,
    required this.endDate,
    required this.cycleLength,
    required this.periodLength,
    this.predicted = false,
  });

  /// Create from JSON map
  factory CycleData.fromJson(Map<String, dynamic> json) {
    return CycleData(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      cycleLength: json['cycleLength'] as int? ?? 28,
      periodLength: json['periodLength'] as int? ?? 5,
      predicted: json['predicted'] as bool? ?? false,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'cycleLength': cycleLength,
      'periodLength': periodLength,
      'predicted': predicted,
    };
  }

  /// Create a copy with modified fields
  CycleData copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? cycleLength,
    int? periodLength,
    bool? predicted,
  }) {
    return CycleData(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      predicted: predicted ?? this.predicted,
    );
  }
}
