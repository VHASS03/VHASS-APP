import 'package:flutter/material.dart';
import '../../core/colors.dart';

class SecurityAnalyticsScreen extends StatelessWidget {
  const SecurityAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Campus Security Analytics"),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Safety Insights", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text(
                      "Data analysis from active SOS alerts, incident reports, and guard dispatch patrols to identify vulnerability trends.",
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Analytics Card 1: Peak Risk Hours ---
              const Text("PEAK RISK HOUR ANALYSIS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 12),
              _buildAnalyticsContainer(
                context,
                title: "SOS Incidents by Hour",
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Risk Level: HIGH", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text("Peak: 10 PM - 02 AM", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar("08am", 0.1, Colors.green),
                        _buildBar("12pm", 0.25, Colors.green),
                        _buildBar("04pm", 0.35, Colors.orange),
                        _buildBar("08pm", 0.65, Colors.red),
                        _buildBar("12am", 0.95, Colors.red),
                        _buildBar("04am", 0.45, Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Analytics Card 2: Incident Heat Map ---
              const Text("CAMPUS INCIDENT HEAT MAP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 12),
              _buildAnalyticsContainer(
                context,
                title: "Safety Risk Locations",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeatMapRow("Library Block Parking (West)", 85, Colors.red),
                    _buildHeatMapRow("Hostel B Dorm Area", 55, Colors.orange),
                    _buildHeatMapRow("Academic Block C Ground Floor", 30, Colors.yellow[700]!),
                    _buildHeatMapRow("Main Athletic Tracks", 15, Colors.green),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Analytics Card 3: Response Time Trends ---
              const Text("AVERAGE SOS RESPONSE TIME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 12),
              _buildAnalyticsContainer(
                context,
                title: "Patrol Dispatch Performance",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Average Response: 3.2 minutes",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                    ),
                    const SizedBox(height: 4),
                    const Text("Down from 4.8m last month. Active QR checkpoints implemented.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildTimeBar("Week 1", 4.8),
                        _buildTimeBar("Week 2", 4.1),
                        _buildTimeBar("Week 3", 3.5),
                        _buildTimeBar("Week 4", 3.2),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsContainer(BuildContext context, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildBar(String label, double val, Color color) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 100 * val,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTimeBar(String label, double mins) {
    // scale max 5.0
    final val = mins / 5.0;

    return Column(
      children: [
        Text("${mins}m", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 80 * val,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHeatMapRow(String location, int val, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(location, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text("$val% risk", style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: val / 100,
              backgroundColor: Colors.grey.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
