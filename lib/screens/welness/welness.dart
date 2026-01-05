import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  // --- STATE VARIABLES ---
  // Defaulting to 2 days ago so the Daily Tracker is visible immediately for testing
  DateTime _lastPeriodDate = DateTime.now().subtract(const Duration(days: 2));
  int _cycleLength = 28;
  int _periodLength = 5;
  final List<Map<String, dynamic>> _healthNotes = [];

  // --- LOGIC CALCULATIONS ---
  DateTime get _nextPeriodDate => _lastPeriodDate.add(Duration(days: _cycleLength));
  
  int get _daysUntilNextPeriod {
    final diff = _nextPeriodDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get _isCurrentlyOnPeriod {
    final today = DateTime.now();
    // Calculate difference in days (ignoring time)
    final difference = DateTime(today.year, today.month, today.day)
        .difference(DateTime(_lastPeriodDate.year, _lastPeriodDate.month, _lastPeriodDate.day))
        .inDays;
    return difference >= 0 && difference < _periodLength;
  }

  int get _currentPeriodDay {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day)
        .difference(DateTime(_lastPeriodDate.year, _lastPeriodDate.month, _lastPeriodDate.day))
        .inDays + 1;
  }

  // --- INTERACTION METHODS ---
  Future<void> _selectLastPeriod(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastPeriodDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF9146FF),
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _lastPeriodDate = picked);
    }
  }

  void _showNoteDialog() {
    TextEditingController noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Log Health Note", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: TextField(
          controller: noteController,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: const InputDecoration(hintText: "Mood, symptoms, or pain level..."),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.isNotEmpty) {
                setState(() {
                  _healthNotes.insert(0, {
                    'date': DateTime.now(),
                    'note': noteController.text,
                  });
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Women Wellness', 
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // --- 1. PREDICTION DASHBOARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9146FF), Color(0xFF6A1B9A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF9146FF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_isCurrentlyOnPeriod ? 'Current Status' : 'Next Period In', 
                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(_isCurrentlyOnPeriod ? 'Period Day $_currentPeriodDay' : '$_daysUntilNextPeriod Days',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Icon(Icons.water_drop, color: Colors.white, size: 40),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoSmall("Expected", DateFormat('MMM dd').format(_nextPeriodDate)),
                      _buildInfoSmall("Cycle Log", "$_cycleLength Days"),
                    ],
                  )
                ],
              ),
            ),

            // --- 2. DAILY TRACKER SHEET (Active only during period) ---
            if (_isCurrentlyOnPeriod) ...[
              const SizedBox(height: 24),
              _buildDailyTrackerSheet(theme, isDark),
            ],

            const SizedBox(height: 20),

            // --- 3. CYCLE SETTINGS ---
            Row(
              children: [
                _buildSummaryCard(context, 'Cycle Length', '$_cycleLength Days', Icons.refresh),
                const SizedBox(width: 16),
                _buildSummaryCard(context, 'Duration', '$_periodLength Days', Icons.calendar_today),
              ],
            ),

            const SizedBox(height: 24),

            // --- 4. ACTION TILES ---
            _buildActionTile(
              context, 
              Icons.edit_calendar, 
              'Update Last Period', 
              'Start: ${DateFormat('MMM dd').format(_lastPeriodDate)}',
              onTap: () => _selectLastPeriod(context),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              context, 
              Icons.note_alt_outlined, 
              'Log Symptoms', 
              'Track mood, pain, or flow',
              onTap: _showNoteDialog,
            ),

            const SizedBox(height: 24),

            // --- 5. NOTES LIST ---
            if (_healthNotes.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Recent Notes", 
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _healthNotes.length > 3 ? 3 : _healthNotes.length,
                itemBuilder: (context, index) {
                  final item = _healthNotes[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['note'], style: TextStyle(color: textColor, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(DateFormat('MMM dd, hh:mm a').format(item['date']), 
                             style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 30),
            _buildPrivacyFooter(isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- BUILDER METHODS ---

  Widget _buildDailyTrackerSheet(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.2)),
        boxShadow: [if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text("Active Period Tracker", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_periodLength, (index) {
              bool isPast = index < _currentPeriodDay - 1;
              bool isToday = index == _currentPeriodDay - 1;

              return Column(
                children: [
                  Text("D${index + 1}", style: TextStyle(fontSize: 10, color: isToday ? const Color(0xFF9146FF) : Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? const Color(0xFF9146FF) : (isPast ? const Color(0xFF9146FF).withOpacity(0.2) : Colors.transparent),
                      border: Border.all(color: isPast || isToday ? const Color(0xFF9146FF) : Colors.grey.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: isPast 
                        ? const Icon(Icons.check, size: 16, color: Color(0xFF9146FF)) 
                        : Text("${index + 1}", style: TextStyle(color: isToday ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSmall(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF9146FF), size: 20),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            Text(value, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF9146FF).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.edit, color: Color(0xFF9146FF), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyFooter(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 14),
        const SizedBox(width: 8),
        Text('Secure, local-only health tracking',
            style: TextStyle(color: isDark ? Colors.grey : Colors.grey[700], fontSize: 11)),
      ],
    );
  }
}