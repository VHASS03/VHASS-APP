import 'package:flutter/material.dart';
import '../../core/widgets/sos_button.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/background_voice_service.dart';
import '../../core/services/sos_alert_service.dart';
import '../../core/config/api_config.dart';
import '../emergency/emergency.dart';
import '../contacts/contacts.dart';
import '../voice_sos/voice.dart';
import '../welness/welness.dart';
import '../chat_screen.dart'; // Use the functional chat screen, not chat/chat.dart
import '../Settings/settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isVoiceServiceRunning = false;
  SOSAlert? _incomingSOSAlert;
  late OverlayEntry? _sosAlertOverlay = null;

  @override
  void initState() {
    super.initState();
    _initializeAndStartVoiceService();
    _initializeSOSAlertListener();
  }

  /// Listen for incoming SOS alerts from emergency contacts
  void _initializeSOSAlertListener() {
    try {
      SOSAlertService.onAlertReceived((alert) {
        if (mounted) {
          print('🚨 [HomeScreen] Received SOS alert from ${alert.userName}');
          setState(() {
            _incomingSOSAlert = alert;
          });

          // Show persistent notification banner
          _showSOSAlertBanner(alert);
        }
      });
      print('✅ [HomeScreen] SOS alert listener initialized');
    } catch (e) {
      print('❌ [HomeScreen] Failed to initialize alert listener: $e');
    }
  }

  /// Display persistent SOS alert banner
  void _showSOSAlertBanner(SOSAlert alert) {
    // Remove previous overlay if exists
    _sosAlertOverlay?.remove();

    _sosAlertOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emergency_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🚨 EMERGENCY ALERT',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${alert.userName} has triggered an SOS emergency!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (alert.latitude != null &&
                                alert.longitude != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Location: ${alert.latitude?.toStringAsFixed(4)}, ${alert.longitude?.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _sosAlertOverlay?.remove();
                          _sosAlertOverlay = null;
                          setState(() {
                            _incomingSOSAlert = null;
                          });
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Could open map or contact details here
                            print('Viewing ${alert.userName} location');
                          },
                          icon: const Icon(Icons.location_on),
                          label: const Text('View Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Could call the contact
                            print('Calling ${alert.userName}');
                          },
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text(
                            'Call',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_sosAlertOverlay!);
  }

  /// Initialize and automatically start voice listening on login
  /// The app will listen for voice commands while user is logged in
  Future<void> _initializeAndStartVoiceService() async {
    try {
      // Auto-start voice service when user is logged in
      // This ensures continuous listening for voice SOS
      await BackgroundVoiceService.startBackgroundService();

      // Check status
      final isEnabled = await BackgroundVoiceService.isServiceEnabled();
      if (mounted) {
        setState(() {
          _isVoiceServiceRunning = isEnabled;
        });

        if (isEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.mic, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '✅ Voice listening is ACTIVE - Say "help me out" for emergency',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Failed to start voice service: $e');
    }
  }

  @override
  void dispose() {
    // Remove SOS alert overlay if exists
    _sosAlertOverlay?.remove();
    // Voice service continues running in background even after leaving home
    // It will only stop when user explicitly logs out
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Accessing theme values instead of hardcoded AppColors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // 1. Dynamic Background
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary, // Using primary from theme
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VHASS',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            // 2. Dynamic Text Color
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              "You're protected",
                              style: TextStyle(
                                // 3. Dynamic Secondary Text
                                color: isDark
                                    ? Colors.blueGrey[200]
                                    : Colors.blueGrey[600],
                                fontSize: 12,
                              ),
                            ),
                            if (_isVoiceServiceRunning) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.mic,
                                      size: 10,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Listening',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    // 4. Dynamic Icon Color
                    icon: Icon(
                      Icons.settings_outlined,
                      color: isDark ? Colors.grey : Colors.black54,
                    ),
                    style: IconButton.styleFrom(
                      // 5. Dynamic IconButton background
                      backgroundColor: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // --- CENTER SOS SECTION ---
            Center(
              child: Column(
                children: [
                  SOSButton(
                    onActivate: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmergencyActiveScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Press & hold for 2 seconds',
                    style: TextStyle(
                      // 6. Dynamic Main Label Color
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'or say "Help me out"',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // --- BOTTOM FEATURE CARDS ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFeatureCard(
                    context,
                    Icons.group_outlined,
                    'Contacts',
                    const ContactsScreen(),
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.mic_none_rounded,
                    'Voice',
                    const VoiceSOSScreen(),
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.favorite_border_rounded,
                    'Wellness',
                    const WellnessScreen(),
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.chat_bubble_outline_rounded,
                    'Chat',
                    null, // Will be created dynamically
                    isChatButton: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String label,
    Widget? destination, {
    bool isChatButton = false,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () async {
        // For chat button, create ChatScreen with token and serverUrl
        if (isChatButton) {
          final token = await StorageService.getToken();
          if (token == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required. Please log in again.'),
              ),
            );
            return;
          }
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                token: token,
                serverUrl: ApiConfig.baseUrl.replaceFirst('/api', ''),
              ),
            ),
          );
        } else if (destination != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        }
      },
      child: Container(
        width: 80,
        height: 90,
        decoration: BoxDecoration(
          // 7. Dynamic Card Background
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          // Added a subtle shadow for light mode visibility
          boxShadow: [
            if (theme.brightness == Brightness.light)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 8. Dynamic Icon color (primary)
            Icon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                // 9. Dynamic Label color
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
