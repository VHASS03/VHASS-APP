import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/services/campus_security_service.dart';

class IncidentManagerScreen extends StatefulWidget {
  const IncidentManagerScreen({super.key});

  @override
  State<IncidentManagerScreen> createState() => _IncidentManagerScreenState();
}

class _IncidentManagerScreenState extends State<IncidentManagerScreen> {
  final _securityService = CampusSecurityService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Incident Management Portal"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Incident Log"),
              Tab(text: "Report Threat"),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            _buildIncidentsListTab(),
            _buildReportIncidentTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentsListTab() {
    final list = _securityService.incidents;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final inc = list[index];
        final isClosed = inc.status == "Closed" || inc.status == "Resolved";

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(inc.category).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      inc.category,
                      style: TextStyle(color: _getCategoryColor(inc.category), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(inc.timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                inc.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                inc.description,
                style: TextStyle(color: isDark ? AppColors.textSecondary : Colors.grey[700], fontSize: 13, height: 1.3),
              ),
              if (inc.evidenceFileName != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(inc.evidenceFileName!, style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.underline)),
                  ],
                ),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  const Text("Status: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(
                    inc.status,
                    style: TextStyle(fontSize: 12, color: _getStatusColor(inc.status), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (inc.assignedInvestigator != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("Investigator: ${inc.assignedInvestigator}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              if (inc.resolutionDetails != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("Resolution: ${inc.resolutionDetails}", style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
                ),
              
              if (!isClosed) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _assignInvestigator(inc),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Assign Case"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _resolveIncident(inc),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Resolve Case"),
                      ),
                    ),
                  ],
                )
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportIncidentTab() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    String? selectedCategory = "Theft";
    String? mockFileName;

    return StatefulBuilder(
      builder: (context, setStateTab) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Report Security Incident", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              const Text("Submit threat reports directly to campus response teams.", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: ["Theft", "Harassment", "Vandalism", "Medical Emergency", "Suspicious Activity"].map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) => setStateTab(() => selectedCategory = val),
                decoration: const InputDecoration(labelText: "Incident Category"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Brief Title", hintText: "e.g. Theft of Wallet"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: "Detailed Description", hintText: "Provide details, times, locations..."),
              ),
              const SizedBox(height: 16),

              // Mock Evidence Upload Card
              GestureDetector(
                onTap: () {
                  setStateTab(() {
                    mockFileName = "evidence_photo_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.jpg";
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(mockFileName != null ? Icons.check_circle : Icons.upload_file, color: mockFileName != null ? Colors.green : AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        mockFileName ?? "Upload Evidence (Mock Photo/PDF)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: mockFileName != null ? Colors.green : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text("Your Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Reporter Name"),
              ),
              TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Contact Phone"),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fill in all mandatory fields")),
                      );
                      return;
                    }

                    await _securityService.reportIncident(
                      title: titleCtrl.text,
                      description: descCtrl.text,
                      category: selectedCategory!,
                      reportedBy: nameCtrl.text,
                      contactInfo: contactCtrl.text,
                      evidenceFileName: mockFileName,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Incident logged successfully"), backgroundColor: Colors.green),
                    );

                    setState(() {
                      // refresh outer state
                    });

                    // Reset form
                    titleCtrl.clear();
                    descCtrl.clear();
                    nameCtrl.clear();
                    contactCtrl.clear();
                    setStateTab(() {
                      mockFileName = null;
                    });

                    DefaultTabController.of(context).animateTo(0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Log Report"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case "Theft":
        return Colors.blue;
      case "Harassment":
        return Colors.red;
      case "Vandalism":
        return Colors.purple;
      case "Medical Emergency":
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Submitted":
        return Colors.orange;
      case "In Investigation":
        return Colors.blue;
      case "Resolved":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _assignInvestigator(IncidentReport inc) {
    String? selectedInvestigator = "Officer John McClane";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setD) {
            return AlertDialog(
              title: const Text("Assign Case Investigator"),
              content: DropdownButtonFormField<String>(
                value: selectedInvestigator,
                items: _securityService.guards.map((g) {
                  return DropdownMenuItem(value: g.name, child: Text(g.name));
                }).toList(),
                onChanged: (val) => setD(() => selectedInvestigator = val),
                decoration: const InputDecoration(labelText: "Select Officer"),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _securityService.updateIncidentStatus(inc.id, "In Investigation", investigator: selectedInvestigator);
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Case assigned successfully")),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text("Assign"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _resolveIncident(IncidentReport inc) {
    final resolutionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Resolve Security Case"),
          content: TextField(
            controller: resolutionCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Resolution details", hintText: "Provide outcome notes..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (resolutionCtrl.text.isNotEmpty) {
                  setState(() {
                    _securityService.updateIncidentStatus(inc.id, "Resolved", resolutionDetails: resolutionCtrl.text);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Case marked as resolved"), backgroundColor: Colors.green),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text("Resolve"),
            ),
          ],
        );
      },
    );
  }
}
