import 'package:flutter/material.dart';
import '../constants/wellness_constants.dart';
import '../theme/wellness_theme.dart';

/// Badge showing the current cycle phase with icon and label.
class PhaseIndicator extends StatelessWidget {
  final CyclePhase phase;

  const PhaseIndicator({super.key, required this.phase});

  Color get _color {
    switch (phase) {
      case CyclePhase.menstrual:
        return WellnessTheme.menstrual;
      case CyclePhase.follicular:
        return WellnessTheme.follicular;
      case CyclePhase.ovulation:
        return WellnessTheme.ovulationDay;
      case CyclePhase.luteal:
        return WellnessTheme.luteal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(phaseIcons[phase], size: 16, color: _color),
          const SizedBox(width: 6),
          Text(
            phaseLabels[phase] ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
