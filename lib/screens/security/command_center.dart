import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/services/campus_security_service.dart';

class SecurityCommandCenterScreen extends StatefulWidget {
  const SecurityCommandCenterScreen({super.key});

  @override
  State<SecurityCommandCenterScreen> createState() => _SecurityCommandCenterScreenState();
}

class _SecurityCommandCenterScreenState extends State<SecurityCommandCenterScreen> {
  final _securityService = CampusSecurityService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeSosList = _securityService.sosEvents.where((e) => e.status != "Resolved").toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Security Command Center"),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Live Status Panel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: isDark ? Colors.red.withOpacity(0.08) : Colors.red.withOpacity(0.05),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: Colors.green, size: 12),
                  const SizedBox(width: 8),
                  const Text("SYSTEM STATUS: ONLINE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                  const Spacer(),
                  Text("ACTIVE SOS ALERTS: ${activeSosList.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION 1: EMERGENCY CONTROL PANEL ---
                    const Text("EMERGENCY CONTROL PANEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildEmergencyButton(
                          title: "Panic Button",
                          icon: Icons.emergency,
                          color: Colors.red,
                          onPressed: () => _triggerPanicBroadcast("Panic Button Activation"),
                        ),
                        const SizedBox(width: 12),
                        _buildEmergencyButton(
                          title: "Broad Cast",
                          icon: Icons.campaign,
                          color: Colors.orange,
                          onPressed: () => _triggerPanicBroadcast("Campus-wide Alert Broadcast"),
                        ),
                        const SizedBox(width: 12),
                        _buildEmergencyButton(
                          title: "Dispatch ERT",
                          icon: Icons.speed,
                          color: Colors.blue,
                          onPressed: () => _triggerPanicBroadcast("Emergency Response Team Dispatch"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- SECTION 2: ACTIVE SOS ESCALATIONS ---
                    const Text("ACTIVE STUDENT SOS ROUTING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    if (activeSosList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.shield_outlined, size: 48, color: Colors.green),
                            SizedBox(height: 12),
                            Text("No active SOS emergencies", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("Campus is currently secure.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      ...activeSosList.map((sos) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text("Alert ID: ${sos.id.substring(sos.id.length - 6)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text(
                                    DateFormat('hh:mm a').format(sos.time),
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Text("Student Name: ${sos.studentName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text("Location: ${sos.locationName}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 12),
                              
                              // Visual Escalation Flow Chart
                              const Text("Escalation Route:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 10),
                              _buildEscalationTimeline(sos),
                              const SizedBox(height: 16),

                              // Actions
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        _showEscalationActionSheet(sos);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(color: AppColors.primary),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text("Escalate Route"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _securityService.resolveSOSEvent(sos.id);
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("SOS alert resolved successfully"), backgroundColor: Colors.green),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text("Resolve"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    
                    const SizedBox(height: 24),
                    // --- SECTION 3: LIVE CAMPUS MONITORING LIST ---
                    const Text("LIVE GUARD LOCATION & SHIFTS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    ..._securityService.guards.map((guard) {
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(backgroundImage: NetworkImage(guard.avatarUrl)),
                          title: Text(guard.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Duty Assignment: ${guard.location}"),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "ON DUTY",
                              style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton({required String title, required IconData icon, required Color color, required VoidCallback onPressed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEscalationTimeline(SecuritySOSEvent sos) {
    // 3 levels: Guard (1), Supervisor (2), Head (3)
    int currentStep = 1;
    if (sos.escalationLevel == "Supervisor") currentStep = 2;
    if (sos.escalationLevel == "Security Head") currentStep = 3;

    return Row(
      children: [
        _buildTimelineNode("Guard", currentStep >= 1, currentStep == 1),
        _buildTimelineLine(currentStep >= 2),
        _buildTimelineNode("Supervisor", currentStep >= 2, currentStep == 2),
        _buildTimelineLine(currentStep >= 3),
        _buildTimelineNode("Security Head", currentStep >= 3, currentStep == 3),
      ],
    );
  }

  Widget _buildTimelineNode(String title, bool active, bool isCurrent) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active ? (isCurrent ? Colors.orange : Colors.red) : Colors.grey[300],
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Center(
            child: Icon(
              isCurrent ? Icons.play_arrow : (active ? Icons.check : Icons.circle),
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildTimelineLine(bool active) {
    return Expanded(
      child: Container(
        height: 3,
        color: active ? Colors.red : Colors.grey[300],
      ),
    );
  }

  void _triggerPanicBroadcast(String actionName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 10),
              Text(actionName),
            ],
          ),
          content: Text("Are you sure you want to trigger the '$actionName'? This will log an audit event and broadcast immediately."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _securityService.logAudit("Panic Broadcast", "Admin Center", "Triggered: $actionName");
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Emergency Action Triggered Successfully"), backgroundColor: Colors.red),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Trigger Alert"),
            ),
          ],
        );
      },
    );
  }

  void _showEscalationActionSheet(SecuritySOSEvent sos) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text("Escalate SOS Response Channel", style: TextStyle(fontWeight: FontWeight.bold))),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.orange),
                title: const Text("Escalate to Duty Supervisor"),
                onTap: () {
                  setState(() {
                    _securityService.escalateSOSEvent(sos.id, "Supervisor", "Escalated to Supervisor James Carter");
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                title: const Text("Escalate to Security Head HQ"),
                onTap: () {
                  setState(() {
                    _securityService.escalateSOSEvent(sos.id, "Security Head", "Escalated to Security Head HQ Office");
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
