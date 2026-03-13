import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../config/api_config.dart';

/// Service to manage background voice monitoring
/// Starts Android foreground service that listens even when app is closed
class BackgroundVoiceService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.my_app/voice_service',
  );

  /// Start background voice monitoring service
  /// This service will continue running even when app is closed
  static Future<bool> startBackgroundService() async {
    try {
      debugPrint('🚀 Starting background voice monitoring service...');

      // Get user data for the service
      final authToken = await StorageService.getToken();
      final userId = await StorageService.getUserId();
      final serverUrl = ApiConfig.baseUrl.replaceFirst('/api', '');

      if (authToken == null || userId == null) {
        debugPrint('❌ Cannot start service: Missing auth data');
        return false;
      }

      final result = await _channel.invokeMethod('startVoiceService', {
        'authToken': authToken,
        'userId': userId,
        'serverUrl': serverUrl,
      });

      debugPrint('✅ Background voice service started: $result');

      // Save service state
      await _saveServiceState(true);

      return result as bool;
    } catch (e) {
      debugPrint('❌ Failed to start background voice service: $e');
      return false;
    }
  }

  /// Stop background voice monitoring service
  static Future<bool> stopBackgroundService() async {
    try {
      debugPrint('🛑 Stopping background voice monitoring service...');

      final result = await _channel.invokeMethod('stopVoiceService');

      debugPrint('✅ Background voice service stopped: $result');

      // Save service state
      await _saveServiceState(false);

      return result as bool;
    } catch (e) {
      debugPrint('❌ Failed to stop background voice service: $e');
      return false;
    }
  }

  /// Check if service should be running
  static Future<bool> isServiceEnabled() async {
    return await StorageService.getBool('voice_service_enabled') ?? false;
  }

  /// Save service state to storage
  static Future<void> _saveServiceState(bool enabled) async {
    await StorageService.setBool('voice_service_enabled', enabled);
  }

  /// Auto-start service if it was previously enabled
  static Future<void> autoStartIfEnabled() async {
    final wasEnabled = await isServiceEnabled();

    if (wasEnabled) {
      debugPrint(
        '🔄 Auto-starting background voice service (was previously enabled)',
      );
      await startBackgroundService();
    }
  }
}
