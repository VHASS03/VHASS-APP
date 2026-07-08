import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/colors.dart';
import '../../core/services/university_wellness_service.dart';

class CounsellingPortalScreen extends StatefulWidget {
  const CounsellingPortalScreen({super.key});

  @override
  State<CounsellingPortalScreen> createState() => _CounsellingPortalScreenState();
}

class _CounsellingPortalScreenState extends State<CounsellingPortalScreen> {
  final _wellnessService = UniversityWellnessService();
  
  final List<String> _concerns = [
    "Psychological Counselling",
    "Stress Management Support",
    "Academic Pressure Support",
    "Anxiety Support",
    "Depression Support",
    "Career Guidance",
    "Relationship Guidance",
    "Crisis Intervention",
  ];

  bool _isLoadingAppointments = false;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoadingAppointments = true);
    await _wellnessService.fetchAppointments();
    if (mounted) {
      setState(() => _isLoadingAppointments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Mental Health & Counselling"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Appointments"),
              Tab(text: "Book A Session"),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Current appointments and history
            _buildAppointmentsListTab(),
            // Tab 2: Booking Wizard
            _buildBookingWizardTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsListTab() {
    if (_isLoadingAppointments) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final list = _wellnessService.appointments;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: AppColors.primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              "No appointments scheduled",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Go to the 'Book A Session' tab to schedule a session.",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            )
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final appointment = list[index];
          final isCompleted = appointment.status == "Completed";
          final isRejected = appointment.status == "Rejected";

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: appointment.isHighPriority ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                width: appointment.isHighPriority ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (appointment.isHighPriority)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "CRISIS / HIGH PRIORITY",
                              style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(appointment.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            appointment.status,
                            style: TextStyle(
                              color: _getStatusColor(appointment.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(appointment.date),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  appointment.concern,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(appointment.counsellor.imageUrl),
                      radius: 16,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      appointment.counsellor.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      appointment.timeSlot,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                if (!isCompleted && !isRejected && appointment.status != "Cancelled") ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              appointment.status = "Cancelled";
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Appointment cancelled successfully")),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _showRescheduleDialog(appointment);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Reschedule"),
                        ),
                      ),
                    ],
                  )
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingWizardTab() {
    return _BookingWizard(
      concerns: _concerns,
      counsellors: _wellnessService.counsellors,
      onBooked: () {
        setState(() {});
        _loadAppointments();
        DefaultTabController.of(context).animateTo(0);
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "confirmed":
        return Colors.green;
      case "pending":
      case "requested":
        return Colors.orange;
      case "cancelled":
      case "rejected":
        return Colors.red;
      case "completed":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showRescheduleDialog(Appointment appointment) {
    DateTime selectedDate = appointment.date;
    String selectedSlot = appointment.timeSlot;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setD) {
            return AlertDialog(
              title: const Text("Reschedule Appointment"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text("Select New Date"),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setD(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedSlot,
                    items: appointment.counsellor.availability.map((slot) {
                      return DropdownMenuItem(
                        value: slot,
                        child: Text(slot),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setD(() => selectedSlot = val);
                      }
                    },
                    decoration: const InputDecoration(labelText: "Time Slot"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Update properties
                      final idx = _wellnessService.appointments.indexWhere((a) => a.id == appointment.id);
                      if (idx != -1) {
                        _wellnessService.appointments[idx] = Appointment(
                          id: appointment.id,
                          studentName: appointment.studentName,
                          studentPhone: appointment.studentPhone,
                          concern: appointment.concern,
                          date: selectedDate,
                          timeSlot: selectedSlot,
                          counsellor: appointment.counsellor,
                          status: "Rescheduled",
                          isHighPriority: appointment.isHighPriority,
                        );
                      }
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Appointment rescheduled successfully")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Reschedule"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BookingWizard extends StatefulWidget {
  final List<String> concerns;
  final List<Counsellor> counsellors;
  final VoidCallback onBooked;

  const _BookingWizard({
    required this.concerns,
    required this.counsellors,
    required this.onBooked,
  });

  @override
  State<_BookingWizard> createState() => _BookingWizardState();
}

class _BookingWizardState extends State<_BookingWizard> {
  int _currentStep = 0;
  
  // Selection States
  String? _selectedConcern;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTimeSlot;
  Counsellor? _selectedCounsellor;
  
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isCrisis = false;

  List<String> _availableSlots = [];
  bool _isLoadingSlots = false;

  Future<void> _loadAvailableSlots() async {
    if (_selectedCounsellor == null) return;
    setState(() => _isLoadingSlots = true);
    final slots = await UniversityWellnessService().fetchAvailableSlots(
      _selectedCounsellor!.id,
      _selectedDate,
    );
    if (mounted) {
      setState(() {
        _availableSlots = slots;
        _isLoadingSlots = false;
        if (_selectedTimeSlot != null && !_availableSlots.contains(_selectedTimeSlot)) {
          _selectedTimeSlot = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stepper(
      type: StepperType.vertical,
      currentStep: _currentStep,
      onStepCancel: () {
        if (_currentStep > 0) {
          setState(() => _currentStep--);
        }
      },
      onStepContinue: () {
        if (_currentStep == 0 && _selectedConcern == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please select a counselling concern")),
          );
          return;
        }
        if (_currentStep == 1 && _selectedCounsellor == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please choose a counsellor")),
          );
          return;
        }
        if (_currentStep == 2 && _selectedTimeSlot == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please pick a time slot")),
          );
          return;
        }

        if (_currentStep < 3) {
          setState(() => _currentStep++);
        } else {
          // Final Submit
          _finalizeBooking();
        }
      },
      controlsBuilder: (context, details) {
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(_currentStep == 3 ? 'Confirm Booking 🎉' : 'Continue'),
              ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
              ],
            ],
          ),
        );
      },
      steps: [
        Step(
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.editing,
          title: const Text("1. Select Support Concern"),
          content: Column(
            children: widget.concerns.map((c) {
              final sel = c == _selectedConcern;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? AppColors.primary : Colors.grey.withOpacity(0.3)),
                ),
                child: ListTile(
                  title: Text(c, style: TextStyle(fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  trailing: sel ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () => setState(() => _selectedConcern = c),
                ),
              );
            }).toList(),
          ),
        ),
        Step(
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.editing,
          title: const Text("2. Choose Counsellor"),
          content: Column(
            children: widget.counsellors.map((c) {
              final sel = c == _selectedCounsellor;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? AppColors.primary : Colors.grey.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(c.imageUrl)),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(c.specialization, style: const TextStyle(fontSize: 12)),
                  trailing: Text("⭐ ${c.rating}"),
                  onTap: () {
                    setState(() {
                      _selectedCounsellor = c;
                      _selectedTimeSlot = null; // Reset slots
                    });
                    _loadAvailableSlots();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Step(
          isActive: _currentStep >= 2,
          state: _currentStep > 2 ? StepState.complete : StepState.editing,
          title: const Text("3. Pick Date & Time Slot"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: const Text("Session Date"),
                subtitle: Text(DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _loadAvailableSlots();
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text("Available Slots", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_selectedCounsellor != null)
                _isLoadingSlots
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _availableSlots.isEmpty
                        ? const Text("No available slots found for this date.", style: TextStyle(color: Colors.red))
                        : Wrap(
                            spacing: 10,
                            children: _availableSlots.map((slot) {
                              final sel = slot == _selectedTimeSlot;
                              return ChoiceChip(
                                label: Text(slot),
                                selected: sel,
                                onSelected: (selected) {
                                  setState(() => _selectedTimeSlot = selected ? slot : null);
                                },
                                selectedColor: AppColors.primary.withOpacity(0.2),
                                checkmarkColor: AppColors.primary,
                              );
                            }).toList(),
                          )
              else
                const Text("Please select a counsellor first.", style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        Step(
          isActive: _currentStep >= 3,
          state: StepState.editing,
          title: const Text("4. Patient Information"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Full Name", hintText: "Student Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Phone Number", hintText: "+1 (555) 000-0000"),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text("Is this a mental health emergency / crisis?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text("This routes your booking to our high priority crisis queue."),
                value: _isCrisis,
                onChanged: (val) => setState(() => _isCrisis = val),
                activeColor: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _finalizeBooking() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in your name and phone number")),
      );
      return;
    }

    await UniversityWellnessService().bookAppointment(
      studentName: _nameCtrl.text,
      studentPhone: _phoneCtrl.text,
      concern: _selectedConcern!,
      date: _selectedDate,
      timeSlot: _selectedTimeSlot!,
      counsellor: _selectedCounsellor!,
      isHighPriority: _isCrisis,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Appointment request submitted successfully!"),
        backgroundColor: Colors.green,
      ),
    );

    // Reset wizard
    setState(() {
      _currentStep = 0;
      _selectedConcern = null;
      _selectedCounsellor = null;
      _selectedTimeSlot = null;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _isCrisis = false;
    });

    widget.onBooked();
  }
}
