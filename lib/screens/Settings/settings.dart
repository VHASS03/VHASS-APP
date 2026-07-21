import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../theme_controller.dart';
import 'safety_device.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/wake_word_service.dart';
import '../../core/services/wellness_service.dart';
import '../../core/services/health_reminder_service.dart';
import '../auth/login_screen.dart';

// --- ADDED THIS CLASS: The missing parent widget ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _userPhone;
  String? _userName;
  String? _userId;
  String? _deviceId;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final phone = await StorageService.getPhone();
    final name = await StorageService.getUserName();
    final notificationsEnabled = await StorageService.areNotificationsEnabled();
    final userId = await StorageService.getUserId();
    final deviceId = await StorageService.getDeviceId();
    setState(() {
      _userPhone = phone;
      _userName = name;
      _notificationsEnabled = notificationsEnabled ?? true;
      _userId = userId;
      _deviceId = deviceId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Settings"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("PROFILE"),
            _buildSettingCard(
              title: _userName ?? "Your Profile",
              subtitle: _userPhone ?? "+91 98765 43210",
              icon: Icons.person_outline,
              onTap: () {
                // Show profile dialog with user info
                _showProfileDialog();
              },
            ),

            _buildSectionHeader("SAFETY"),
            _buildSettingCard(
              title: "Safety Device",
              subtitle: "BLE & Bluetooth SOS button",
              icon: Icons.bluetooth_searching,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SafetyDeviceScreen(),
                  ),
                );
              },
            ),

            _buildSectionHeader("PREFERENCES"),
            _buildSettingCard(
              title: "Dark Mode",
              icon: isDark ? Icons.dark_mode : Icons.light_mode,
              trailing: Switch(
                value: isDark,
                activeThumbColor: AppColors.primary,
                onChanged: (bool value) {
                  // Ensure themeNotifier is defined in your theme_controller.dart
                  themeNotifier.value = value
                      ? ThemeMode.dark
                      : ThemeMode.light;
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingCard(
              title: "Notifications",
              subtitle: _notificationsEnabled ? "On" : "Off",
              icon: _notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              trailing: Switch(
                value: _notificationsEnabled,
                activeColor: AppColors.primary,
                onChanged: (bool value) async {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  await StorageService.setNotificationsEnabled(value);
                },
              ),
            ),

            _buildSectionHeader("HEALTH REMINDERS"),
            _buildSettingCard(
              title: "Health Reminders",
              subtitle: "Water, posture, eye breaks & more",
              icon: Icons.health_and_safety,
              onTap: () => _showHealthReminderSettings(),
            ),

            _buildSectionHeader("SUPPORT"),
            _buildSettingCard(title: "Help & FAQs", icon: Icons.help_outline),

            const SizedBox(height: 32),
            _buildLogoutButton(),
            const SizedBox(height: 24),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    String? subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: () {
        _showLogoutDialog();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.5)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text(
              "Logout",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Column(
        children: [
          Text(
            "Syava AI v1.0.0",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          SizedBox(height: 2),
          Text(
            "powered by VHASS",
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          SizedBox(height: 4),
          Text(
            "Made with care for your safety 💜",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? Voice listening will be stopped and your session will end.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Stop voice listening before logout
                await WakeWordService.stopService();
                print('🛑 Voice service stopped on logout');

                // Get userId before clearing auth data
                final userId = await StorageService.getUserId();
                if (userId != null && userId.isNotEmpty) {
                  // Clear user's wellness data
                  await WellnessService.clearUserWellnessData(userId);
                  print('🧹 Wellness data cleared for user $userId');
                }
              } catch (e) {
                print('❌ Error during logout cleanup: $e');
              }

              // Clear all auth data
              await AuthService.logout();

              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "ProfileDetails",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: EdgeInsets.zero,
              content: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  decoration: BoxDecoration(color: Theme.of(context).cardColor),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with Gradient and Avatar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.lavender],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                  child: Text(
                                    (_userName != null && _userName!.isNotEmpty)
                                        ? _userName![0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _userName ?? 'User Profile',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userPhone ?? 'No Phone Number',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Details Section
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            _buildProfileDetailRow(
                              icon: Icons.person_outline,
                              label: "Full Name",
                              value: _userName ?? 'Not specified',
                            ),
                            const Divider(height: 24),
                            _buildProfileDetailRow(
                              icon: Icons.phone_android,
                              label: "Phone Number",
                              value: _userPhone ?? 'Not specified',
                            ),
                          ],
                        ),
                      ),
                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 20,
                          left: 24,
                          right: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isCode = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: isCode ? 'monospace' : null,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHealthReminderSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _HealthReminderSettingsSheet(),
    );
  }
}

/// Health Reminder Settings Bottom Sheet
class _HealthReminderSettingsSheet extends StatefulWidget {
  const _HealthReminderSettingsSheet();

  @override
  State<_HealthReminderSettingsSheet> createState() =>
      _HealthReminderSettingsSheetState();
}

class _HealthReminderSettingsSheetState
    extends State<_HealthReminderSettingsSheet> {
  bool _remindersEnabled = true;
  int _intervalMinutes = 30;
  bool _waterReminders = true;
  bool _postureReminders = true;
  bool _eyeBreakReminders = true;
  bool _stretchReminders = true;
  bool _wellnessTips = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await HealthReminderService.getSettings();
    if (mounted) {
      setState(() {
        _remindersEnabled = settings['enabled'] ?? true;
        _intervalMinutes = settings['intervalMinutes'] ?? 30;
        _waterReminders = settings['waterReminders'] ?? true;
        _postureReminders = settings['postureReminders'] ?? true;
        _eyeBreakReminders = settings['eyeBreakReminders'] ?? true;
        _stretchReminders = settings['stretchReminders'] ?? true;
        _wellnessTips = settings['wellnessTips'] ?? true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Icon(
                    Icons.health_and_safety,
                    color: Colors.green[600],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Health Reminders',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Get periodic reminders to drink water, fix posture, take eye breaks, and more!',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Master toggle
              _buildToggleCard(
                title: 'Enable Health Reminders',
                subtitle: 'Turn on/off all health notifications',
                icon: Icons.notifications_active,
                value: _remindersEnabled,
                onChanged: (value) async {
                  setState(() => _remindersEnabled = value);
                  await HealthReminderService.setRemindersEnabled(value);
                },
                iconColor: Colors.green,
              ),

              const SizedBox(height: 16),

              // Interval selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.orange[600]),
                        const SizedBox(width: 12),
                        const Text(
                          'Reminder Interval',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Every $_intervalMinutes minutes',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    Slider(
                      value: _intervalMinutes.toDouble(),
                      min: 15,
                      max: 120,
                      divisions: 7,
                      label: '$_intervalMinutes min',
                      activeColor: AppColors.primary,
                      onChanged: _remindersEnabled
                          ? (value) {
                              setState(() => _intervalMinutes = value.toInt());
                            }
                          : null,
                      onChangeEnd: (value) async {
                        await HealthReminderService.setReminderInterval(
                          value.toInt(),
                        );
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '15 min',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '2 hours',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'REMINDER TYPES',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),

              // Water reminders
              _buildToggleCard(
                title: 'Water Reminders',
                subtitle: 'Stay hydrated throughout the day',
                icon: Icons.water_drop,
                value: _waterReminders,
                onChanged: _remindersEnabled
                    ? (value) async {
                        setState(() => _waterReminders = value);
                        await HealthReminderService.setWaterRemindersEnabled(
                          value,
                        );
                      }
                    : null,
                iconColor: Colors.blue,
              ),

              // Posture reminders
              _buildToggleCard(
                title: 'Posture Reminders',
                subtitle: 'Sit up straight, back health',
                icon: Icons.accessibility_new,
                value: _postureReminders,
                onChanged: _remindersEnabled
                    ? (value) async {
                        setState(() => _postureReminders = value);
                        await HealthReminderService.setPostureRemindersEnabled(
                          value,
                        );
                      }
                    : null,
                iconColor: Colors.purple,
              ),

              // Eye break reminders
              _buildToggleCard(
                title: 'Eye Break Reminders',
                subtitle: '20-20-20 rule for eye health',
                icon: Icons.remove_red_eye,
                value: _eyeBreakReminders,
                onChanged: _remindersEnabled
                    ? (value) async {
                        setState(() => _eyeBreakReminders = value);
                        await HealthReminderService.setEyeBreakRemindersEnabled(
                          value,
                        );
                      }
                    : null,
                iconColor: Colors.teal,
              ),

              // Stretch reminders
              _buildToggleCard(
                title: 'Stretch Reminders',
                subtitle: 'Move your body, prevent stiffness',
                icon: Icons.self_improvement,
                value: _stretchReminders,
                onChanged: _remindersEnabled
                    ? (value) async {
                        setState(() => _stretchReminders = value);
                        await HealthReminderService.setStretchRemindersEnabled(
                          value,
                        );
                      }
                    : null,
                iconColor: Colors.orange,
              ),

              // Wellness tips
              _buildToggleCard(
                title: 'Wellness Tips',
                subtitle: 'Breathing, mindfulness, mood boosters',
                icon: Icons.spa,
                value: _wellnessTips,
                onChanged: _remindersEnabled
                    ? (value) async {
                        setState(() => _wellnessTips = value);
                        await HealthReminderService.setWellnessTipsEnabled(
                          value,
                        );
                      }
                    : null,
                iconColor: Colors.pink,
              ),

              const SizedBox(height: 24),

              // Test button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _remindersEnabled
                      ? () async {
                          await HealthReminderService.sendWaterReminder();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Test notification sent!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.send),
                  label: const Text('Send Test Reminder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool)? onChanged,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
