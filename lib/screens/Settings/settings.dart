import 'package:flutter/material.dart';
import '../../theme_controller.dart'; // Ensure this path is correct

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    // Detect theme state
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      // Background color automatically switches based on appTheme
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Settings"),
        // The AppBarTheme in main.dart will handle the text/icon color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("PREFERENCES"),
            
            // --- DARK MODE CARD ---
            _buildSettingCard(
              title: "Dark Mode",
              icon: isDark ? Icons.dark_mode : Icons.light_mode,
              trailing: Switch(
                value: isDark,
                activeColor: const Color(0xFF9146FF),
                onChanged: (bool value) {
                  // Trigger global theme change
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
          ],
        ),
      ),
    );
  }

  // Helper for Section Headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- FIXED BUILDER METHOD ---
  Widget _buildSettingCard({
    required String title,
    required IconData icon,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Uses the cardColor defined in your appTheme (Dark = greyish, Light = white)
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          if (Theme.of(context).brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF9146FF)),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              // IMPORTANT: This pulls from your textTheme in main.dart
              // It will automatically be black in light mode and white in dark mode.
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}