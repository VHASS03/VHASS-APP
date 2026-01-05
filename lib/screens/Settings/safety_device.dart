import 'package:flutter/material.dart';

class SafetyDeviceScreen extends StatelessWidget {
  const SafetyDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: theme.cardColor,
              shape: const CircleBorder(),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Safety Device",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text(
              "Bluetooth integration",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 60),
            
            // Central Bluetooth Icon with Glow
            Center(
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF9146FF).withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.bluetooth,
                      size: 60,
                      color: Color(0xFF9146FF),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(0xFF16161E),
                    child: Icon(Icons.bolt, color: Colors.amber, size: 14),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            Text(
              "Coming Soon",
              style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Wearable safety device that lets you trigger SOS with a simple button press",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
            
            const SizedBox(height: 40),
            
            // Feature List
            _buildFeatureItem(context, "Compact wearable design"),
            const SizedBox(height: 12),
            _buildFeatureItem(context, "Long battery life (30+ days)"),
            const SizedBox(height: 12),
            _buildFeatureItem(context, "Instant emergency trigger"),
            
            const SizedBox(height: 40),
            
            // Info Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF9146FF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF9146FF), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "We're working on Bluetooth-enabled safety devices. Stay tuned for updates!",
                      style: TextStyle(color: Color(0xFFB0A0C0), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Color(0xFF9146FF), size: 12),
          const SizedBox(width: 16),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}