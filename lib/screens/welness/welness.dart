import 'package:flutter/material.dart';

class WellnessScreen extends StatelessWidget {
  const WellnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access current theme data
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      // 1. Dynamic Background
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            // 2. Dynamic icon color
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
              'Women Wellness',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: textColor, // 3. Dynamic title
              ),
            ),
            Text(
              'Private health tracking',
              style: TextStyle(
                fontSize: 12, 
                color: isDark ? Colors.blueGrey : Colors.blueGrey[600],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            
            // --- MAIN PERIOD TRACKER CARD ---
            // We keep the primary color background as it's the brand highlight
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Next Period',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '8 days',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Expected: Jan 5, 2025',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                  const Icon(Icons.calendar_month_outlined, color: Colors.white30, size: 64),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- CYCLE & PERIOD LENGTH ROW ---
            Row(
              children: [
                _buildSummaryCard(context, 'Cycle Length', '28 days'),
                const SizedBox(width: 16),
                _buildSummaryCard(context, 'Period Length', '5 days'),
              ],
            ),

            const SizedBox(height: 24),

            // --- ACTION LIST ---
            _buildActionTile(context, Icons.calendar_today_outlined, 'Track Cycle', 'Log your period dates'),
            const SizedBox(height: 12),
            _buildActionTile(context, Icons.favorite_outline, 'Symptoms', 'Track mood & symptoms'),
            const SizedBox(height: 12),
            _buildActionTile(context, Icons.edit_note_outlined, 'Health Notes', 'Private notes & reminders'),

            const SizedBox(height: 40),

            // --- PRIVACY FOOTER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 14),
                const SizedBox(width: 8),
                Text(
                  'All data is private and stored securely on your device',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey[700], 
                    fontSize: 12
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Small Summary Cards (Cycle/Period Length)
  Widget _buildSummaryCard(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // 4. Dynamic Card Color
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                // 5. Dynamic text color
                color: theme.textTheme.bodyLarge?.color, 
                fontSize: 18, 
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Feature Action List Items
  Widget _buildActionTile(BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // 6. Dynamic Tile Color
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    // 7. Dynamic text color
                    color: theme.textTheme.bodyLarge?.color, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey[700], 
                    fontSize: 13
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}