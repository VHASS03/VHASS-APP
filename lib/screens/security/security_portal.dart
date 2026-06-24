import 'package:flutter/material.dart';
import '../../core/colors.dart';
import 'command_center.dart';
import 'duty_roster.dart';
import 'incident_manager.dart';
import 'qr_verification.dart';
import 'security_analytics.dart';
import 'lost_found.dart';
import 'vehicle_management.dart';

class SecurityPortalScreen extends StatelessWidget {
  const SecurityPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Security Operations Portal"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Command Center Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.redAccent, Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.online_prediction, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          "Active Incident Command",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Real-time SOS escalation, guard locations, panic broadcasts, and incident mapping services.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SecurityCommandCenterScreen()),
                      ),
                      icon: const Icon(Icons.videocam, size: 18),
                      label: const Text("Open Command Center"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                "SECURITY OPERATIONS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textSecondary : Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),

              // Hub Options
              _buildOpCard(
                context: context,
                title: "Duty & Shift Roster",
                subtitle: "View active assignments, shift status, and duty locations of campus guards.",
                icon: Icons.assignment_ind,
                color: Colors.indigo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DutyRosterScreen()),
                ),
              ),

              _buildOpCard(
                context: context,
                title: "Incident Management Logs",
                subtitle: "Report safety threats, upload photo evidence, assign investigators, and trace resolution status.",
                icon: Icons.report_problem,
                color: Colors.amber[700]!,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IncidentManagerScreen()),
                ),
              ),

              _buildOpCard(
                context: context,
                title: "QR Verification System",
                subtitle: "Generate campus ID passes or scan codes to verify incoming visitors and staff members.",
                icon: Icons.qr_code_scanner,
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QrVerificationScreen()),
                ),
              ),

              _buildOpCard(
                context: context,
                title: "Campus Security Analytics",
                subtitle: "Explore peak-hour risk analytics, SOS response charts, and incident heat maps.",
                icon: Icons.analytics_outlined,
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SecurityAnalyticsScreen()),
                ),
              ),

              const Divider(height: 32),

              Text(
                "CAMPUS LOGISTICS & SUPPORT",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textSecondary : Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),

              _buildOpCard(
                context: context,
                title: "Lost & Found Registry",
                subtitle: "Log lost belongings, post discovered items, verify claimant ownership, and settle claims.",
                icon: Icons.find_in_page,
                color: Colors.deepPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LostFoundScreen()),
                ),
              ),

              _buildOpCard(
                context: context,
                title: "Security Vehicle Management",
                subtitle: "Track emergency response vehicle fleets, monitor fuel logs, maintenance status, and dispatch logs.",
                icon: Icons.local_taxi,
                color: Colors.blueAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VehicleManagementScreen()),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondary : Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Align(
                  alignment: Alignment.center,
                  child: Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
