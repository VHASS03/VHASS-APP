import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'sms_service.dart';
import 'dialer_service.dart';
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
  /// Calls contacts one after another (no conference, no delay between starting each call)
  static Future<void> _executeInstructions(
    List<DeviceInstruction> instructions,
  ) async {
    // Separate call and SMS instructions
    final callInstructions = instructions
        .where((i) => i.action == 'CALL')
        .toList();
    final smsInstructions = instructions
        .where((i) => i.action == 'SEND_SMS')
        .toList();
    
    print('📞 [SOS] Processing ${callInstructions.length} CALL instructions and ${smsInstructions.length} SMS instructions');
    
    // Handle calls - call each contact one after another, no delay
    if (callInstructions.isNotEmpty) {
      final phoneNumbers = callInstructions
          .map((i) => _formatPhoneForCall(i.phoneNumber, i.countryCode))
          .toList();
      
      print('📞 [SOS] Phone numbers to call: $phoneNumbers');
      await _callAllContactsSequentially(phoneNumbers);
    }
    
    // Handle SMS - send to ALL contacts with location
    for (final instruction in smsInstructions) {
      await _sendSMS(
        instruction.phoneNumber,
        instruction.contactName,
        instruction.countryCode,
      );
    }
  }
  
  /// Call contacts one after another with no delay between starting each call
  static Future<void> _callAllContactsSequentially(List<String> phoneNumbers) async {
    print('📞 [SOS] Calling ${phoneNumbers.length} contacts one after another (no delay)');
    
    for (final number in phoneNumbers) {
      try {
        print('📞 [SOS] Calling: $number');
        DialerService.makeCall(number).catchError((e) {
          print('❌ [SOS] Call failed for $number: $e');
          return false;
        });
      } catch (e) {
        print('❌ [SOS] Error initiating call to $number: $e');
      }
    }
    
    print('✅ [SOS] All ${phoneNumbers.length} contacts called');
  }
  
  /// Format phone number for calling
  /// Handles numbers like "9123456789" where "91" is part of the number, not country code
  static String _formatPhoneForCall(String phoneNumber, String countryCode) {
    // Clean the number - remove everything except digits and +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // If already has + prefix, return as is
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    
    // Define expected lengths for countries
    const countryLengths = {
      'IN': 10,  // India: 10 digits
      'US': 10,  // USA: 10 digits
      'UK': 10,  // UK: 10 digits
      'PK': 10,  // Pakistan: 10 digits
      'BD': 10,  // Bangladesh: 10 digits
    };
    
    final expectedLength = countryLengths[countryCode] ?? 10;
    
    // Get dial code for country
    const dialCodes = {
      'IN': '91',
      'US': '1',
      'UK': '44',
      'PK': '92',
      'BD': '880',
    };
    
    final dialCode = dialCodes[countryCode] ?? '91';
    
    // ONLY strip existing country code if number is LONGER than expected
    // This prevents treating "9123456789" as "91" + "23456789"
    if (cleaned.startsWith(dialCode) && cleaned.length > expectedLength) {
      // Number has country code prefixed, strip it and re-add with +
      cleaned = cleaned.substring(dialCode.length);
    }
    
    // Now add the country code with +
    return '+$dialCode$cleaned';
  }
  
  /// Make phone call to a single contact (public utility method)
  /// Uses native dialer with fallback to url_launcher
  static Future<void> makeEmergencyCall(String phoneNumber, String countryCode) async {
    try {
      final formattedNumber = _formatPhoneForCall(phoneNumber, countryCode);
      
      // Try native dialer service first (more reliable)
      final success = await DialerService.makeCall(formattedNumber);
      
      if (!success) {
        // Fallback to url_launcher
        final uri = Uri.parse('tel:$formattedNumber');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('📞 Dialer opened for: $formattedNumber');
        } else {
          print('❌ Cannot launch dialer');
        }
      } else {
        print('📞 Call initiated to: $formattedNumber');
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

      // Send SMS to all contacts concurrently using Future.wait for maximum speed
      final smsFutures = contacts.map((contact) async {
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
        } catch (e) {
          print('❌ [SOS] Error sending SMS to ${contact.name}: $e');
        }
      }).toList();

      await Future.wait(smsFutures);
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

  /// Create emergency SMS message with LIVE tracking link and Google Maps link
  static String _createEmergencySMSMessage(
    String userName,
    Position? position,
  ) {
    final time = DateTime.now();
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    
    // Create LIVE tracking link if SOS ID exists
    final liveTrackingLink = _currentSosId != null 
        ? 'https://vhass-backend-jfpr.onrender.com/track/$_currentSosId'
        : null;
    
    if (position == null) {
      return '🚨 EMERGENCY ALERT 🚨\n'
          '$userName needs immediate help!\n\n'
          '${liveTrackingLink != null ? '🔴 LIVE TRACKING:\n$liveTrackingLink\n\n' : ''}'
          'Location: Being determined...\n'
          '⏰ Time: $timeStr\n\n'
          'Please respond urgently or call 112/999\n'
          'Location updates coming every 30 seconds!';
    }
    
    final lat = position.latitude.toStringAsFixed(6);
    final lng = position.longitude.toStringAsFixed(6);
    final mapsLink = 'https://maps.google.com/?q=$lat,$lng';

    return '🚨 EMERGENCY ALERT 🚨\n'
        '$userName needs immediate help!\n\n'
        '${liveTrackingLink != null ? '🔴 LIVE TRACKING LINK:\n$liveTrackingLink\n\n' : ''}'
        '📍 CURRENT LOCATION:\n'
        '$mapsLink\n\n'
        'Coordinates: $lat, $lng\n'
        'Accuracy: ${position.accuracy.toStringAsFixed(0)}m\n'
        '⏰ Time: $timeStr\n\n'
        'Track LIVE with link above!\n'
        'Updates every 30 seconds.\n'
        'Call 112 if you cannot reach them!';
  }
  
  /// Send location update SMS to all contacts (for live tracking)
  /// Called every 30 seconds during emergency
  static Future<void> sendLocationUpdateToContacts({
    required Position position,
    required String userName,
  }) async {
    try {
      print('📱 [SOS] Sending location update SMS (every 30 seconds)...');
      
      final contacts = await _getEmergencyContacts();
      if (contacts.isEmpty) {
        print('⚠️ [SOS] No contacts for location update');
        return;
      }
      
      final lat = position.latitude.toStringAsFixed(6);
      final lng = position.longitude.toStringAsFixed(6);
      final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
      final time = DateTime.now();
      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      
      // Create LIVE tracking link if SOS ID exists
      final liveTrackingLink = _currentSosId != null 
          ? 'https://vhass-backend-jfpr.onrender.com/track/$_currentSosId'
          : null;
      
      final message = '📍 LIVE LOCATION UPDATE\n'
          '$userName - Emergency active\n\n'
          '${liveTrackingLink != null ? '🔴 LIVE TRACKING:\n$liveTrackingLink\n\n' : ''}'
          '📍 Current location:\n'
          '$mapsLink\n\n'
          'Coords: $lat, $lng\n'
          '⏰ Updated: $timeStr';
      
      for (final contact in contacts) {
        try {
          await SMSService.sendCustomSMS(contact.phone, message);
          print('✅ [SOS] Location SMS sent to ${contact.name}');
        } catch (e) {
          print('❌ [SOS] SMS failed: $e');
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      print('❌ [SOS] Error sending location update: $e');
    }
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
