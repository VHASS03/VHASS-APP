import 'package:flutter/material.dart';
import '../constants/wellness_constants.dart';
import '../models/period_log.dart';
import '../services/wellness_tracker_service.dart';
import '../theme/wellness_theme.dart';
import '../widgets/flow_selector.dart';
import '../widgets/symptom_chip.dart';

/// Screen for logging period details with a simplified, clean, and premium UI.
class LogPeriodScreen extends StatefulWidget {
  final DateTime date;

  const LogPeriodScreen({super.key, required this.date});

  @override
  State<LogPeriodScreen> createState() => _LogPeriodScreenState();
}

class _LogPeriodScreenState extends State<LogPeriodScreen> {
  bool _loading = true;
  FlowIntensity? _flow;
  final List<SymptomType> _selectedSymptoms = [];
  MoodType? _mood;
  double _painLevel = 0;
  final TextEditingController _notesController = TextEditingController();
  bool _showAllSymptoms = false;

  // Most common symptoms to display by default
  final List<SymptomType> _commonSymptoms = [
    SymptomType.cramps,
    SymptomType.headache,
    SymptomType.bloating,
    SymptomType.fatigue,
    SymptomType.moodSwings,
    SymptomType.acne,
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingLog();
  }

  Future<void> _loadExistingLog() async {
    final log = await WellnessTrackerService.getPeriodLogForDate(widget.date);
    if (log != null) {
      if (mounted) {
        setState(() {
          _flow = log.flow;
          _selectedSymptoms.addAll(log.symptoms);
          _mood = log.mood;
          _painLevel = log.painLevel.toDouble();
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

  Future<void> _saveLog() async {
    final log = PeriodLog(
      date: widget.date,
      flow: _flow,
      symptoms: _selectedSymptoms,
      mood: _mood,
      painLevel: _painLevel.toInt(),
      notes: _notesController.text,
    );

    await WellnessTrackerService.upsertPeriodLog(log);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Period log saved successfully!'),
          backgroundColor: WellnessTheme.menstrual,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _deleteLog() async {
    await WellnessTrackerService.deletePeriodLog(widget.date);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Period log removed.'),
          backgroundColor: Colors.grey,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getPainLabel(int level) {
    if (level == 0) return 'No Pain';
    if (level <= 3) return 'Mild';
    if (level <= 6) return 'Moderate';
    if (level <= 8) return 'Severe';
    return 'Unbearable 😩';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedDate = '${widget.date.day} ${_getMonthName(widget.date.month)} ${widget.date.year}';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          formattedDate,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Log'),
                  content: const Text('Are you sure you want to delete this period log?'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteLog();
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── FLOW INTENSITY ───
            _buildSectionCard(
              title: 'Flow Intensity',
              titleColor: WellnessTheme.menstrual,
              child: FlowSelector(
                selected: _flow,
                onSelected: (val) => setState(() => _flow = val),
              ),
            ),
            const SizedBox(height: 16),

            // ─── PAIN LEVEL ───
            _buildSectionCard(
              title: 'Pain Level',
              titleColor: WellnessTheme.menstrual,
              trailing: Text(
                '${_painLevel.toInt()}/10 - ${_getPainLabel(_painLevel.toInt())}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              child: Column(
                children: [
                  Slider(
                    value: _painLevel,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    activeColor: WellnessTheme.menstrual,
                    inactiveColor: WellnessTheme.menstrual.withOpacity(0.15),
                    onChanged: (val) => setState(() => _painLevel = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── MOOD (Horizontal scrolling for cleaner layout) ───
            _buildSectionCard(
              title: 'Mood',
              titleColor: WellnessTheme.menstrual,
              trailing: _mood != null
                  ? Text(
                      moodLabels[_mood] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : null,
              child: SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: MoodType.values.length,
                  itemBuilder: (context, idx) {
                    final mood = MoodType.values[idx];
                    final isSelected = _mood == mood;
                    return GestureDetector(
                      onTap: () => setState(() => _mood = mood),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? WellnessTheme.menstrual.withOpacity(0.12)
                              : (isDark ? const Color(0xFF261D30) : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? WellnessTheme.menstrual
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              moodEmojis[mood] ?? '😐',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── SYMPTOMS (Simplified with 'Show All' Toggle) ───
            _buildSectionCard(
              title: 'Symptoms',
              titleColor: WellnessTheme.menstrual,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: (showAllSymptomsList).map((symptom) {
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
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAllSymptoms = !_showAllSymptoms;
                        });
                      },
                      icon: Icon(
                        _showAllSymptoms ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: WellnessTheme.menstrual,
                      ),
                      label: Text(
                        _showAllSymptoms ? 'Show Less' : 'More Symptoms',
                        style: const TextStyle(color: WellnessTheme.menstrual, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── NOTES ───
            _buildSectionCard(
              title: 'Notes & Journal',
              titleColor: WellnessTheme.menstrual,
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add extra details, physical states, medications...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1828) : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: WellnessTheme.menstrual),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── SAVE BUTTON ───
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: WellnessTheme.periodGradient,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: WellnessTheme.menstrual.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  child: const Text(
                    'Save Daily Period Log',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<SymptomType> get showAllSymptomsList {
    if (_showAllSymptoms) {
      return SymptomType.values;
    } else {
      // Always show common symptoms plus any custom symptom currently checked
      final items = List<SymptomType>.from(_commonSymptoms);
      for (final s in _selectedSymptoms) {
        if (!items.contains(s)) {
          items.add(s);
        }
      }
      return items;
    }
  }

  Widget _buildSectionCard({
    required String title,
    required Color titleColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: WellnessTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  letterSpacing: 1.2,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
