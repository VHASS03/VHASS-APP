import 'package:flutter/material.dart';
import 'api_service.dart';
import 'storage_service.dart';

class Counsellor {
  final String id;
  final String name;
  final String specialization;
  final String imageUrl;
  final double rating;
  final List<String> availability; // Time slots like "09:00 AM", "11:00 AM"
  final String email;

  Counsellor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.imageUrl,
    required this.rating,
    required this.availability,
    required this.email,
  });
}

class Appointment {
  final String id;
  final String studentName;
  final String studentPhone;
  final String concern; // e.g. "Anxiety Support"
  final DateTime date;
  final String timeSlot;
  final Counsellor counsellor;
  String status; // "Pending", "Approved", "Rejected", "Completed", "Rescheduled"
  final bool isHighPriority;

  Appointment({
    required this.id,
    required this.studentName,
    required this.studentPhone,
    required this.concern,
    required this.date,
    required this.timeSlot,
    required this.counsellor,
    required this.status,
    this.isHighPriority = false,
  });
}

class WellnessEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String location;
  final String speaker;
  final String imageUrl;
  bool isRegistered;

  WellnessEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.speaker,
    required this.imageUrl,
    this.isRegistered = false,
  });
}

class ResourceArticle {
  final String id;
  final String title;
  final String category;
  final String readTime;
  final String content;
  final String author;
  final String imageUrl;

  ResourceArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.readTime,
    required this.content,
    required this.author,
    required this.imageUrl,
  });
}

class UniversityWellnessService {
  static final UniversityWellnessService _instance = UniversityWellnessService._internal();
  factory UniversityWellnessService() => _instance;

  UniversityWellnessService._internal() {
    _initMockData();
  }

  final List<Counsellor> _counsellors = [];
  final List<Appointment> _appointments = [];
  final List<WellnessEvent> _events = [];
  final List<ResourceArticle> _articles = [];

  List<Counsellor> get counsellors => _counsellors;
  List<Appointment> get appointments => _appointments;
  List<WellnessEvent> get events => _events;
  List<ResourceArticle> get articles => _articles;

