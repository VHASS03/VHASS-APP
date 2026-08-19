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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _UserProfileDialog(),
    ).then((_) => _loadUserData());
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

class _UserProfileDialog extends StatefulWidget {
  const _UserProfileDialog();

  @override
  State<_UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<_UserProfileDialog> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _admissionNumberController;
  late TextEditingController _emailController;
  late TextEditingController _ageController;
  late TextEditingController _roomNumberController;
  late TextEditingController _guardianNameController;
  late TextEditingController _guardianPhoneController;

  String _selectedCourse = 'B.Tech';
  String _selectedYear = '1st Year';
  String _selectedGender = 'Female';
  String _residenceType = 'Hosteller';
  String _selectedRelationship = 'Parent';

  final List<String> _courseOptions = [
    'B.Tech',
    'M.Tech',
    'B.Sc',
    'M.Sc',
    'BCA',
    'MCA',
    'BBA',
    'MBA',
    'B.Com',
    'MBBS',
    'PhD',
    'Other',
  ];

  final List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Post Graduate',
  ];

  final List<String> _genderOptions = ['Female', 'Male', 'Other'];
  final List<String> _relationshipOptions = [
    'Parent',
    'Sibling',
    'Guardian',
    'Relative',
    'Friend',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _admissionNumberController = TextEditingController();
    _emailController = TextEditingController();
    _ageController = TextEditingController();
    _roomNumberController = TextEditingController();
    _guardianNameController = TextEditingController();
    _guardianPhoneController = TextEditingController();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await AuthService.getProfile();
      if (response.success && response.data != null && response.data!['user'] != null) {
        final u = response.data!['user'] as Map<String, dynamic>;
        setState(() {
          _nameController.text = u['name']?.toString() ?? '';
          _phoneController.text = u['phone']?.toString() ?? '';
          _admissionNumberController.text = u['admissionNumber']?.toString() ?? '';
          _emailController.text = u['email']?.toString() ?? '';
          _ageController.text = u['age']?.toString() ?? '';
          _roomNumberController.text = u['roomNumber']?.toString() ?? '';
          _guardianNameController.text = u['guardianName']?.toString() ?? '';
          _guardianPhoneController.text = u['guardianPhone']?.toString() ?? '';

          if (u['course'] != null && _courseOptions.contains(u['course'])) {
            _selectedCourse = u['course'];
          }
          if (u['year'] != null && _yearOptions.contains(u['year'])) {
            _selectedYear = u['year'];
          }
          if (u['gender'] != null && _genderOptions.contains(u['gender'])) {
            _selectedGender = u['gender'];
          }
          if (u['residenceType'] != null) {
            _residenceType = u['residenceType'];
          }
          if (u['emergencyRelationship'] != null &&
              _relationshipOptions.contains(u['emergencyRelationship'])) {
            _selectedRelationship = u['emergencyRelationship'];
          }
          _isLoading = false;
        });
      } else {
        // Fallback to local storage
        final localName = await StorageService.getUserName();
        final localPhone = await StorageService.getPhone();
        setState(() {
          _nameController.text = localName ?? '';
          _phoneController.text = localPhone ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _admissionNumberController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _roomNumberController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name cannot be empty'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await AuthService.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        age: _ageController.text.trim(),
        admissionNumber: _admissionNumberController.text.trim(),
        course: _selectedCourse,
        year: _selectedYear,
        gender: _selectedGender,
        residenceType: _residenceType,
        roomNumber: _residenceType == 'Hosteller' ? _roomNumberController.text.trim() : null,
        guardianName: _guardianNameController.text.trim(),
        guardianPhone: _guardianPhoneController.text.trim(),
        emergencyRelationship: _selectedRelationship,
      );

      if (response.success) {
        await StorageService.setUserName(_nameController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
          );
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? 'Failed to update profile'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(color: theme.cardColor),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.lavender],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      child: Text(
                        _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _nameController.text.isNotEmpty ? _nameController.text : 'User Profile',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _phoneController.text.isNotEmpty ? _phoneController.text : 'No phone',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing) ...[
                              // --- EDIT MODE ---
                              _buildSectionTitle("PERSONAL & ACADEMIC"),
                              const SizedBox(height: 10),
                              _buildTextField(_nameController, "Full Name", Icons.person_outline),
                              const SizedBox(height: 10),

                              // Locked phone number in edit mode
                              TextField(
                                controller: _phoneController,
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: "Phone Number (Cannot be edited)",
                                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                                  filled: true,
                                  fillColor: isDark ? Colors.white10 : Colors.grey[200],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildTextField(_admissionNumberController, "Admission / Roll Number", Icons.badge_outlined),
                              const SizedBox(height: 10),
                              _buildTextField(_emailController, "Email Address", Icons.email_outlined),
                              const SizedBox(height: 10),
                              _buildTextField(_ageController, "Age", Icons.cake_outlined, keyboard: TextInputType.number),
                              const SizedBox(height: 10),
                              _buildDropdownField("Course", _selectedCourse, _courseOptions, Icons.school_outlined, (v) => setState(() => _selectedCourse = v!)),
                              const SizedBox(height: 10),
                              _buildDropdownField("Year of Study", _selectedYear, _yearOptions, Icons.calendar_today_outlined, (v) => setState(() => _selectedYear = v!)),
                              const SizedBox(height: 10),
                              _buildDropdownField("Gender", _selectedGender, _genderOptions, Icons.wc_outlined, (v) => setState(() => _selectedGender = v!)),

                              const SizedBox(height: 18),
                              _buildSectionTitle("RESIDENCE"),
                              const SizedBox(height: 10),
                              _buildDropdownField("Residence Type", _residenceType, ['Hosteller', 'Day Scholar'], Icons.home_work_outlined, (v) => setState(() => _residenceType = v!)),
                              if (_residenceType == 'Hosteller') ...[
                                const SizedBox(height: 10),
                                _buildTextField(_roomNumberController, "Room Number / Block", Icons.meeting_room_outlined),
                              ],

                              const SizedBox(height: 18),
                              _buildSectionTitle("GUARDIAN DETAILS"),
                              const SizedBox(height: 10),
                              _buildTextField(_guardianNameController, "Guardian Name", Icons.family_restroom_outlined),
                              const SizedBox(height: 10),
                              _buildTextField(_guardianPhoneController, "Guardian Phone", Icons.contact_phone_outlined, keyboard: TextInputType.phone),
                              const SizedBox(height: 10),
                              _buildDropdownField("Emergency Relationship", _selectedRelationship, _relationshipOptions, Icons.people_outline, (v) => setState(() => _selectedRelationship = v!)),
                            ] else ...[
                              // --- VIEW MODE ---
                              _buildSectionTitle("STUDENT & ACADEMIC"),
                              const SizedBox(height: 10),
                              _buildDetailRow(Icons.person_outline, "Full Name", _nameController.text),
                              _buildDetailRow(Icons.lock_outline, "Phone Number", _phoneController.text, subtitle: "Phone number is fixed"),
                              _buildDetailRow(Icons.badge_outlined, "Admission Number", _admissionNumberController.text),
                              _buildDetailRow(Icons.email_outlined, "Email Address", _emailController.text),
                              _buildDetailRow(Icons.cake_outlined, "Age & Gender", "${_ageController.text.isNotEmpty ? _ageController.text : 'N/A'} • $_selectedGender"),
                              _buildDetailRow(Icons.school_outlined, "Course & Year", "$_selectedCourse ($_selectedYear)"),

                              const SizedBox(height: 16),
                              _buildSectionTitle("RESIDENCE"),
                              const SizedBox(height: 10),
                              _buildDetailRow(Icons.home_work_outlined, "Residence Type", _residenceType),
                              if (_residenceType == 'Hosteller')
                                _buildDetailRow(Icons.meeting_room_outlined, "Room / Block", _roomNumberController.text),

                              const SizedBox(height: 16),
                              _buildSectionTitle("GUARDIAN & EMERGENCY"),
                              const SizedBox(height: 10),
                              _buildDetailRow(Icons.family_restroom_outlined, "Guardian Name", _guardianNameController.text),
                              _buildDetailRow(Icons.contact_phone_outlined, "Guardian Phone", _guardianPhoneController.text),
                              _buildDetailRow(Icons.people_outline, "Emergency Relationship", _selectedRelationship),
                            ],
                          ],
                        ),
                      ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_isEditing) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text("Edit Profile"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {String? subtitle}) {
    final displayValue = value.trim().isNotEmpty ? value : 'Not specified';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(displayValue, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.orange)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, IconData icon, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: options.contains(value) ? value : options.first,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
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
