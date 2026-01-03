import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/widgets/sos_button.dart';
import '../emergency/emergency.dart';
import '../contacts/contacts.dart';
import '../voice_sos/voice.dart';
import '../welness/welness.dart'; 
import '../chat/chat.dart';
import '../Settings/settings.dart'; 

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                      color: theme.colorScheme.primary, // Using primary from theme
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
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
                      Text(
                        "You're protected",
                        style: TextStyle(
                          // 3. Dynamic Secondary Text
                          color: isDark ? Colors.blueGrey[200] : Colors.blueGrey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
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
                    icon: Icon(Icons.settings_outlined, 
                        color: isDark ? Colors.grey : Colors.black54),
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
                      fontSize: 16
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
                  _buildFeatureCard(context, Icons.group_outlined, 'Contacts', const ContactsScreen()),
                  _buildFeatureCard(context, Icons.mic_none_rounded, 'Voice', const VoiceSOSScreen()),
                  _buildFeatureCard(context, Icons.favorite_border_rounded, 'Wellness', const WellnessScreen()),
                  _buildFeatureCard(context, Icons.chat_bubble_outline_rounded, 'Chat', const ChatScreen()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, IconData icon, String label, Widget destination) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
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