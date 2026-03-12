import 'package:flutter/services.dart';

class DialerService {
  static const platform = MethodChannel('com.example.my_app/dialer');

  /// Initiate a call using native Android intent
  static Future<bool> makeCall(String phoneNumber) async {
    try {
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

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
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

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
  
  /// Make a conference call to multiple numbers
  /// Uses GSM conference call feature
  static Future<bool> makeConferenceCall(List<String> phoneNumbers) async {
    try {
      if (phoneNumbers.isEmpty) {
        print('❌ No phone numbers provided for conference call');
        return false;
      }
      
      final cleanedNumbers = phoneNumbers
          .map((n) => n.replaceAll(RegExp(r'[^0-9+]'), ''))
          .where((n) => n.isNotEmpty)
          .toList();
      
      if (cleanedNumbers.isEmpty) {
        return false;
      }
      
      print('📞 Making conference call to ${cleanedNumbers.length} numbers');
      
      final result = await platform.invokeMethod<bool>('makeConferenceCall', {
        'phoneNumbers': cleanedNumbers,
      });

      return result ?? false;
    } catch (e) {
      print('❌ Error making conference call: $e');
      // Fallback to regular call if conference not supported
      if (phoneNumbers.isNotEmpty) {
        return makeCall(phoneNumbers.first);
      }
      return false;
    }
  }
  
  /// Make sequential calls to multiple numbers
  /// Calls each number one after another
  static Future<void> makeSequentialCalls(
    List<String> phoneNumbers, {
    Duration delayBetweenCalls = const Duration(seconds: 3),
  }) async {
    for (int i = 0; i < phoneNumbers.length; i++) {
      final number = phoneNumbers[i];
      print('📞 Sequential call ${i + 1}/${phoneNumbers.length}: $number');
      
      await makeCall(number);
      
      // Wait between calls (except for last one)
      if (i < phoneNumbers.length - 1) {
        await Future.delayed(delayBetweenCalls);
      }
    }
  }
}
