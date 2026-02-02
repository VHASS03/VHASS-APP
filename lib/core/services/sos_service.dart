import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'sms_service.dart';
import '../models/device_instruction.dart';
import '../models/api_response.dart';
import '../utils/phone_formatter.dart';

/// SOS Service
/// Handles SOS triggering, location updates, and device instructions
class SOSService {
  static String? _currentSosId;

  /// Trigger SOS
  static Future<ApiResponse<Map<String, dynamic>>> triggerSOS() async {
    try {
      // Get current location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        print('Location error: $e');
        // Continue without location
      }

      final response = await ApiService.post<Map<String, dynamic>>(
        '/sos/trigger',
        {
          if (position != null) ...{
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        },
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        _currentSosId = data['sosId'] as String?;

        // Execute device instructions
        if (data['instructions'] != null) {
          final instructions = (data['instructions'] as List)
              .map((i) => DeviceInstruction.fromJson(i))
              .toList();
          await _executeInstructions(instructions);
        }
      }

      return response;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to trigger SOS: ${e.toString()}',
      );
    }
  }

  /// Execute device instructions (CALL/SMS)
  static Future<void> _executeInstructions(
    List<DeviceInstruction> instructions,
  ) async {
    for (final instruction in instructions) {
      if (instruction.action == 'CALL') {
        await _makeCall(instruction.phoneNumber, instruction.countryCode);
      } else if (instruction.action == 'SEND_SMS') {
        await _sendSMS(
          instruction.phoneNumber,
          instruction.contactName,
          instruction.countryCode,
        );
      }
    }
  }

  /// Make phone call
  static Future<void> _makeCall(String phoneNumber, String countryCode) async {
    try {
      // Use url_launcher with tel: URI (works on all devices including emulator)
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        final formattedNumber = PhoneFormatter.formatPhoneNumber(
          phoneNumber,
          countryCode,
        );
        print('📞 Dialer opened for: $formattedNumber');
      } else {
        print('❌ Cannot launch dialer');
      }
    } catch (e) {
      print('❌ Call error: $e');
    }
  }

  /// Send SMS
  static Future<void> _sendSMS(
    String phoneNumber,
    String contactName,
    String countryCode,
  ) async {
    try {
      final message =
          'EMERGENCY: $contactName, I need immediate help. My location is being shared. Please respond.';
      final uri = Uri.parse(
        'sms:$phoneNumber?body=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        final formattedNumber = PhoneFormatter.formatPhoneNumber(
          phoneNumber,
          countryCode,
        );
        print('💬 SMS opened for: $formattedNumber');
      } else {
        print('❌ Cannot launch SMS');
      }
    } catch (e) {
      print('❌ SMS error: $e');
    }
  }

  /// Update SOS location
  static Future<void> updateLocation() async {
    if (_currentSosId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await ApiService.post('/sos/update-location', {
        'sosId': _currentSosId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      });
    } catch (e) {
      print('Location update error: $e');
    }
  }

  /// End SOS
  static Future<ApiResponse<void>> endSOS({required String reason}) async {
    if (_currentSosId == null) {
      return ApiResponse(success: false, message: 'No active SOS');
    }

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        // Continue without location
      }

      final response = await ApiService.post('/sos/end', {
        'sosId': _currentSosId,
        'reason': reason,
        if (position != null) ...{
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      });

      if (response.success) {
        _currentSosId = null;
      }

      return response as ApiResponse<void>;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to end SOS: ${e.toString()}',
      );
    }
  }

  /// Get current SOS ID
  static String? getCurrentSosId() => _currentSosId;

  /// Send emergency SMS alerts to all emergency contacts
  /// Uses device's native SMS service via SIM card
  static Future<void> sendEmergencySMSAlerts({
    required Position? position,
    required String userName,
  }) async {
    try {
      print('📱 [SOS] Sending emergency SMS alerts to all contacts...');

      // Get emergency contacts from local storage or API
      final contacts = await _getEmergencyContacts();

      if (contacts.isEmpty) {
        print('⚠️ [SOS] No emergency contacts available for SMS');
        return;
      }

      // Create emergency message with location
      final message = _createEmergencySMSMessage(userName, position);

      print('📱 [SOS] Emergency message: $message');
      print('📱 [SOS] Sending SMS to ${contacts.length} emergency contacts...');

      // Send SMS to each contact using device's native SMS
      for (final contact in contacts) {
        try {
          final success = await SMSService.sendCustomSMS(
            contact.phone,
            message,
          );

          if (success) {
            print('✅ [SOS] SMS sent to ${contact.name} (${contact.phone})');
          } else {
            print('⚠️ [SOS] Failed to send SMS to ${contact.name}');
          }

          // Small delay between SMS to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          print('❌ [SOS] Error sending SMS to ${contact.name}: $e');
        }
      }
    } catch (e) {
      print('❌ [SOS] Error in sendEmergencySMSAlerts: $e');
    }
  }

  /// Get emergency contacts
  static Future<List<EmergencyContact>> _getEmergencyContacts() async {
    try {
      // Try to get from API first
      final response = await ApiService.get<List<dynamic>>(
        '/contacts',
        fromJson: (data) {
          if (data is List) {
            return data.map((item) => EmergencyContact.fromJson(item)).toList();
          }
          return [];
        },
      );

      if (response.success && response.data != null) {
        return response.data! as List<EmergencyContact>;
      }

      return [];
    } catch (e) {
      print('⚠️ [SOS] Error fetching emergency contacts: $e');
      return [];
    }
  }

  /// Create emergency SMS message with location
  static String _createEmergencySMSMessage(
    String userName,
    Position? position,
  ) {
    final locationInfo = position != null
        ? 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
        : 'Location: Being determined...';

    return '🚨 EMERGENCY ALERT 🚨\n'
        '$userName needs immediate help!\n'
        '$locationInfo\n'
        'Please respond urgently or call 112/999\n'
        'This is an automated emergency alert.';
  }
}

/// Emergency Contact Model
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String countryCode;
  final int priority;
  final bool isActive;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.countryCode,
    required this.priority,
    required this.isActive,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      phone: json['phone'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? 'IN',
      priority: json['priority'] as int? ?? 999,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
