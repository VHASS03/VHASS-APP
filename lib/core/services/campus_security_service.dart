import 'package:flutter/material.dart';

class GuardProfile {
  final String id;
  final String name;
  final String role; // "Guard", "Supervisor", "Security Head"
  final String contact;
  final String avatarUrl;
  final String shift; // "Morning (06 AM - 02 PM)", "Evening (02 PM - 10 PM)", "Night (10 PM - 06 AM)"
  String location; // e.g. "Main Gate", "Hostel A", "Library Block"
  bool isAvailable;

  GuardProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.contact,
    required this.avatarUrl,
    required this.shift,
    required this.location,
    this.isAvailable = true,
  });
}

class IncidentReport {
  final String id;
  final String title;
  final String description;
  final String category; // "Theft", "Harassment", "Vandalism", "Medical Emergency", "Suspicious Activity"
  final DateTime timestamp;
  final String reportedBy;
  final String contactInfo;
  String status; // "Submitted", "In Investigation", "Resolved", "Closed"
  String? evidenceFileName;
  String? assignedInvestigator;
  String? resolutionDetails;

  IncidentReport({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.timestamp,
    required this.reportedBy,
    required this.contactInfo,
    required this.status,
    this.evidenceFileName,
    this.assignedInvestigator,
    this.resolutionDetails,
  });
}

class SecuritySOSEvent {
  final String id;
  final String studentName;
  final String locationName;
  final double latitude;
  final double longitude;
  final DateTime time;
  String escalationLevel; // "Nearest Guard", "Supervisor", "Security Head"
  String status; // "Active", "Dispatched", "Resolved"
  final List<String> logs;

  SecuritySOSEvent({
    required this.id,
    required this.studentName,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.time,
    required this.escalationLevel,
    required this.status,
    required this.logs,
  });
}

class AuditLog {
  final String id;
  final String action;
  final String performedBy;
  final DateTime timestamp;
  final String details;

  AuditLog({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.timestamp,
    required this.details,
  });
}

class VehicleLog {
  final String id;
  final String vehicleNo;
  final String driver;
  final String status; // "Standby", "Dispatched", "Maintenance"
  final double fuelLevel; // in %
  final String logs;

  VehicleLog({
    required this.id,
    required this.vehicleNo,
    required this.driver,
    required this.status,
    required this.fuelLevel,
    required this.logs,
  });
}

class LostFoundItem {
  final String id;
  final String title;
  final String description;
  final String type; // "Lost", "Found"
  final String status; // "Open", "Claimed", "Resolved"
  final DateTime date;
  final String contactName;

  LostFoundItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.date,
    required this.contactName,
  });
}

class CampusSecurityService {
  static final CampusSecurityService _instance = CampusSecurityService._internal();
  factory CampusSecurityService() => _instance;

  CampusSecurityService._internal() {
    _initMockData();
  }

  final List<GuardProfile> _guards = [];
  final List<IncidentReport> _incidents = [];
  final List<SecuritySOSEvent> _sosEvents = [];
  final List<AuditLog> _auditLogs = [];
  final List<VehicleLog> _vehicles = [];
  final List<LostFoundItem> _lostFoundItems = [];

  List<GuardProfile> get guards => _guards;
  List<IncidentReport> get incidents => _incidents;
  List<SecuritySOSEvent> get sosEvents => _sosEvents;
  List<AuditLog> get auditLogs => _auditLogs;
  List<VehicleLog> get vehicles => _vehicles;
  List<LostFoundItem> get lostFoundItems => _lostFoundItems;

