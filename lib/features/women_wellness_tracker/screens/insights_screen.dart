import 'package:flutter/material.dart';
import '../models/period_log.dart';
import '../models/daily_log.dart';
import '../models/cycle_data.dart';
import '../models/wellness_settings.dart';
import '../services/wellness_tracker_service.dart';
import '../utils/insights_engine.dart';
import '../theme/wellness_theme.dart';

/// Insights screen displaying generated health tips, warnings, and guidelines.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _loading = true;
  List<HealthInsight> _insights = [];

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final settings = await WellnessTrackerService.getSettings();
    final cycleHistory = await WellnessTrackerService.getCycleHistory();
    final periodLogs = await WellnessTrackerService.getPeriodLogs();
    final dailyLogs = await WellnessTrackerService.getDailyLogs();

    final list = InsightsEngine.generateInsights(
      cycleHistory: cycleHistory,
      periodLogs: periodLogs,
      dailyLogs: dailyLogs,
      cycleLength: settings.cycleLength,
      periodLength: settings.periodLength,
    );

    if (mounted) {
      setState(() {
        _insights = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle Insights'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _insights.length,
              itemBuilder: (context, idx) {
                final insight = _insights[idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: WellnessTheme.cardDecoration(context),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.icon,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insight.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                insight.body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                            ],
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
}
