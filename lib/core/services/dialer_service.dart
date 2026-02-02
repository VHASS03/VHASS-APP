import 'package:flutter/services.dart';

class DialerService {
  static const platform = MethodChannel('com.example.my_app/dialer');

  /// Initiate a call using native Android intent
  static Future<bool> makeCall(String phoneNumber) async {
    try {
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanedNumber.isEmpty) {
        return false;
      }

      print('📞 Making call via native channel: $cleanedNumber');

      final result = await platform.invokeMethod<bool>('makeCall', {
        'phoneNumber': cleanedNumber,
      });

      return result ?? false;
    } catch (e) {
      print('❌ Error making call: $e');
      return false;
    }
  }

  /// Initiate a dial (opens dialer with number pre-filled)
  static Future<bool> openDialer(String phoneNumber) async {
    try {
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanedNumber.isEmpty) {
        return false;
      }

      print('📞 Opening dialer via native channel: $cleanedNumber');

      final result = await platform.invokeMethod<bool>('openDialer', {
        'phoneNumber': cleanedNumber,
      });

      return result ?? false;
    } catch (e) {
      print('❌ Error opening dialer: $e');
      return false;
    }
  }
}
