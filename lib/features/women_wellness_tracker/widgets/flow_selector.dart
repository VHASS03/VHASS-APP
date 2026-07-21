import 'package:flutter/material.dart';
import '../constants/wellness_constants.dart';
import '../theme/wellness_theme.dart';

/// Flow intensity selector with visual indicators.
class FlowSelector extends StatelessWidget {
  final FlowIntensity? selected;
  final ValueChanged<FlowIntensity> onSelected;

  const FlowSelector({
    super.key,
    this.selected,
    required this.onSelected,
  });

  Color _flowColor(FlowIntensity flow) {
    switch (flow) {
      case FlowIntensity.spotting:
        return WellnessTheme.flowSpotting;
      case FlowIntensity.light:
        return WellnessTheme.flowLight;
      case FlowIntensity.medium:
        return WellnessTheme.flowMedium;
      case FlowIntensity.heavy:
        return WellnessTheme.flowHeavy;
      case FlowIntensity.veryHeavy:
        return WellnessTheme.flowVeryHeavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: FlowIntensity.values.map((flow) {
        final isSelected = selected == flow;
        final color = _flowColor(flow);

        return GestureDetector(
          onTap: () => onSelected(flow),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? color : Colors.grey.withOpacity(0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  flowIcons[flow],
                  size: 22,
                  color: isSelected ? color : Colors.grey[400],
                ),
                const SizedBox(height: 4),
                Text(
                  flowLabels[flow] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? color : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
