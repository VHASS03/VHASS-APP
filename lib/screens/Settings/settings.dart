import 'package:flutter/material.dart';
import '../../theme_controller.dart'; 
import 'safety_device.dart';

// --- ADDED THIS CLASS: The missing parent widget ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
              title: "Your Profile",
              subtitle: "+91 98765 43210",
              icon: Icons.person_outline,
              onTap: () {
                // Navigate to Profile Screen if you have one
              },
            ),

            _buildSectionHeader("SAFETY"),
            _buildSettingCard(
              title: "Safety Device",
              subtitle: "Coming soon",
              icon: Icons.bluetooth_searching,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SafetyDeviceScreen()),
                );
              },
            ),

            _buildSectionHeader("PREFERENCES"),
            _buildSettingCard(
              title: "Dark Mode",
              icon: isDark ? Icons.dark_mode : Icons.light_mode,
              trailing: Switch(
                value: isDark,
                activeColor: const Color(0xFF9146FF),
                onChanged: (bool value) {
                  // Ensure themeNotifier is defined in your theme_controller.dart
                  themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingCard(
              title: "Notifications",
              icon: Icons.notifications_none,
            ),

            _buildSectionHeader("SUPPORT"),
            _buildSettingCard(
              title: "Help & FAQs",
              icon: Icons.help_outline,
            ),

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
            Icon(icon, color: const Color(0xFF9146FF)),
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
            trailing ?? const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
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
          letterSpacing: 1.2
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: () {
        // Implement Logout logic
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
            Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Column(
        children: [
          Text("VHASS v1.0.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
          Text("Made with care for your safety", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}