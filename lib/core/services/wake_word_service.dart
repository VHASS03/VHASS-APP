import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'storage_service.dart';
import '../config/api_config.dart';

/// Battery-Efficient Wake Word Detection Service with STEALTH MODE
///
/// Uses ONLY Android's built-in APIs - NO third-party services!
///
/// Wake Word: "HELP ME OUT" (and variations)
///
/// 🥷 STEALTH MODE FEATURES:
/// When "help me out" is detected:
/// 1. Screen turns BLACK (looks like phone is off)
/// 2. Calls are made SILENTLY (attacker can't hear)
/// 3. Speakerphone enabled (contact can HEAR the situation)
/// 4. If call is cut, AUTO-REDIALS up to 3 times
/// 5. SMS sent with location SILENTLY
///
/// This prevents kidnappers from:
/// - Seeing the call on screen
/// - Knowing SOS was triggered
/// - Cutting the call before contact answers
///
/// Battery comparison:
/// - Continuous listening (old): ~15-20% per hour
/// - Smart wake word (new): ~5-8% per hour
class WakeWordService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.my_app/wake_word',
  );

  /// Start wake word detection service
  ///
  /// This service will:
  /// 1. Monitor audio levels (low power)
  /// 2. When voice detected → listen for "help me out"
  /// 3. If detected → IMMEDIATELY trigger SOS
  /// 4. Return to monitoring after SOS completes
  static Future<bool> startService() async {
    try {
      debugPrint('🚀 Starting wake word detection service...');
      debugPrint('   Using Android built-in APIs only (no third-party)');

      // Get user data for the service
      final authToken = await StorageService.getToken();
      final userId = await StorageService.getUserId();
      final serverUrl = ApiConfig.baseUrl.replaceFirst('/api', '');

      if (authToken == null || userId == null) {
        debugPrint('❌ Cannot start service: Missing auth data');
        return false;
      }

      final result = await _channel.invokeMethod('startWakeWordService', {
        'authToken': authToken,
        'userId': userId,
        'serverUrl': serverUrl,
      });

      debugPrint('✅ Wake word service started: $result');
      debugPrint('   Say "HELP ME OUT" to trigger emergency SOS');

      // Save service state
      await _saveServiceState(true);

      return result as bool;
    } catch (e) {
      debugPrint('❌ Failed to start wake word service: $e');
      return false;
    }
  }

  /// Stop wake word detection service
  static Future<bool> stopService() async {
    try {
      debugPrint('🛑 Stopping wake word detection service...');

      final result = await _channel.invokeMethod('stopWakeWordService');

      debugPrint('✅ Wake word service stopped: $result');

      // Save service state
      await _saveServiceState(false);

      return result as bool;
    } catch (e) {
      debugPrint('❌ Failed to stop wake word service: $e');
      return false;
    }
  }

  /// Check if wake word service is currently running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isWakeWordServiceRunning');
      return result as bool;
    } catch (e) {
      debugPrint('❌ Failed to check wake word service status: $e');
      return false;
    }
  }

  /// Check if service should be running (user preference)
  static Future<bool> isServiceEnabled() async {
    return await StorageService.getBool('wake_word_service_enabled') ?? false;
  }

  /// Save service state to storage
  static Future<void> _saveServiceState(bool enabled) async {
    await StorageService.setBool('wake_word_service_enabled', enabled);
  }

  /// Auto-start service if it was previously enabled
  static Future<void> autoStartIfEnabled() async {
    final wasEnabled = await isServiceEnabled();

    if (wasEnabled) {
      debugPrint('🔄 Auto-starting wake word service (was previously enabled)');
      await startService();
    }
  }

  /// Request all permissions needed for stealth mode
  /// Call this before starting the service
  static Future<bool> requestStealthPermissions() async {
    debugPrint('📱 Requesting stealth mode permissions...');

    // Request microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('❌ Microphone permission denied');
      return false;
    }

    // Request phone permission (for calls)
    final phoneStatus = await Permission.phone.request();
    if (!phoneStatus.isGranted) {
      debugPrint('❌ Phone permission denied');
      return false;
    }

    // Request SMS permission
    final smsStatus = await Permission.sms.request();
    if (!smsStatus.isGranted) {
      debugPrint('❌ SMS permission denied');
      return false;
    }

    // Request location permission (for SOS location)
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      debugPrint(
        '⚠️ Location permission denied (SOS will work without location)',
      );
    }

    // Request "Display over other apps" permission (CRITICAL for hiding dialer!)
    final overlayStatus = await Permission.systemAlertWindow.request();
    if (!overlayStatus.isGranted) {
      debugPrint(
        '⚠️ Overlay permission denied - dialer may be visible during SOS',
      );
      debugPrint('   Go to Settings > Apps > VHASS > Display over other apps');
    } else {
      debugPrint('✅ Overlay permission granted - dialer will be hidden!');
    }

    debugPrint('✅ Stealth mode permissions granted');
    return true;
  }

  /// Check if all stealth permissions are granted
  static Future<bool> hasStealthPermissions() async {
    final mic = await Permission.microphone.isGranted;
    final phone = await Permission.phone.isGranted;
    final sms = await Permission.sms.isGranted;

    return mic && phone && sms;
  }
}