  void _initMockData() {
    // Guards
    _guards.addAll([
      GuardProfile(
        id: "g1",
        name: "Officer John McClane",
        role: "Guard",
        contact: "+1 (555) 012-3456",
        avatarUrl: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150",
        shift: "Morning (06 AM - 02 PM)",
        location: "Main Gate Entry",
      ),
      GuardProfile(
        id: "g2",
        name: "Supervisor James Carter",
        role: "Supervisor",
        contact: "+1 (555) 012-7890",
        avatarUrl: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150",
        shift: "Evening (02 PM - 10 PM)",
        location: "Security Main Office",
      ),
      GuardProfile(
        id: "g3",
        name: "Director Sarah Connor",
        role: "Security Head",
        contact: "+1 (555) 012-1122",
        avatarUrl: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150",
        shift: "General (09 AM - 05 PM)",
        location: "Command HQ",
      ),
    ]);

    // Incidents
    _incidents.addAll([
      IncidentReport(
        id: "inc1",
        title: "Bicycle Theft at Hostel B Lobby",
        description: "A student reported their mountain bike stolen from the ground floor racks between 2 PM and 4 PM today.",
        category: "Theft",
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        reportedBy: "Mark Miller",
        contactInfo: "+1 (555) 014-9988",
        status: "In Investigation",
        assignedInvestigator: "Supervisor James Carter",
      ),
      IncidentReport(
        id: "inc2",
        title: "Broken Window in Science Lab Block C",
        description: "Spotted shattered glass panes on the second floor corridor windows. No intruders seen, possibly storm damage.",
        category: "Vandalism",
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        reportedBy: "Officer John McClane",
        contactInfo: "+1 (555) 012-3456",
        status: "Resolved",
        resolutionDetails: "Facilities team notified. Glass replaced. Incident logged.",
      ),
    ]);

    // SOS events
    _sosEvents.addAll([
      SecuritySOSEvent(
        id: "sos1",
        studentName: "Emily Watson",
        locationName: "Library Parking Lot Area",
        latitude: 12.9716,
        longitude: 77.5946,
        time: DateTime.now().subtract(const Duration(minutes: 8)),
        escalationLevel: "Supervisor",
        status: "Active",
        logs: [
          "09:37 AM - SOS Alert triggered by Emily Watson",
          "09:39 AM - Officer John McClane dispatched to Library Lot",
          "09:41 AM - Escalated to Supervisor James Carter",
        ],
      ),
    ]);

    // Audit logs
    _auditLogs.addAll([
      AuditLog(
        id: "aud1",
        action: "Login",
        performedBy: "Director Sarah Connor",
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        details: "Successful admin authorization from IP 192.168.1.104",
      ),
      AuditLog(
        id: "aud2",
        action: "Roster Update",
        performedBy: "Supervisor James Carter",
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        details: "Assigned Officer John McClane to Main Gate Entry shift roster",
      ),
    ]);

    // Vehicles
    _vehicles.addAll([
      VehicleLog(
        id: "v1",
        vehicleNo: "CAMPUS-PATROL-01",
        driver: "Officer John McClane",
        status: "Standby",
        fuelLevel: 82.5,
        logs: "Shift inspection passed. Ready for dispatch.",
      ),
      VehicleLog(
        id: "v2",
        vehicleNo: "EMERGENCY-AMB-02",
        driver: "Paramedic Bruce Banner",
        status: "Maintenance",
        fuelLevel: 94.0,
        logs: "Brake pad replacement scheduled.",
      ),
    ]);

    // Lost & Found
    _lostFoundItems.addAll([
      LostFoundItem(
        id: "lf1",
        title: "Apple AirPods Case",
        description: "White charging case found in Room 402, Academic Block B.",
        type: "Found",
        status: "Open",
        date: DateTime.now().subtract(const Duration(days: 1)),
        contactName: "Prof. Jane Foster",
      ),
      LostFoundItem(
        id: "lf2",
        title: "Black leather wallet",
        description: "Contains student ID card and driver's license. Lost near the athletic tracks.",
        type: "Lost",
        status: "Claimed",
        date: DateTime.now().subtract(const Duration(days: 3)),
        contactName: "Peter Parker",
      ),
    ]);
  }

  // --- ACTIONS ---

  Future<void> logAudit(String action, String performedBy, String details) async {
    _auditLogs.insert(0, AuditLog(
      id: "aud_${DateTime.now().millisecondsSinceEpoch}",
      action: action,
      performedBy: performedBy,
      timestamp: DateTime.now(),
      details: details,
    ));
  }

  Future<IncidentReport> reportIncident({
    required String title,
    required String description,
    required String category,
    required String reportedBy,
    required String contactInfo,
    String? evidenceFileName,
  }) async {
    final newInc = IncidentReport(
      id: "inc_${DateTime.now().millisecondsSinceEpoch}",
      title: title,
      description: description,
      category: category,
      timestamp: DateTime.now(),
      reportedBy: reportedBy,
      contactInfo: contactInfo,
      status: "Submitted",
      evidenceFileName: evidenceFileName,
    );
    _incidents.insert(0, newInc);
    await logAudit("Incident Reported", reportedBy, "Reported incident ID: ${newInc.id}");
    return newInc;
  }

  Future<void> updateIncidentStatus(String id, String status, {String? resolutionDetails, String? investigator}) async {
    final idx = _incidents.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _incidents[idx].status = status;
      if (resolutionDetails != null) _incidents[idx].resolutionDetails = resolutionDetails;
      if (investigator != null) _incidents[idx].assignedInvestigator = investigator;
      await logAudit("Incident Updated", investigator ?? "HQ Admin", "Updated status of incident $id to $status");
    }
  }

  Future<void> triggerSOSAlert({
    required String studentName,
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    final newSos = SecuritySOSEvent(
      id: "sos_${DateTime.now().millisecondsSinceEpoch}",
      studentName: studentName,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      time: DateTime.now(),
      escalationLevel: "Nearest Guard",
      status: "Active",
      logs: [
        "${DateTime.now().toString().substring(11, 16)} - SOS Alert triggered by $studentName at $locationName"
      ],
    );
    _sosEvents.insert(0, newSos);
    await logAudit("SOS Triggered", studentName, "SOS Alert ID: ${newSos.id}");
  }

  Future<void> escalateSOSEvent(String id, String level, String logMsg) async {
    final idx = _sosEvents.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _sosEvents[idx].escalationLevel = level;
      _sosEvents[idx].logs.add("${DateTime.now().toString().substring(11, 16)} - $logMsg");
      await logAudit("SOS Escalated", "System", "Escalated SOS $id to $level");
    }
  }

  Future<void> resolveSOSEvent(String id) async {
    final idx = _sosEvents.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _sosEvents[idx].status = "Resolved";
      _sosEvents[idx].logs.add("${DateTime.now().toString().substring(11, 16)} - SOS Alert marked as resolved.");
      await logAudit("SOS Resolved", "Security Team", "Resolved SOS alert $id");
    }
  }

  Future<void> updateGuardRoster(String guardId, String newLocation, String newShift) async {
    final idx = _guards.indexWhere((g) => g.id == guardId);
    if (idx != -1) {
      _guards[idx].location = newLocation;
      // We will keep shift unmodified or update if needed
      await logAudit("Roster Shifted", "HQ Admin", "Moved Guard $guardId to location $newLocation");
    }
  }

  Future<void> logLostFoundItem(LostFoundItem item) async {
    _lostFoundItems.insert(0, item);
  }

  Future<void> addVehicleLog(VehicleLog vLog) async {
    _vehicles.add(vLog);
  }
}
