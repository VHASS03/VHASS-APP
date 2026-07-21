import 'package:flutter/material.dart';
import '../models/wellness_settings.dart';
import '../services/wellness_tracker_service.dart';

/// Settings screen for configuring cycle length, period length, reminders, and data export/deletion.
class TrackerSettingsScreen extends StatefulWidget {
  const TrackerSettingsScreen({super.key});

  @override
  State<TrackerSettingsScreen> createState() => _TrackerSettingsScreenState();
}

class _TrackerSettingsScreenState extends State<TrackerSettingsScreen> {
  bool _loading = true;
  WellnessSettings _settings = WellnessSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await WellnessTrackerService.getSettings();
    if (mounted) {
      setState(() {
        _settings = settings;
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings(WellnessSettings updated) async {
    await WellnessTrackerService.saveSettings(updated);
    setState(() {
      _settings = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracker Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── CYCLE BASICS ──
          _buildSectionHeader('CYCLE BASICS'),
          _buildCycleLengthPicker(context),
          _buildPeriodLengthPicker(context),
          const SizedBox(height: 24),

          // ─── REMINDERS ──
          _buildSectionHeader('REMINDERS & NOTIFICATIONS'),
          SwitchListTile(
            title: const Text('Period Reminders'),
            subtitle: const Text('Notify me a few days before expected period'),
            value: _settings.periodReminder,
            onChanged: (val) {
              _saveSettings(_settings.copyWith(periodReminder: val));
            },
          ),
          SwitchListTile(
            title: const Text('Ovulation Reminders'),
            subtitle: const Text('Notify me on predicted ovulation day'),
            value: _settings.ovulationReminder,
            onChanged: (val) {
              _saveSettings(_settings.copyWith(ovulationReminder: val));
            },
          ),
          SwitchListTile(
            title: const Text('Daily Log Reminders'),
            subtitle: const Text('Daily reminder to log mood and symptoms'),
            value: _settings.dailyLogReminder,
            onChanged: (val) {
              _saveSettings(_settings.copyWith(dailyLogReminder: val));
            },
          ),
          const SizedBox(height: 24),

          // ─── DATA MANAGEMENT ──
          _buildSectionHeader('DATA MANAGEMENT'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Wellness Data', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently erase logs, history, and preferences'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: const Text(
                      'This action cannot be undone. All period logs, cycle history, and custom settings will be deleted.'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await WellnessTrackerService.clearAllData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All wellness data cleared.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          Navigator.pop(context); // Go back to tracker
                        }
                      },
                      child: const Text('Clear Data'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCycleLengthPicker(BuildContext context) {
    return ListTile(
      title: const Text('Cycle Length'),
      trailing: DropdownButton<int>(
        value: _settings.cycleLength,
        items: List.generate(45, (i) => i + 15).map((val) {
          return DropdownMenuItem<int>(
            value: val,
            child: Text('$val days'),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            _saveSettings(_settings.copyWith(cycleLength: val));
          }
        },
      ),
    );
  }

  Widget _buildPeriodLengthPicker(BuildContext context) {
    return ListTile(
      title: const Text('Period Duration'),
      trailing: DropdownButton<int>(
        value: _settings.periodLength,
        items: List.generate(15, (i) => i + 1).map((val) {
          return DropdownMenuItem<int>(
            value: val,
            child: Text('$val days'),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            _saveSettings(_settings.copyWith(periodLength: val));
          }
        },
      ),
    );
  }
}
