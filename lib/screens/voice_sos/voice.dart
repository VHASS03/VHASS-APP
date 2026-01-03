import 'package:flutter/material.dart';

class VoiceSOSScreen extends StatelessWidget {
  const VoiceSOSScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access current theme data
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      // CHANGE 1: Use theme background
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            // CHANGE 2: Dynamic back button color
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice SOS',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: textColor, // CHANGE 3: Dynamic title
              ),
            ),
            Text(
              'Hands-free emergency trigger',
              style: TextStyle(
                fontSize: 12, 
                color: isDark ? Colors.blueGrey : Colors.blueGrey[600],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // --- LARGE MIC ICON ---
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary, // Using theme primary
                ),
                child: const Icon(Icons.mic, size: 64, color: Colors.white),
              ),
            ),
            
            const SizedBox(height: 32),
            Text(
              'Always Listening',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold, 
                color: textColor, // CHANGE 4: Dynamic text
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'VHASS is listening for your voice command, even when your phone is locked',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey[700], 
                fontSize: 15, 
                height: 1.4,
              ),
            ),

            const SizedBox(height: 32),

            // --- TRIGGER PHRASE CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                // CHANGE 5: Use theme card color
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.volume_up_outlined, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Say this to trigger SOS',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '"Help me out"',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: textColor, // CHANGE 6: Large text flips color
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- HOW IT WORKS SECTION ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'How it works',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            _buildStepRow(context, 1, 'Continuous listening', 'Low-power mode detects your voice phrase'),
            const SizedBox(height: 24),
            _buildStepRow(context, 2, 'Instant activation', 'Emergency mode triggers immediately'),
            const SizedBox(height: 24),
            _buildStepRow(context, 3, 'Help dispatched', 'Contacts notified, location shared'),

            const SizedBox(height: 32),

            // --- INFO BANNER ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // CHANGE 7: Use primary tint instead of hardcoded purple-black
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This feature works even when your phone is locked or you cannot reach the screen.',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFB0A0C0) : Colors.black87, 
                        fontSize: 13, 
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(BuildContext context, int step, String title, String subtitle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color, 
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey[700], 
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}