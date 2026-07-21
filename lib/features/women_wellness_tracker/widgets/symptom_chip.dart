import 'package:flutter/material.dart';
import '../constants/wellness_constants.dart';

/// Selectable symptom chip with icon, used in period logging and daily log.
class SymptomChip extends StatelessWidget {
  final SymptomType symptom;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const SymptomChip({
    super.key,
    required this.symptom,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final label = symptomLabels[symptom] ?? '';
    final icon = symptomIcons[symptom] ?? Icons.circle;
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;

    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: color),
      selected: selected,
      onSelected: (val) => onSelected(val),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).textTheme.bodyMedium?.color,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
