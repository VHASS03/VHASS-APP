import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'yoga_pose_screen.dart';
import 'yoga_pose_data.dart';
import '../../core/services/storage_service.dart';
import '../../core/config/api_config.dart';
import '../../core/colors.dart';
import '../chat_screen.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  // ─── STATE ───────────────────────────────
  String _healthCondition = "None";
  DateTime _lastPeriodDate = DateTime.now().subtract(const Duration(days: 2));
  int _cycleLength = 28;
  int _periodLength = 5;
  bool _setupDone = false;

  final List<String> _selectedSymptoms = [];
  final List<Map<String, dynamic>> _notes = [];

  final _conditions = [
    "None",
    "PCOS",
    "PCOD",
    "Irregular Periods",
    "Endometriosis",
    "I don't know",
  ];

  final _symptoms = [
    "Cramps",
    "Headache",
    "Bloating",
    "Fatigue",
    "Mood Swings",
    "Acne",
    "Cravings",
  ];

  // ─── LIFECYCLE ───────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  Future<void> _loadSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('wellness_setup_done') ?? false;

    if (done) {
      setState(() {
        _setupDone = true;
        _healthCondition = prefs.getString('wellness_condition') ?? 'None';
        _periodLength = prefs.getInt('wellness_period_length') ?? 5;
        _cycleLength = prefs.getInt('wellness_cycle_length') ?? 28;
        final dateStr = prefs.getString('wellness_last_period');
        if (dateStr != null) {
          _lastPeriodDate = DateTime.tryParse(dateStr) ?? _lastPeriodDate;
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSetupDialog());
    }
  }

  Future<void> _saveSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wellness_setup_done', true);
    await prefs.setString('wellness_condition', _healthCondition);
    await prefs.setInt('wellness_period_length', _periodLength);
    await prefs.setInt('wellness_cycle_length', _cycleLength);
    await prefs.setString(
        'wellness_last_period', _lastPeriodDate.toIso8601String());
  }

  // ─── CYCLE CALCULATIONS ──────────────────
  DateTime get _nextPeriodDate {
    // Keep adding cycles until the date is in the future
    DateTime next = _lastPeriodDate.add(Duration(days: _cycleLength));
    while (next.isBefore(DateTime.now())) {
      next = next.add(Duration(days: _cycleLength));
    }
    return next;
  }

  int get _dayInCycle =>
      DateTime.now().difference(_lastPeriodDate).inDays % _cycleLength;

  bool get _isOnPeriod => _dayInCycle < _periodLength;
  int get _periodDay => _dayInCycle + 1;

  String get _cyclePhase {
    final d = _dayInCycle;
    if (d < _periodLength) return "Menstrual";
    if (d < 13) return "Follicular";
    if (d < 16) return "Ovulation";
    return "Luteal";
  }

  // ─── RECOMMENDATIONS ────────────────────

  Map<String, List<String>> get _dietRecommendations {
    if (_isOnPeriod) {
      // During period — comfort foods, anti-cramp
      switch (_healthCondition) {
        case 'PCOS':
        case 'PCOD':
          return {
            'eat': [
              '🫚 Anti-inflammatory ginger tea',
              '🥬 Leafy greens (spinach, kale)',
              '🐟 Omega-3 rich fish or flaxseeds',
              '🫐 Berries and antioxidant fruits',
              '🥜 Nuts and seeds for magnesium',
            ],
            'avoid': [
              '🚫 Sugary drinks and sweets',
              '🚫 Dairy products',
              '🚫 Refined carbs and white bread',
            ],
          };
        case 'Endometriosis':
          return {
            'eat': [
              '🥗 Iron-rich foods (red meat, lentils)',
              '🍠 Sweet potatoes and root veggies',
              '🫖 Chamomile or turmeric tea',
              '🥑 Healthy fats (avocado, olive oil)',
              '🍌 Bananas for potassium',
            ],
            'avoid': [
              '🚫 Red meat in excess',
              '🚫 Alcohol and caffeine',
              '🚫 Processed foods',
            ],
          };
        default:
          return {
            'eat': [
              '🫚 Warm ginger or cinnamon tea',
              '🍫 Dark chocolate (magnesium!)',
              '🍌 Bananas for potassium',
              '🥗 Iron-rich leafy greens',
              '💧 Plenty of warm water',
            ],
            'avoid': [
              '🚫 Cold beverages',
              '🚫 Excess salt (causes bloating)',
              '🚫 Caffeine',
            ],
          };
      }
    }

    // Non-period days — condition-specific
    switch (_healthCondition) {
      case 'PCOS':
      case 'PCOD':
        return {
          'eat': [
            '🥦 Low-GI vegetables',
            '🐔 Lean protein (chicken, fish, tofu)',
            '🫘 Legumes and lentils',
            '🥜 Walnuts and almonds',
            '🍵 Spearmint tea for hormones',
          ],
          'avoid': [
            '🚫 Sugar and processed snacks',
            '🚫 White rice and bread',
            '🚫 Excess dairy',
          ],
        };
      case 'Endometriosis':
        return {
          'eat': [
            '🥬 Anti-inflammatory vegetables',
            '🐟 Fatty fish (salmon, mackerel)',
            '🫐 Colorful fruits and berries',
            '🧄 Garlic and turmeric',
            '🌾 Whole grains',
          ],
          'avoid': [
            '🚫 Gluten (may trigger inflammation)',
            '🚫 Alcohol',
            '🚫 Trans fats',
          ],
        };
      case 'Irregular Periods':
        return {
          'eat': [
            '🥜 Seeds (flax, pumpkin, sesame)',
            '🥗 Balanced meals at regular times',
            '🍠 Complex carbohydrates',
            '🫖 Fennel and fenugreek tea',
            '🥛 Vitamin D-rich foods',
          ],
          'avoid': [
            '🚫 Skipping meals',
            '🚫 Excess caffeine',
            '🚫 Highly processed food',
          ],
        };
      default:
        return {
          'eat': [
            '🥗 Fresh fruits and vegetables',
            '🐟 Lean proteins and healthy fats',
            '🌾 Whole grains for steady energy',
            '💧 8 glasses of water daily',
            '🫖 Herbal teas',
          ],
          'avoid': [
            '🚫 Excess sugar',
            '🚫 Processed junk food',
            '🚫 Late-night heavy meals',
          ],
        };
    }
  }

  List<YogaPose> get _recommendedPoses {
    if (_isOnPeriod) {
      return periodReliefPoses;
    }
    switch (_cyclePhase) {
      case 'Follicular':
        return generalPoses
            .where((p) =>
                p.name == 'Sun Salutation' ||
                p.name == 'Warrior II' ||
                p.name == 'Bridge Pose')
            .toList();
      case 'Ovulation':
        return generalPoses
            .where((p) =>
                p.name == 'Camel Pose' ||
                p.name == 'Warrior II' ||
                p.name == 'Sun Salutation')
            .toList();
      case 'Luteal':
        return [
          ...generalPoses
              .where((p) =>
                  p.name == 'Forward Fold' || p.name == 'Bridge Pose'),
          ...periodReliefPoses
              .where((p) => p.name == 'Cat-Cow Stretch'),
        ];
      default:
        return generalPoses.take(3).toList();
    }
  }

  // ─── SETUP DIALOG ───────────────────────

  void _showSetupDialog() {
    DateTime selectedDate = _lastPeriodDate;
    final periodCtrl = TextEditingController(text: _periodLength.toString());
    String condition = _healthCondition;
    int step = 0; // 0 = date, 1 = length, 2 = condition

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setD) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;

          Widget stepContent;
          String title;
          String subtitle;

          switch (step) {
            case 0:
              title = '🌸 When was your last period?';
              subtitle = 'Tap to pick the start date';
              stepContent = GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setD(() => selectedDate = picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.card
                        : AppColors.blush.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('MMM dd, yyyy').format(selectedDate),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              break;

            case 1:
              title = '📅 How many days does it last?';
              subtitle = 'Average period length in days';
              stepContent = TextField(
                controller: periodCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  hintText: '5',
                  suffix: Text(
                    'days',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.card
                      : AppColors.blush.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              );
              break;

            default:
              title = '💊 Any health conditions?';
              subtitle = 'This helps us personalise your plan';
              stepContent = Column(
                children: _conditions.map((c) {
                  final sel = c == condition;
                  return GestureDetector(
                    onTap: () => setD(() => condition = c),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary.withOpacity(0.12)
                            : (isDark
                                ? AppColors.card
                                : AppColors.blush.withOpacity(0.06)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.1),
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sel
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: sel
                                ? AppColors.primary
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            c,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.normal,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding:
                const EdgeInsets.only(top: 24, left: 24, right: 24),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress dots
                Row(
                  children: List.generate(3, (i) {
                    return Container(
                      width: i == step ? 28 : 10,
                      height: 5,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i <= step
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(child: stepContent),
            actions: [
              if (step > 0)
                TextButton(
                  onPressed: () => setD(() => step--),
                  child: Text(
                    'Back',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (step < 2) {
                    setD(() => step++);
                  } else {
                    // Save
                    setState(() {
                      _lastPeriodDate = selectedDate;
                      _periodLength =
                          int.tryParse(periodCtrl.text) ?? 5;
                      _healthCondition = condition;
                      _setupDone = true;
                    });
                    _saveSetup();
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                ),
                child: Text(step < 2 ? 'Next' : 'Get Started 🎉'),
              ),
            ],
          );
        });
      },
    );
  }

  // ─── NOTE DIALOG ────────────────────────

  void _addNote() {
    final controller = TextEditingController();
    String selectedMood = '😊';
    final moods = ['😊', '😢', '😤', '😴', '🤢', '💪', '🥺'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setD) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('📝 Log Note'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mood picker
                  Text(
                    'How are you feeling?',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: moods.map((m) {
                      final sel = m == selectedMood;
                      return GestureDetector(
                        onTap: () => setD(() => selectedMood = m),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel
                                ? AppColors.primary.withOpacity(0.15)
                                : Colors.transparent,
                            border: sel
                                ? Border.all(
                                    color: AppColors.primary, width: 2)
                                : null,
                          ),
                          child: Text(m, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Symptoms, mood, or anything...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.card
                          : AppColors.blush.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    setState(() {
                      _notes.insert(0, {
                        'text': controller.text,
                        'mood': selectedMood,
                        'date': DateTime.now(),
                      });
                    });
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  // ─── CYCLE DASHBOARD ────────────────────

  Widget _cycleDashboard() {
    final daysLeft = _nextPeriodDate.difference(DateTime.now()).inDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isOnPeriod
              ? [AppColors.primary, const Color(0xFFD45B8A)]
              : [AppColors.lavender, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnPeriod ? 'Period Day' : 'Next Period In',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOnPeriod
                          ? 'Day $_periodDay of $_periodLength 🌸'
                          : '$daysLeft days',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Right info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Expected On',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd').format(_nextPeriodDate),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Period progress bar
          if (_isOnPeriod) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _periodDay / _periodLength,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isOnPeriod && _periodDay <= 2
                  ? '💛 Take it easy, rest well'
                  : _periodDay <= 4
                      ? '💪 You\'re doing great, stay hydrated'
                      : '🌟 Almost there, hang in!',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],

          // Condition badge
          if (_healthCondition != 'None' &&
              _healthCondition != "I don't know") ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '⚕️ $_healthCondition',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── PHASE CARD ─────────────────────────

  Widget _phaseCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Map<String, Map<String, dynamic>> phaseInfo = {
      'Menstrual': {
        'icon': Icons.water_drop,
        'color': AppColors.primary,
        'tip': 'Rest, warm drinks, gentle stretching',
      },
      'Follicular': {
        'icon': Icons.eco,
        'color': AppColors.mintAccent,
        'tip': 'Energy is rising — great for new activities!',
      },
      'Ovulation': {
        'icon': Icons.wb_sunny,
        'color': AppColors.peach,
        'tip': 'Peak energy! Best time for intense workouts',
      },
      'Luteal': {
        'icon': Icons.nightlight_round,
        'color': AppColors.lavender,
        'tip': 'Slow down, prioritise calm and sleep',
      },
    };

    final info = phaseInfo[_cyclePhase]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? (info['color'] as Color).withOpacity(0.10)
            : (info['color'] as Color).withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (info['color'] as Color).withOpacity(isDark ? 0.20 : 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (info['color'] as Color).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(info['icon'] as IconData,
                color: info['color'] as Color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_cyclePhase} Phase',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  info['tip'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondary
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SYMPTOM TRACKER ────────────────────

  Widget _symptomTracker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Map<String, IconData> sIcons = {
      'Cramps': Icons.bolt,
      'Headache': Icons.psychology,
      'Bloating': Icons.air,
      'Fatigue': Icons.bedtime,
      'Mood Swings': Icons.mood,
      'Acne': Icons.face,
      'Cravings': Icons.fastfood,
    };

    final colors = [
      AppColors.blush,
      AppColors.lavender,
      AppColors.peach,
      AppColors.mintAccent,
      AppColors.primary,
      AppColors.blush,
      AppColors.lavender,
    ];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _symptoms.length,
        itemBuilder: (_, i) {
          final s = _symptoms[i];
          final sel = _selectedSymptoms.contains(s);
          final c = colors[i % colors.length];

          return GestureDetector(
            onTap: () => setState(() {
              sel ? _selectedSymptoms.remove(s) : _selectedSymptoms.add(s);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 90,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.primary
                    : (isDark
                        ? c.withOpacity(0.10)
                        : c.withOpacity(0.15)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? AppColors.primary
                      : c.withOpacity(isDark ? 0.20 : 0.25),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    sIcons[s],
                    color: sel
                        ? Colors.white
                        : (isDark ? c : c.withOpacity(0.8)),
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── DIET CARD ──────────────────────────

  Widget _dietCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final diet = _dietRecommendations;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.mintAccent.withOpacity(0.08)
            : AppColors.mintAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.mintAccent.withOpacity(isDark ? 0.15 : 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu, color: AppColors.mintAccent),
              const SizedBox(width: 8),
              Text(
                _isOnPeriod ? 'Comfort Foods 🌸' : 'Diet Tips',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...diet['eat']!.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  e,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              )),
          if (diet['avoid'] != null && diet['avoid']!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Better to avoid:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            ...diet['avoid']!.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ─── EXERCISE / YOGA CARD ───────────────

  Widget _exerciseCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final poses = _recommendedPoses;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.blush.withOpacity(0.08)
            : AppColors.blush.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.blush.withOpacity(isDark ? 0.15 : 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.self_improvement, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                _isOnPeriod
                    ? 'Gentle Exercises (Cramp Relief) 🧘'
                    : 'Recommended Exercises',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...poses.map((pose) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.card
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(pose.icon,
                        color: AppColors.primary, size: 22),
                  ),
                  title: Text(
                    pose.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    pose.holdSeconds > 0
                        ? '${pose.difficulty} · ${pose.holdSeconds}s hold'
                        : pose.difficulty,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.lavender.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow_rounded,
                        color: AppColors.lavender, size: 20),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => YogaPoseScreen(pose: pose),
                      ),
                    );
                  },
                ),
              )),
        ],
      ),
    );
  }

  // ─── CALENDAR ───────────────────────────

  Widget _calendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2035),
      focusedDay: DateTime.now(),
      rowHeight: 46,
      daysOfWeekHeight: 22,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarStyle: const CalendarStyle(cellMargin: EdgeInsets.all(4)),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, date, _) {
          final diff =
              date.difference(_lastPeriodDate).inDays % _cycleLength;
          if (diff < _periodLength) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }
          return null;
        },
      ),
    );
  }

  // ─── NOTES LIST ─────────────────────────

  Widget _notesList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_notes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.card
              : AppColors.lavender.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.note_alt_outlined,
                color: AppColors.lavender, size: 36),
            const SizedBox(height: 8),
            Text(
              'No notes yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to log how you\'re feeling',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _notes.asMap().entries.map((entry) {
        final i = entry.key;
        final note = entry.value;
        final mood = note['mood'] ?? '😊';
        final pastels = [
          AppColors.blush,
          AppColors.lavender,
          AppColors.peach,
          AppColors.mintAccent,
        ];
        final c = pastels[i % pastels.length];

        return Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.red),
          ),
          onDismissed: (_) => setState(() => _notes.removeAt(i)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? c.withOpacity(0.08)
                  : c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: c.withOpacity(isDark ? 0.15 : 0.12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mood, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note['text'],
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd · hh:mm a')
                            .format(note['date']),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── MAIN BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Women Wellness'),
        centerTitle: false,
        actions: [
          // Reconfigure button
          IconButton(
            icon: Icon(Icons.tune_rounded, color: AppColors.primary),
            onPressed: _showSetupDialog,
            tooltip: 'Reconfigure',
          ),
        ],
      ),

      // FABs
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'add_note',
              onPressed: _addNote,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'ai_companion',
              icon: const Icon(Icons.smart_toy, color: Colors.white),
              label: const Text(
                'AI Companion',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.lavender,
              onPressed: () async {
                final token = await StorageService.getToken();
                if (token == null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Authentication required. Please log in again.',
                      ),
                    ),
                  );
                  return;
                }
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      token: token,
                      serverUrl:
                          ApiConfig.baseUrl.replaceFirst('/api', ''),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      // Body
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cycleDashboard(),
              const SizedBox(height: 16),

              _phaseCard(),
              const SizedBox(height: 20),

              _calendar(),
              const SizedBox(height: 24),

              // Symptoms
              Text(
                'Track Symptoms',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _symptomTracker(),
              const SizedBox(height: 24),

              // Diet
              Text(
                _isOnPeriod
                    ? 'Period Comfort Foods 🌸'
                    : 'Diet Suggestions',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _dietCard(),
              const SizedBox(height: 24),

              // Exercise
              Text(
                _isOnPeriod
                    ? 'Gentle Exercises for Relief 🧘'
                    : 'Wellness Exercises',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _exerciseCard(),
              const SizedBox(height: 24),

              // Notes
              Text(
                'Health Notes',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _notesList(),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