  void _initMockData() {
    // Counsellors
    _counsellors.addAll([
      Counsellor(
        id: "65b9fc0e5e0423c10b7f8de1",
        name: "Dr. Elena Gilbert",
        specialization: "Anxiety & Depression Specialist",
        imageUrl: "https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=150",
        rating: 4.9,
        availability: ["09:00 AM", "10:00 AM", "11:30 AM", "02:00 PM", "04:00 PM"],
        email: "elena.g@university.edu",
      ),
      Counsellor(
        id: "65b9fc0e5e0423c10b7f8de2",
        name: "Dr. Alaric Saltzman",
        specialization: "Stress Management & Academics Specialist",
        imageUrl: "https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=150",
        rating: 4.8,
        availability: ["10:30 AM", "11:00 AM", "01:00 PM", "03:00 PM", "05:00 PM"],
        email: "alaric.s@university.edu",
      ),
      Counsellor(
        id: "65b9fc0e5e0423c10b7f8de3",
        name: "Dr. Stefan Salvatore",
        specialization: "Crisis Intervention & Relationships Counsel",
        imageUrl: "https://images.unsplash.com/photo-1537368910025-700350fe46c7?w=150",
        rating: 4.7,
        availability: ["09:30 AM", "12:00 PM", "02:30 PM", "03:30 PM", "04:30 PM"],
        email: "stefan.s@university.edu",
      ),
    ]);

    // Resource Articles
    _articles.addAll([
      ResourceArticle(
        id: "a1",
        title: "Navigating Academic Burnout: A Guide for Students",
        category: "Academic Pressure Support",
        readTime: "5 min read",
        author: "Dr. Alaric Saltzman",
        imageUrl: "https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=400",
        content: """
Academic pressure is one of the leading causes of chronic stress and mental exhaustion among university students. When demands exceed physical and emotional capacity, burnout sets in.

### Recognizing the Signs
1. **Emotional Exhaustion**: Feeling constantly tired, detached, or unable to cope.
2. **Decreased Performance**: Difficulty concentrating, lack of motivation, and falling grades.
3. **Physical Symptoms**: Frequent headaches, insomnia, or muscle tension.

### Actionable Coping Strategies
- **Practice Time Boxing**: Dedicate specific blocks of time to study, but strictly set aside blocks for rest and socialization.
- **Set Realistic Goals**: Break down complex projects into bite-sized, daily tasks.
- **Learn to Say No**: Avoid overcommitting to extracurricular roles.
- **Seek Support**: Reach out to university wellness services early.
        """,
      ),
      ResourceArticle(
        id: "a2",
        title: "Understanding and Managing Panic Attacks",
        category: "Anxiety Support",
        readTime: "7 min read",
        author: "Dr. Elena Gilbert",
        imageUrl: "https://images.unsplash.com/photo-1474418386616-3d6f6e9a8b3d?w=400",
        content: """
A panic attack is a sudden episode of intense fear that triggers severe physical reactions when there is no real danger or apparent cause.

### The 5-4-3-2-1 Grounding Method
When panic begins to rise, try focusing on your surroundings using this simple exercise:
- **5 things you can SEE**: Look for small details (a clock, a leaf, a book).
- **4 things you can TOUCH**: Feel the texture of your shirt, the table, or the floor.
- **3 things you can HEAR**: Listen to birds, air conditioning, or distant traffic.
- **2 things you can SMELL**: Identify soap, perfume, or coffee.
- **1 thing you can TASTE**: Sip warm water or pop a mint.

### Breathing Exercise
Inhale slowly for 4 seconds, hold for 4 seconds, and exhale smoothly for 6 seconds. This slows down the autonomic nervous system.
        """,
      ),
      ResourceArticle(
        id: "a3",
        title: "Building Healthy Relationships in College",
        category: "Relationship Guidance",
        readTime: "4 min read",
        author: "Dr. Stefan Salvatore",
        imageUrl: "https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?w=400",
        content: """
Navigating relationships at university is vital for social support and personal growth. A healthy relationship is built on mutual respect, trust, and communication.

### Key Pillars
- **Honest Communication**: Express your feelings openly without fear of judgment.
- **Boundaries**: Respect each other's physical and emotional space.
- **Independence**: Balance relationship time with studies and personal hobbies.
        """,
      ),
    ]);

    // Wellness Events & Workshops
    _events.addAll([
      WellnessEvent(
        id: "e1",
        title: "Mindfulness & Stress Management Seminar",
        description: "Join us for a guided meditation session and learn cognitive techniques to manage final exam stress.",
        date: DateTime.now().add(const Duration(days: 2)),
        time: "02:00 PM - 03:30 PM",
        location: "Seminar Hall C & Zoom",
        speaker: "Dr. Alaric Saltzman",
        imageUrl: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400",
      ),
      WellnessEvent(
        id: "e2",
        title: "Crisis Intervention & Mental Well-being Workshop",
        description: "A specialized workshop for peer educators and student leaders on identifying mental distress in peers and routing support.",
        date: DateTime.now().add(const Duration(days: 5)),
        time: "10:00 AM - 01:00 PM",
        location: "Wellness Lounge, Campus Block A",
        speaker: "Dr. Stefan Salvatore & Dr. Elena Gilbert",
        imageUrl: "https://images.unsplash.com/photo-1515187029135-18ee286d815b?w=400",
      ),
    ]);

    // Initial Appointments
    _appointments.addAll([
      Appointment(
        id: "ap1",
        studentName: "John Doe",
        studentPhone: "+1 (555) 019-2834",
        concern: "Anxiety Support",
        date: DateTime.now().add(const Duration(days: 1)),
        timeSlot: "10:00 AM",
        counsellor: _counsellors[0],
        status: "Approved",
      ),
      Appointment(
        id: "ap2",
        studentName: "Jane Smith",
        studentPhone: "+1 (555) 018-9281",
        concern: "Academic Pressure Support",
        date: DateTime.now().add(const Duration(days: 2)),
        timeSlot: "11:00 AM",
        counsellor: _counsellors[1],
        status: "Pending",
      ),
      Appointment(
        id: "ap3",
        studentName: "Alex Vance",
        studentPhone: "+1 (555) 014-4421",
        concern: "Crisis Intervention",
        date: DateTime.now(),
        timeSlot: "02:30 PM",
        counsellor: _counsellors[2],
        status: "Approved",
        isHighPriority: true,
      ),
    ]);
  }

  // --- ACTIONS ---

  // Helper to parse timeSlot like "09:00 AM" or "09:30" to 24h format "09:00"
  String _parseTo24h(String timeSlot) {
    try {
      timeSlot = timeSlot.trim().toUpperCase();
      if (timeSlot.contains("AM") || timeSlot.contains("PM")) {
        final parts = timeSlot.split(" ");
        final timeParts = parts[0].split(":");
        int hour = int.parse(timeParts[0]);
        final minutes = timeParts[1];
        if (timeSlot.contains("PM") && hour < 12) {
          hour += 12;
        } else if (timeSlot.contains("AM") && hour == 12) {
          hour = 0;
        }
        return "${hour.toString().padLeft(2, '0')}:$minutes";
      }
      return timeSlot;
    } catch (_) {
      return timeSlot;
    }
  }

