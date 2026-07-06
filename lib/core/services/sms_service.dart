import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// SMS Service - Send actual SMS from device
/// No third-party APIs needed - uses Android native SMS
class SMSService {
  static const platform = MethodChannel('com.example.my_app/sms');

  /// Request SMS permission at runtime (Android)
  static Future<bool> requestSMSPermission() async {
    try {
      final status = await Permission.sms.status;

      if (status.isGranted) {
        print('✅ SMS permission already granted');
        return true;
      }

      if (status.isDenied) {
        print('📱 Requesting SMS permission...');
        final result = await Permission.sms.request();

        if (result.isGranted) {
          print('✅ SMS permission granted by user');
          return true;
        } else if (result.isPermanentlyDenied) {
          print('❌ SMS permission permanently denied');
          print('   Please enable SMS permission in app settings');
          await openAppSettings();
          return false;
        } else {
          print('❌ SMS permission denied by user');
          return false;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error requesting SMS permission: $e');
      return false;
    }
  }

  /// Send OTP via native Android SMS
  /// Works on real devices (not emulator)
  /// Automatically requests permission if needed
  static Future<bool> sendOTP(String phoneNumber, String otp) async {
    try {
      // Request permission first
      final hasPermission = await requestSMSPermission();
      if (!hasPermission) {
        print('❌ Cannot send SMS: Permission not granted');
        return false;
      }

      print('📱 Attempting to send SMS to: $phoneNumber');
      print('   OTP: $otp');

      final result = await platform.invokeMethod('sendSMS', {
        'phoneNumber': phoneNumber,
        'message':
            'Your VHASS verification code is: $otp. Valid for 10 minutes.',
      });

      if (result == true) {
        print('✅ SMS sent successfully via native Android SMS');
        return true;
      } else {
        print('❌ SMS sending failed');
        return false;
      }
    } on PlatformException catch (e) {
      print('❌ SMS Platform error: ${e.message}');
      print('   Code: ${e.code}');
      print('   This likely means:');
      print('   - You are using Android Emulator (doesn\'t have real SMS)');
      print('   - Or SMS permissions not granted on device');
      return false;
    } catch (e) {
      print('❌ Unexpected SMS error: $e');
      return false;
    }
  }

  /// Send SMS with custom message
  static Future<bool> sendCustomSMS(String phoneNumber, String message) async {
    try {
      final result = await platform.invokeMethod('sendSMS', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return result == true;
    } catch (e) {
      print('❌ Failed to send custom SMS: $e');
      return false;
    }
  }
}
