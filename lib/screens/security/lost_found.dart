import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/services/campus_security_service.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  final _securityService = CampusSecurityService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Lost & Found Registry"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Belongings Catalog"),
              Tab(text: "Report Item"),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            _buildCatalogTab(),
            _buildReportItemTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogTab() {
    final list = _securityService.lostFoundItems;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final isOpen = item.status == "Open";

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.type == "Found" ? Colors.green.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.type.toUpperCase(),
                      style: TextStyle(color: item.type == "Found" ? Colors.green : Colors.blue, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(item.date),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                item.description,
                style: TextStyle(color: isDark ? AppColors.textSecondary : Colors.grey[700], fontSize: 13),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Text("Contact: ${item.contactName}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Spacer(),
                  Text("Status: ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(item.status, style: TextStyle(color: isOpen ? Colors.orange : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              if (isOpen) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Mark claimed
                        final idx = _securityService.lostFoundItems.indexWhere((i) => i.id == item.id);
                        if (idx != -1) {
                          _securityService.lostFoundItems[idx] = LostFoundItem(
                            id: item.id,
                            title: item.title,
                            description: item.description,
                            type: item.type,
                            status: "Claimed",
                            date: item.date,
                            contactName: item.contactName,
                          );
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Claim logged. Pending verification check."), backgroundColor: Colors.green),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(item.type == "Found" ? "Claim Item" : "Report as Found"),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportItemTab() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String itemType = "Lost";

    return StatefulBuilder(
      builder: (context, setStateTab) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Report Lost or Found Item", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("I Lost Something")),
                      selected: itemType == "Lost",
                      onSelected: (selected) {
                        if (selected) setStateTab(() => itemType = "Lost");
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("I Found Something")),
                      selected: itemType == "Found",
                      onSelected: (selected) {
                        if (selected) setStateTab(() => itemType = "Found");
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Item Name", hintText: "e.g. Blue Backpack"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Description / Location", hintText: "Describe details, branding, key contents..."),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Reporter Name"),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fill in all fields")),
                      );
                      return;
                    }

                    await _securityService.logLostFoundItem(LostFoundItem(
                      id: "lf_${DateTime.now().millisecondsSinceEpoch}",
                      title: titleCtrl.text,
                      description: descCtrl.text,
                      type: itemType,
                      status: "Open",
                      date: DateTime.now(),
                      contactName: nameCtrl.text,
                    ));

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Belonging logged in catalog successfully"), backgroundColor: Colors.green),
                    );

                    setState(() {}); // refresh list

                    // Reset form
                    titleCtrl.clear();
                    descCtrl.clear();
                    nameCtrl.clear();

                    DefaultTabController.of(context).animateTo(0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Log Item"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
