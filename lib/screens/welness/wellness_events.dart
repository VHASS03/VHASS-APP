import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/services/university_wellness_service.dart';

class WellnessEventsScreen extends StatefulWidget {
  const WellnessEventsScreen({super.key});

  @override
  State<WellnessEventsScreen> createState() => _WellnessEventsScreenState();
}

class _WellnessEventsScreenState extends State<WellnessEventsScreen> {
  final _wellnessService = UniversityWellnessService();

  @override
  Widget build(BuildContext context) {
    final events = _wellnessService.events;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Wellness Events & Workshops"),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              elevation: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    event.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('EEEE, MMM dd').format(event.date),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: event.isRegistered ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                event.isRegistered ? "Registered" : "Open for Registration",
                                style: TextStyle(
                                  color: event.isRegistered ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          event.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.description,
                          style: TextStyle(color: isDark ? AppColors.textSecondary : Colors.grey[700], fontSize: 13, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              event.speaker,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              event.location,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: event.isRegistered
                                ? null
                                : () async {
                                    await _wellnessService.registerForEvent(event.id);
                                    setState(() {});
                                    _showSuccessNotification(event.title);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(event.isRegistered ? "Registered ✓" : "Register Now"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSuccessNotification(String title) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text("Registration Success"),
            ],
          ),
          content: Text("You have successfully registered for the workshop:\n\n\"$title\""),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Awesome!"),
            ),
          ],
        );
      },
    );
  }
}
