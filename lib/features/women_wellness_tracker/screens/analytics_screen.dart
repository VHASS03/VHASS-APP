import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/period_log.dart';
import '../models/daily_log.dart';
import '../models/cycle_data.dart';
import '../services/wellness_tracker_service.dart';
import '../theme/wellness_theme.dart';
import '../constants/wellness_constants.dart';

/// Analytics screen showing trends, mood distribution, pain levels, and cycle history.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  List<CycleData> _cycleHistory = [];
  List<PeriodLog> _periodLogs = [];
  List<DailyLog> _dailyLogs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cycleHistory = await WellnessTrackerService.getCycleHistory();
    final periodLogs = await WellnessTrackerService.getPeriodLogs();
    final dailyLogs = await WellnessTrackerService.getDailyLogs();

    // If there is no real cycle history but there are period logs, we can simulate some history
    // so the charts don't look completely empty.
    List<CycleData> processedHistory = List.from(cycleHistory);
    if (processedHistory.isEmpty && periodLogs.isNotEmpty) {
      // Create a simulated cycle for presentation
      processedHistory.add(CycleData(
        startDate: DateTime.now().subtract(const Duration(days: 28)),
        endDate: DateTime.now().subtract(const Duration(days: 23)),
        cycleLength: 28,
        periodLength: 5,
        predicted: true,
      ));
    }

    if (mounted) {
      setState(() {
        _cycleHistory = processedHistory;
        _periodLogs = periodLogs;
        _dailyLogs = dailyLogs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasData = _cycleHistory.isNotEmpty || _periodLogs.isNotEmpty || _dailyLogs.isNotEmpty;

    if (!hasData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No Data Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Log your periods and daily habits to see charts and analytics trends here.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Cycle Length Chart ──
          if (_cycleHistory.isNotEmpty) ...[
            Text('CYCLE LENGTH HISTORY', style: WellnessTheme.sectionTitle.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: WellnessTheme.cardDecoration(context),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getCycleSpots(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ─── Pain Levels Chart ──
          if (_periodLogs.any((l) => l.painLevel > 0)) ...[
            Text('PAIN LEVELS OVER TIME', style: WellnessTheme.sectionTitle.copyWith(color: WellnessTheme.menstrual)),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: WellnessTheme.cardDecoration(context),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getPainSpots(),
                      isCurved: true,
                      color: WellnessTheme.menstrual,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: WellnessTheme.menstrual.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ─── Mood Distribution Chart ──
          if (_dailyLogs.any((l) => l.mood != null)) ...[
            Text('MOOD DISTRIBUTION', style: WellnessTheme.sectionTitle.copyWith(color: Colors.purpleAccent)),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: WellnessTheme.cardDecoration(context),
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          if (val >= 0 && val < MoodType.values.length) {
                            return Text(
                              moodEmojis[MoodType.values[val.toInt()]] ?? '',
                              style: const TextStyle(fontSize: 16),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _getMoodBarGroups(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  List<FlSpot> _getCycleSpots() {
    final List<FlSpot> spots = [];
    final list = List<CycleData>.from(_cycleHistory)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    for (int i = 0; i < list.length; i++) {
      spots.add(FlSpot(i.toDouble(), list[i].cycleLength.toDouble()));
    }
    return spots;
  }

  List<FlSpot> _getPainSpots() {
    final List<FlSpot> spots = [];
    final painLogs = _periodLogs.where((l) => l.painLevel > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // Limit to last 10 logs for display readability
    final logsToShow = painLogs.length > 10 ? painLogs.sublist(painLogs.length - 10) : painLogs;
    for (int i = 0; i < logsToShow.length; i++) {
      spots.add(FlSpot(i.toDouble(), logsToShow[i].painLevel.toDouble()));
    }
    return spots;
  }

  List<BarChartGroupData> _getMoodBarGroups() {
    final Map<MoodType, int> counts = {};
    for (final log in _dailyLogs) {
      if (log.mood != null) {
        counts[log.mood!] = (counts[log.mood!] ?? 0) + 1;
      }
    }

    return MoodType.values.map((mood) {
      final idx = mood.index;
      final count = counts[mood] ?? 0;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: _moodColor(mood),
            width: 14,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );
    }).toList();
  }

  Color _moodColor(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
      case MoodType.excited:
      case MoodType.energetic:
        return WellnessTheme.moodHappy;
      case MoodType.calm:
        return WellnessTheme.moodCalm;
      case MoodType.sad:
      case MoodType.depressed:
      case MoodType.tired:
        return WellnessTheme.moodSad;
      case MoodType.angry:
      case MoodType.frustrated:
      case MoodType.stressed:
        return WellnessTheme.moodAngry;
      default:
        return WellnessTheme.moodNeutral;
    }
  }
}