  String _calculateEndTime(String startTime24h) {
    try {
      final parts = startTime24h.split(":");
      final hour = int.parse(parts[0]);
      final min = int.parse(parts[1]);
      final endMinTotal = min + 45;
      final endHour = (hour + (endMinTotal ~/ 60)) % 24;
      final endMin = endMinTotal % 60;
      return "${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}";
    } catch (_) {
      return startTime24h; // fallback
    }
  }

  Future<List<String>> fetchAvailableSlots(String counsellorId, DateTime date) async {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    try {
      final response = await ApiService.get<dynamic>(
        '/appointments/slots/$counsellorId/$dateStr',
      );
      if (response.success && response.data != null) {
        final dynamic dataList = response.data;
        if (dataList is List) {
          return dataList.map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      print("❌ Error fetching slots: $e");
    }
    // Fallback/Default slots if api fails or is empty
    final counsellor = _counsellors.firstWhere((c) => c.id == counsellorId, orElse: () => _counsellors.first);
    return counsellor.availability;
  }

  Future<List<Appointment>> fetchAppointments() async {
    try {
      final response = await ApiService.get<dynamic>(
        '/appointments',
      );
      if (response.success && response.data != null) {
        final dynamic list = response.data;
        if (list is List) {
          _appointments.clear();
          for (var item in list) {
            try {
              final counsellorId = item['counsellor']?.toString() ?? '';
              final c = _counsellors.firstWhere((c) => c.id == counsellorId, orElse: () => _counsellors.first);
              final appDate = DateTime.tryParse(item['date']?.toString() ?? '') ?? DateTime.now();
              final startTime = item['startTime']?.toString() ?? '';
              
              _appointments.add(Appointment(
                id: item['_id']?.toString() ?? '',
                studentName: item['studentName']?.toString() ?? 'Student',
                studentPhone: item['studentPhone']?.toString() ?? '',
                concern: item['notes']?.toString() ?? 'General Support',
                date: appDate,
                timeSlot: startTime,
                counsellor: c,
                status: item['status']?.toString() ?? 'Pending',
                isHighPriority: item['type']?.toString() == 'emergency',
              ));
            } catch (e) {
              print("❌ Error parsing appointment: $e");
            }
          }
        }
      }
    } catch (e) {
      print("❌ Error fetching appointments: $e");
    }
    return _appointments;
  }

  Future<Appointment> bookAppointment({
    required String studentName,
    required String studentPhone,
    required String concern,
    required DateTime date,
    required String timeSlot,
    required Counsellor counsellor,
    bool isHighPriority = false,
  }) async {
    final studentId = await StorageService.getUserId() ?? "65b9fc0e5e0423c10b7f8abc";
    final startTime = _parseTo24h(timeSlot);
    final endTime = _calculateEndTime(startTime);
    final isoDateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}T00:00:00.000Z";

    final payload = {
      "student": studentId,
      "counsellor": counsellor.id,
      "date": isoDateStr,
      "startTime": startTime,
      "endTime": endTime,
      "type": isHighPriority ? "emergency" : "scheduled",
      "notes": concern,
      "status": "pending"
    };

    Appointment newAp;
    try {
      final response = await ApiService.post<dynamic>('/appointments', payload);
      if (response.success && response.data != null) {
        final dynamic data = response.data;
        newAp = Appointment(
          id: data['_id']?.toString() ?? "ap_${DateTime.now().millisecondsSinceEpoch}",
          studentName: studentName,
          studentPhone: studentPhone,
          concern: concern,
          date: date,
          timeSlot: timeSlot,
          counsellor: counsellor,
          status: "Pending",
          isHighPriority: isHighPriority,
        );
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      print("❌ Error booking appointment on backend, fallback to local: $e");
      newAp = Appointment(
        id: "ap_${DateTime.now().millisecondsSinceEpoch}",
        studentName: studentName,
        studentPhone: studentPhone,
        concern: concern,
        date: date,
        timeSlot: timeSlot,
        counsellor: counsellor,
        status: "Pending",
        isHighPriority: isHighPriority,
      );
    }

    _appointments.add(newAp);
    return newAp;
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _appointments[idx].status = status;
    }
  }

  Future<void> registerForEvent(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _events[idx].isRegistered = true;
    }
  }

  Future<void> addCounsellor(Counsellor counsellor) async {
    _counsellors.add(counsellor);
  }
}
