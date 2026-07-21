import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/services/university_wellness_service.dart';

class WellnessAdminScreen extends StatefulWidget {
  const WellnessAdminScreen({super.key});

  @override
  State<WellnessAdminScreen> createState() => _WellnessAdminScreenState();
}

class _WellnessAdminScreenState extends State<WellnessAdminScreen> {
  final _wellnessService = UniversityWellnessService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalRegistered = 142; // Mock total registered students
    final activeAppointments = _wellnessService.appointments.where((a) => a.status == "Approved" || a.status == "Rescheduled").length;
    final pendingRequests = _wellnessService.appointments.where((a) => a.status == "Pending").length;
    final completedSessions = _wellnessService.appointments.where((a) => a.status == "Completed").length;
    final crisisCount = _wellnessService.appointments.where((a) => a.isHighPriority && a.status != "Completed").length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Wellness Admin Portal"),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _exportReport(),
              tooltip: "Export PDF Report",
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Overview"),
              Tab(text: "Appointments"),
              Tab(text: "Counsellors"),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(totalRegistered, activeAppointments, pendingRequests, completedSessions, crisisCount),
            _buildAppointmentsTab(),
            _buildCounsellorsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(int total, int active, int pending, int completed, int crisis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 Cards
          Row(
            children: [
              _buildStatCard("Total Registered", "$total", Icons.people_outline, Colors.blue),
              const SizedBox(width: 14),
              _buildStatCard("Active sessions", "$active", Icons.calendar_today, Colors.green),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatCard("Pending Requests", "$pending", Icons.hourglass_empty, Colors.orange),
              const SizedBox(width: 14),
              _buildStatCard("Completed", "$completed", Icons.done_all, Colors.purple),
            ],
          ),
          const SizedBox(height: 16),

          // High Priority / Crisis Section
          if (crisis > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "HIGH PRIORITY CRISIS QUEUE",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "There are $crisis active crisis cases that require immediate counsellor assignment or intervention.",
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondary : Colors.red[900]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Text(
            "MONTHLY WELLNESS TRENDS",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          // Analytics Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Monthly Support Bookings", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("June 2026", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 20),
                // Custom chart representation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBar("Jan", 0.4),
                    _buildBar("Feb", 0.5),
                    _buildBar("Mar", 0.3),
                    _buildBar("Apr", 0.7),
                    _buildBar("May", 0.9),
                    _buildBar("Jun", 0.8),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double val) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 120 * val,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.85),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isDark ? AppColors.textSecondary : Colors.grey[600], fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    final list = _wellnessService.appointments;

    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final ap = list[index];
        final isPending = ap.status == "Pending";

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ap.isHighPriority ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Student: ${ap.studentName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ap.isHighPriority ? Colors.red.withOpacity(0.15) : Colors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ap.isHighPriority ? "Crisis Queue" : "Regular",
                      style: TextStyle(color: ap.isHighPriority ? Colors.red : Colors.blue, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text("Concern: ${ap.concern}", style: const TextStyle(fontSize: 13)),
              Text("Preferred Counsellor: ${ap.counsellor.name}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
              Text("Time: ${DateFormat('MMM dd, yyyy').format(ap.date)} at ${ap.timeSlot}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text("Status: ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(ap.status, style: TextStyle(fontSize: 12, color: _getStatusColor(ap.status), fontWeight: FontWeight.bold)),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            ap.status = "Rejected";
                          });
                          _wellnessService.updateAppointmentStatus(ap.id, "Rejected");
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Reject"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            ap.status = "Approved";
                          });
                          _wellnessService.updateAppointmentStatus(ap.id, "Approved");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Approve"),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Approved":
        return Colors.green;
      case "Pending":
        return Colors.orange;
      case "Rejected":
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Widget _buildCounsellorsTab() {
    final list = _wellnessService.counsellors;

    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: list.length + 1,
      itemBuilder: (context, index) {
        if (index == list.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddCounsellorDialog(),
              icon: const Icon(Icons.add),
              label: const Text("Add New Counsellor"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
        }

        final c = list[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: CircleAvatar(
              backgroundImage: NetworkImage(c.imageUrl),
              radius: 28,
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.specialization, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text("Slots: ${c.availability.join(', ')}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            trailing: Text("⭐ ${c.rating}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  void _showAddCounsellorDialog() {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Counsellor"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Counsellor Name"),
                ),
                TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(labelText: "Specialization"),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && specCtrl.text.isNotEmpty) {
                  setState(() {
                    _wellnessService.addCounsellor(Counsellor(
                      id: "c_${DateTime.now().millisecondsSinceEpoch}",
                      name: nameCtrl.text,
                      specialization: specCtrl.text,
                      imageUrl: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150",
                      rating: 4.8,
                      availability: ["09:00 AM", "11:00 AM", "03:00 PM"],
                      email: emailCtrl.text,
                    ));
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Counsellor added successfully")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _exportReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red),
            SizedBox(width: 10),
            Text("Export Wellness Report"),
          ],
        ),
        content: const Text(
          "Generate comprehensive PDF report for June 2026?\n\nThis includes:\n- Appointment statistics\n- Crisis intervention tracking\n- Monthly trends analytics\n- Anonymous reports overview",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Report PDF exported and saved to /Downloads successfully!"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Export PDF"),
          ),
        ],
      ),
    );
  }
}
