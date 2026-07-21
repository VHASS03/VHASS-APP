import 'package:flutter/material.dart';
import '../constants/wellness_constants.dart';
import '../models/period_log.dart';
import '../models/daily_log.dart';
import '../models/cycle_data.dart';
import '../models/wellness_settings.dart';
import '../services/wellness_tracker_service.dart';
import '../utils/cycle_calculator.dart';
import '../theme/wellness_theme.dart';
import '../widgets/cycle_ring.dart';
import '../widgets/phase_indicator.dart';
import '../widgets/stat_card.dart';
import 'log_period_screen.dart';

/// Dashboard screen — the main home view of the wellness tracker.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  WellnessSettings _settings = WellnessSettings();
  List<PeriodLog> _periodLogs = [];
  List<DailyLog> _dailyLogs = [];
  List<CycleData> _cycleHistory = [];
  DateTime _lastPeriodStart = DateTime.now().subtract(const Duration(days: 5));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final settings = await WellnessTrackerService.getSettings();
    final periodLogs = await WellnessTrackerService.getPeriodLogs();
    final dailyLogs = await WellnessTrackerService.getDailyLogs();
    final cycleHistory = await WellnessTrackerService.getCycleHistory();

    // Determine last period start from logged data or default
    DateTime lastStart = DateTime.now().subtract(const Duration(days: 5));
    if (periodLogs.isNotEmpty) {
      // Find earliest log in the most recent contiguous period block
      final sorted = List<PeriodLog>.from(periodLogs)
        ..sort((a, b) => b.date.compareTo(a.date));
      lastStart = sorted.first.date;

      // Walk back to find start of this period block
      for (int i = 1; i < sorted.length; i++) {
        final diff = sorted[i - 1].date.difference(sorted[i].date).inDays;
        if (diff <= 2) {
          lastStart = sorted[i].date;
        } else {
          break;
        }
      }
    } else if (cycleHistory.isNotEmpty) {
      lastStart = cycleHistory.first.startDate;
    }

    if (mounted) {
      setState(() {
        _settings = settings;
        _periodLogs = periodLogs;
        _dailyLogs = dailyLogs;
        _cycleHistory = cycleHistory;
        _lastPeriodStart = lastStart;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final cycleDay = CycleCalculator.currentCycleDay(_lastPeriodStart);
    final phase = CycleCalculator.currentPhase(
      _lastPeriodStart,
      _settings.cycleLength,
      _settings.periodLength,
    );
    final daysUntil = CycleCalculator.daysUntilNextPeriod(
      _lastPeriodStart,
      _settings.cycleLength,
    );
    final ovDays = CycleCalculator.daysUntilOvulation(
      _lastPeriodStart,
      _settings.cycleLength,
    );
    final avgCycle = CycleCalculator.averageCycleLength(_cycleHistory);
    final confidence = CycleCalculator.predictionConfidence(_cycleHistory);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ─── Phase description card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: WellnessTheme.gradientCard(
                _gradientForPhase(phase),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhaseIndicator(phase: phase),
                  const SizedBox(height: 10),
                  Text(
                    phaseDescriptions[phase] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.95),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Cycle Ring ──
            CycleRing(
              currentDay: cycleDay.clamp(1, _settings.cycleLength),
              cycleLength: _settings.cycleLength,
              phase: phase,
              daysUntilNextPeriod: daysUntil,
            ),
            const SizedBox(height: 24),

            // ─── Quick Stats Grid ──
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Next Period',
                    value: daysUntil > 0 ? '$daysUntil' : 'Due',
                    subtitle: daysUntil > 0 ? 'days away' : 'today',
                    icon: Icons.water_drop,
                    color: WellnessTheme.menstrual,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Ovulation',
                    value: ovDays > 0 ? '$ovDays' : (ovDays == 0 ? 'Today' : 'Passed'),
                    subtitle: ovDays > 0 ? 'days away' : null,
                    icon: Icons.star,
                    color: WellnessTheme.ovulationDay,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Cycle Length',
                    value: '${avgCycle.round()}d',
                    subtitle: 'average',
                    icon: Icons.loop,
                    color: WellnessTheme.luteal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Confidence',
                    value: '${(confidence * 100).round()}%',
                    subtitle: '${_cycleHistory.length} cycles logged',
                    icon: Icons.verified,
                    color: WellnessTheme.follicular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Log Period CTA ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LogPeriodScreen(date: DateTime.now()),
                    ),
                  );
                  _loadData();
                },
                icon: const Icon(Icons.water_drop, size: 18),
                label: const Text('Log Period'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WellnessTheme.menstrual,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Today's Logs Summary ──
            if (_todayLog != null || _todayPeriod != null) ...[
              const SizedBox(height: 8),
              _buildTodaySummary(context),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Color> _gradientForPhase(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return WellnessTheme.periodGradient;
      case CyclePhase.follicular:
        return WellnessTheme.fertileGradient;
      case CyclePhase.ovulation:
        return WellnessTheme.ovulationGradient;
      case CyclePhase.luteal:
        return WellnessTheme.dashboardGradient;
    }
  }

  DailyLog? get _todayLog {
    final today = DateTime.now();
    final key = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      return _dailyLogs.firstWhere((l) {
        final d = l.date;
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' == key;
      });
    } catch (_) {
      return null;
    }
  }

  PeriodLog? get _todayPeriod {
    final today = DateTime.now();
    final key = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      return _periodLogs.firstWhere((l) {
        final d = l.date;
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' == key;
      });
    } catch (_) {
      return null;
    }
  }

  Widget _buildTodaySummary(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: WellnessTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Log",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_todayPeriod != null) ...[
            Row(
              children: [
                Icon(Icons.water_drop, size: 16, color: WellnessTheme.menstrual),
                const SizedBox(width: 6),
                Text(
                  'Flow: ${flowLabels[_todayPeriod!.flow] ?? 'Logged'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (_todayLog?.mood != null) ...[
            Row(
              children: [
                Text(moodEmojis[_todayLog!.mood!] ?? '', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  'Mood: ${moodLabels[_todayLog!.mood!] ?? ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (_todayLog != null && _todayLog!.waterIntakeMl > 0)
            Row(
              children: [
                const Icon(Icons.local_drink, size: 16, color: Colors.blueAccent),
                const SizedBox(width: 6),
                Text(
                  'Water: ${_todayLog!.waterIntakeMl}ml',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
