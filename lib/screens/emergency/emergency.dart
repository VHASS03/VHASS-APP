import 'package:flutter/material.dart';
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';

class EmergencyActiveScreen extends StatefulWidget {
  const EmergencyActiveScreen({super.key});

  @override
  State<EmergencyActiveScreen> createState() => _EmergencyActiveScreenState();
}

class _EmergencyActiveScreenState extends State<EmergencyActiveScreen> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  late StreamSubscription<BatteryState> _batterySubscription;

  // --- STOPWATCH VARIABLES ---
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _getBatteryLevel();
    _startStopwatch(); // Start counting when screen opens
    
    _batterySubscription = _battery.onBatteryStateChanged.listen((BatteryState state) {
      _getBatteryLevel();
    });
  }

  // Logic to increment timer every second
  void _startStopwatch() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime += const Duration(seconds: 1);
      });
    });
  }

  // Helper to format Duration into 0:00 string
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _getBatteryLevel() async {
    final level = await _battery.batteryLevel;
    if (mounted) {
      setState(() {
        _batteryLevel = level;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Stop the timer and clear memory
    _batterySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // --- RED STATUS HEADER ---
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMERGENCY ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Contacts being notified',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_elapsedTime), // DISPLAY DYNAMIC TIME
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 16,
                        fontFeatures: [FontFeature.tabularFigures()], // Keeps numbers from jumping
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ... Rest of your Column code remains exactly the same ...
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withOpacity(0.1),
                      ),
                    ),
                    const Icon(Icons.location_on, color: Color(0xFFD32F2F), size: 60),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Live location tracking active',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color, 
                    fontSize: 16, 
                    fontWeight: FontWeight.w500
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Updates every 5 seconds',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey[600], 
                    fontSize: 14
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F0F14) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Help is being notified',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color, 
                          fontSize: 18, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stay calm. We\'re reaching your contacts.',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey[700], 
                          fontSize: 14
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatusItem(context, Icons.battery_std, 'Battery', '$_batteryLevel%'),
                    const SizedBox(width: 16),
                    _buildStatusItem(context, Icons.phone_in_talk, 'Calling', '3 contacts'),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF2C2C35) : Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Cancel Emergency (PIN required)',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F14) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  value, 
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}