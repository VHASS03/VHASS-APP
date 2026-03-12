import 'package:device_info_plus/device_info_plus.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/api_response.dart';
import 'dart:io';

/// Authentication Service
class AuthService {
  /// Sign up new user with details and emergency contacts
  static Future<ApiResponse<Map<String, dynamic>>> signup({
    required String name,
    required String phone,
    String? email,
    String? age,
    String? occupation,
    List<Map<String, String>>? emergencyContacts,
  }) async {
    final Map<String, dynamic> data = {'name': name, 'phone': phone};

    if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }
    if (age != null && age.isNotEmpty) {
      final parsedAge = int.tryParse(age);
      if (parsedAge != null) {
        data['age'] = parsedAge;
      }
    }
    if (occupation != null && occupation.isNotEmpty) {
      data['occupation'] = occupation;
    }
    if (emergencyContacts != null && emergencyContacts.isNotEmpty) {
      data['emergencyContacts'] = emergencyContacts
          .where(
            (contact) =>
                contact['name']?.isNotEmpty == true &&
                contact['phone']?.isNotEmpty == true,
          )
          .map(
            (contact) => {'name': contact['name'], 'phone': contact['phone']},
          )
          .toList();
    }

    return await ApiService.post('/auth/signup', data);
  }

  /// Send OTP to phone number
  /// Includes deviceId to ensure OTP only goes to requesting device
  /// This prevents OTP being sent to multiple devices on shared phone numbers
  static Future<ApiResponse<Map<String, dynamic>>> sendOTP(String phone) async {
    try {
      // Get device ID to send with request
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown';

      try {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? 'unknown';
        }
      } catch (e) {
        print('⚠️  Could not get device ID: $e');
      }

      return await ApiService.post('/auth/send-otp', {
        'phone': phone,
        'deviceId':
            deviceId, // Send device ID to prevent multi-device OTP sends
      });
    } catch (e) {
      print('❌ Error in sendOTP: $e');
      rethrow;
    }
  }

  /// Verify OTP and login
  static Future<ApiResponse<Map<String, dynamic>>> verifyOTP({
    required String phone,
    required String otp,
  }) async {
    // Get device info
    final deviceInfo = DeviceInfoPlugin();
    String deviceId;
    String deviceType = 'SMARTPHONE';
    Map<String, dynamic> metadata = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceType = 'SMARTPHONE';
        metadata = {
          'os': 'Android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        deviceType = 'SMARTPHONE';
        metadata = {'os': 'iOS', 'model': iosInfo.model};
      } else {
        deviceId = 'unknown';
      }
    } catch (e) {
      deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }

    final response =
        await ApiService.post<Map<String, dynamic>>('/auth/verify-otp', {
          'phone': phone,
          'otp': otp,
          'deviceId': deviceId,
          'deviceType': deviceType,
          'metadata': metadata,
        });

    // ignore: avoid_print
    print(
      '🟡 [Auth] verifyOTP response.success=${response.success} message=${response.message} data=${response.data}',
    );

    if (response.success && response.data != null) {
      final data = response.data!;

      // Save token and user data
      if (data['token'] != null) {
        // ignore: avoid_print
        print('🔐 [Auth] Token found in response, saving...');
        await StorageService.saveToken(data['token'] as String);
        // ignore: avoid_print
        print('🔐 [Auth] Token saved');
      }

      if (data['user'] != null && data['device'] != null) {
        final user = data['user'] as Map<String, dynamic>;
        final device = data['device'] as Map<String, dynamic>;

        await StorageService.saveUserData(
          userId: user['id']?.toString() ?? '',
          deviceId: device['deviceId']?.toString() ?? deviceId,
          phone: user['phone']?.toString() ?? phone,
          name: user['name']?.toString(),
        );
      }
    }

    return response;
  }

  /// Logout
  static Future<void> logout() async {
    await StorageService.clearAll();
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    return await StorageService.isLoggedIn();
  }
}
