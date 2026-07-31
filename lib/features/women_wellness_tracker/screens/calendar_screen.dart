import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../constants/wellness_constants.dart';
import '../models/period_log.dart';
import '../models/cycle_data.dart';
import '../models/wellness_settings.dart';
import '../services/wellness_tracker_service.dart';
import '../utils/cycle_calculator.dart';
import '../theme/wellness_theme.dart';
import 'log_period_screen.dart';

/// Calendar screen showing cycle phases, periods, fertile days, and logged periods.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _loading = true;
  WellnessSettings _settings = WellnessSettings();
  List<PeriodLog> _periodLogs = [];
  List<CycleData> _cycleHistory = [];
  DateTime _lastPeriodStart = DateTime.now().subtract(const Duration(days: 10));

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Track selected day detail
  PeriodLog? _selectedPeriodLog;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final settings = await WellnessTrackerService.getSettings();
    final periodLogs = await WellnessTrackerService.getPeriodLogs();
    final cycleHistory = await WellnessTrackerService.getCycleHistory();

    DateTime lastStart = DateTime.now().subtract(const Duration(days: 10));
    if (periodLogs.isNotEmpty) {
      final sorted = List<PeriodLog>.from(periodLogs)
        ..sort((a, b) => b.date.compareTo(a.date));
      lastStart = sorted.first.date;
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
        _cycleHistory = cycleHistory;
        _lastPeriodStart = lastStart;
        _loading = false;
      });
      _updateSelectedDayLog();
    }
  }

  void _updateSelectedDayLog() {
    if (_selectedDay == null) return;
    final key = _dateKey(_selectedDay!);
    try {
      _selectedPeriodLog = _periodLogs.firstWhere(
        (l) => _dateKey(l.date) == key,
      );
    } catch (_) {
      _selectedPeriodLog = null;
    }
  }

  String _dateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  bool _isPeriod(DateTime date) {
    return CycleCalculator.isPeriodDay(
      date,
      _lastPeriodStart,
      _settings.periodLength,
      _settings.cycleLength,
    );
  }

  bool _isFertile(DateTime date) {
    return CycleCalculator.isFertileDay(
      date,
      _lastPeriodStart,
      _settings.cycleLength,
    );
  }

  bool _isOvulation(DateTime date) {
    return CycleCalculator.isOvulationDay(
      date,
      _lastPeriodStart,
      _settings.cycleLength,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          // ─── CALENDAR CONTAINER ───
          Container(
            padding: const EdgeInsets.all(12),
            decoration: WellnessTheme.cardDecoration(context),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _updateSelectedDayLog();
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              // Styles
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(16),
                ),
                formatButtonTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                leftChevronIcon: const Icon(Icons.chevron_left, size: 20),
                rightChevronIcon: const Icon(Icons.chevron_right, size: 20),
              ),
              // Custom Day Builders for Cycle Colors
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return _buildCustomDay(day);
                },
                selectedBuilder: (context, day, focusedDay) {
                  return _buildCustomDay(day, isSelected: true);
                },
                todayBuilder: (context, day, focusedDay) {
                  return _buildCustomDay(day, isToday: true);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── LEGEND ───
          Wrap(
            spacing: 14,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem('Period', WellnessTheme.periodDay),
              _buildLegendItem('Fertile Window', WellnessTheme.fertileDay),
              _buildLegendItem('Ovulation Day', WellnessTheme.ovulationDay),
            ],
          ),
          const SizedBox(height: 20),

          // ─── DAY DETAIL SECTION ───
          _buildDayDetailCard(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCustomDay(DateTime day, {bool isSelected = false, bool isToday = false}) {
    Color? cellColor;
    Color? textColor;
    bool hasIndicator = false;
    Color indicatorColor = Colors.transparent;

    final isPeriodVal = _isPeriod(day);
    final isFertileVal = _isFertile(day);
    final isOvulationVal = _isOvulation(day);

    if (isPeriodVal) {
      cellColor = WellnessTheme.periodDay;
      textColor = Colors.white;
    } else if (isOvulationVal) {
      cellColor = WellnessTheme.ovulationDay;
      textColor = Colors.white;
    } else if (isFertileVal) {
      cellColor = WellnessTheme.fertileDay.withOpacity(0.2);
      textColor = WellnessTheme.fertileDay;
    }

    if (isSelected) {
      textColor = Colors.white;
    }

    final hasLog = _periodLogs.any((l) => isSameDay(l.date, day));
    if (hasLog) {
      hasIndicator = true;
      indicatorColor = cellColor != null ? Colors.white : Colors.pinkAccent;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : (isToday && cellColor == null
                ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                : cellColor),
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: Colors.white, width: 1.5)
            : (isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              color: textColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected || isToday || isPeriodVal || isOvulationVal
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          if (hasIndicator)
            Positioned(
              bottom: 4,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDayDetailCard(BuildContext context) {
    if (_selectedDay == null) return const SizedBox();

    final isLogDate = _selectedPeriodLog != null;
    final formattedDate = '${_selectedDay!.day} ${_getMonthName(_selectedDay!.month)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: WellnessTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLogDate ? 'Symptom Log Summary' : 'No entries registered',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LogPeriodScreen(date: _selectedDay!),
                    ),
                  );
                  _loadData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLogDate ? Colors.transparent : WellnessTheme.menstrual.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: WellnessTheme.menstrual,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isLogDate ? 'Edit Log' : '+ Add Log',
                    style: const TextStyle(
                      color: WellnessTheme.menstrual,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isLogDate) ...[
            const Divider(height: 24),
            // Flow Details
            if (_selectedPeriodLog!.flow != null)
              _buildDetailItem(
                icon: Icons.water_drop,
                color: WellnessTheme.periodDay,
                label: 'Flow Intensity',
                value: flowLabels[_selectedPeriodLog!.flow] ?? '',
              ),
            // Pain details
            if (_selectedPeriodLog!.painLevel > 0)
              _buildDetailItem(
                icon: Icons.personal_injury,
                color: Colors.orangeAccent,
                label: 'Pain Level',
                value: '${_selectedPeriodLog!.painLevel}/10',
              ),
            // Symptoms Details
            if (_selectedPeriodLog!.symptoms.isNotEmpty)
              _buildDetailItem(
                icon: Icons.favorite,
                color: Colors.pinkAccent,
                label: 'Symptoms',
                value: _selectedPeriodLog!.symptoms.map((s) => symptomLabels[s] ?? '').join(', '),
              ),
            // Mood details
            if (_selectedPeriodLog!.mood != null)
              _buildDetailItem(
                icon: Icons.face,
                color: Colors.purpleAccent,
                label: 'Mood',
                value: '${moodEmojis[_selectedPeriodLog!.mood]} ${moodLabels[_selectedPeriodLog!.mood]}',
              ),
            // Journal/Notes Details
            if (_selectedPeriodLog!.notes.isNotEmpty)
              _buildDetailItem(
                icon: Icons.edit_note,
                color: Colors.teal,
                label: 'Notes',
                value: _selectedPeriodLog!.notes,
              ),
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Select a day and click "+ Add Log" to record details.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
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
