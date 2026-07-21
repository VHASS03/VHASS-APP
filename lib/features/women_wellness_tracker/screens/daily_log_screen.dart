import 'package:flutter/material.dart';
import '../constants/wellness_constants.dart';
import '../models/daily_log.dart';
import '../services/wellness_tracker_service.dart';
import '../theme/wellness_theme.dart';
import '../widgets/mood_selector.dart';
import '../widgets/symptom_chip.dart';

/// Screen for tracking everyday metrics (mood, daily symptoms, water intake, sleep, weight).
class DailyLogScreen extends StatefulWidget {
  const DailyLogScreen({super.key});

  @override
  State<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends State<DailyLogScreen> {
  bool _loading = true;
  DateTime _today = DateTime.now();
  MoodType? _mood;
  final List<SymptomType> _selectedSymptoms = [];
  int _waterIntakeMl = 0;
  double _sleepHours = 7.0;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodayLog();
  }

  Future<void> _loadTodayLog() async {
    final log = await WellnessTrackerService.getDailyLogForDate(_today);
    if (log != null) {
      if (mounted) {
        setState(() {
          _mood = log.mood;
          _selectedSymptoms.addAll(log.symptoms);
          _waterIntakeMl = log.waterIntakeMl;
          _sleepHours = log.sleepHours ?? 7.0;
          _weightController.text = log.weight != null ? log.weight.toString() : '';
          _notesController.text = log.notes;
          _loading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveDailyLog() async {
    final weightVal = double.tryParse(_weightController.text);
    final log = DailyLog(
      date: _today,
      mood: _mood,
      symptoms: _selectedSymptoms,
      waterIntakeMl: _waterIntakeMl,
      sleepHours: _sleepHours,
      weight: weightVal,
      notes: _notesController.text,
    );

    await WellnessTrackerService.upsertDailyLog(log);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Daily wellness log saved!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── MOOD ──
          Text('DAILY MOOD', style: WellnessTheme.sectionTitle.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          MoodSelector(
            selectedMood: _mood,
            onMoodSelected: (val) => setState(() => _mood = val),
          ),
          const SizedBox(height: 24),

          // ─── WATER INTAKE ──
          Text('WATER INTAKE', style: WellnessTheme.sectionTitle.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: WellnessTheme.cardDecoration(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_waterIntakeMl ml',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _waterIntakeMl >= 2000 ? 'Goal reached! 🎉' : 'Goal: 2000 ml',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.blueAccent, size: 28),
                      onPressed: () {
                        setState(() {
                          _waterIntakeMl = (_waterIntakeMl - 250).clamp(0, 5000);
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 28),
                      onPressed: () {
                        setState(() {
                          _waterIntakeMl = (_waterIntakeMl + 250).clamp(0, 5000);
                        });
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── SLEEP HOURS ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SLEEP DURATION', style: WellnessTheme.sectionTitle.copyWith(color: theme.colorScheme.primary)),
              Text('${_sleepHours.toStringAsFixed(1)} hrs', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _sleepHours,
            min: 0,
            max: 24,
            divisions: 48, // 0.5 steps
            activeColor: Colors.purpleAccent,
            onChanged: (val) => setState(() => _sleepHours = val),
          ),
          const SizedBox(height: 24),

          // ─── WEIGHT ──
          Text('WEIGHT (KG)', style: WellnessTheme.sectionTitle.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Enter current weight (e.g., 55.4)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              prefixIcon: const Icon(Icons.monitor_weight_outlined),
            ),
          ),
          const SizedBox(height: 24),

          // ─── SYMPTOMS ──
          Text('DAILY SYMPTOMS', style: WellnessTheme.sectionTitle.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: SymptomType.values.map((symptom) {
              final isSelected = _selectedSymptoms.contains(symptom);
              return SymptomChip(
                symptom: symptom,
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedSymptoms.add(symptom);
                    } else {
                      _selectedSymptoms.remove(symptom);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ─── NOTES ──
          Text('DAILY NOTES / JOURNAL', style: WellnessTheme.sectionTitle.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add notes about food, activity, or general mood...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ─── SAVE CTA ──
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveDailyLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save Daily Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}
