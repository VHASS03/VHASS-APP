import 'package:flutter/material.dart';
import '../../core/widgets/sos_button.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/wake_word_service.dart';
import '../../core/services/sos_alert_service.dart';
import '../../core/config/api_config.dart';
import '../../core/colors.dart';
import '../emergency/emergency.dart';
import '../contacts/contacts.dart';
import '../voice_sos/voice.dart';
import '../welness/welness.dart';
import '../welness/wellness_hub.dart';
import '../security/security_portal.dart';
import '../chat_screen.dart';
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
          setState(() {
            _incomingSOSAlert = alert;
          });
          _showSOSAlertBanner(alert);
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize alert listener: $e');
    }
  }

  /// Display persistent SOS alert banner
  void _showSOSAlertBanner(SOSAlert alert) {
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
              color: AppColors.emergency,
              boxShadow: [
                BoxShadow(
                  color: AppColors.emergency.withOpacity(0.5),
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
                            debugPrint('Viewing ${alert.userName} location');
                          },
                          icon: const Icon(Icons.location_on),
                          label: const Text('View Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.emergency,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            debugPrint('Calling ${alert.userName}');
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

  Future<void> _initializeAndStartVoiceService() async {
    try {
      await WakeWordService.startService();
      final isEnabled = await WakeWordService.isServiceEnabled();
      if (mounted) {
        setState(() {
          _isVoiceServiceRunning = isEnabled;
        });

        if (isEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.mic, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '✅ Voice listening is active — Say "help me out"',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.mintAccent.withOpacity(0.85),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to start voice service: $e');
    }
  }

  @override
  void dispose() {
    _sosAlertOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.lavender],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Syava AI',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: theme.textTheme.bodyLarge?.color,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 0),
                        Text(
                          "You're safe with us 💜",
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.primary.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                  const SizedBox(height: 28),
                  Text(
                    'Press & hold for 2 seconds',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'or say "Help me out"',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF9B89A8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // --- BOTTOM FEATURE CARDS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFeatureCard(
                      context,
                      Icons.group_outlined,
                      'Contacts',
                      const ContactsScreen(),
                      accentColor: AppColors.lavender,
                    ),
                    const SizedBox(width: 12),
                    _buildFeatureCard(
                      context,
                      Icons.favorite_border_rounded,
                      'Wellness',
                      const WellnessHubScreen(),
                      accentColor: AppColors.blush,
                    ),

                    const SizedBox(width: 12),
                    _buildFeatureCard(
                      context,
                      Icons.chat_bubble_outline_rounded,
                      'Chat',
                      null,
                      isChatButton: true,
                      accentColor: AppColors.mintAccent,
                    ),
                    const SizedBox(width: 12),
                    _buildFeatureCard(
                      context,
                      Icons.settings_outlined,
                      'Settings',
                      const SettingsScreen(),
                      accentColor: AppColors.peach,
                    ),
                  ],
                ),
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
    Color accentColor = AppColors.primary,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        if (isChatButton) {
          final token = await StorageService.getToken();
          if (token == null) {
            if (!context.mounted) return;
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: isDark
              ? accentColor.withOpacity(0.10)
              : accentColor.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withOpacity(isDark ? 0.20 : 0.15),
            width: 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: accentColor.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accentColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
