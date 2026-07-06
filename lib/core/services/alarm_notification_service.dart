import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'storage_service.dart';

/// Alarm Notification Service
///
/// Handles LOUD emergency notifications that:
/// 1. Play alarm sound even when phone is on SILENT
/// 2. Vibrate continuously
/// 3. Show full-screen alert
/// 4. Cannot be easily dismissed
///
/// Used when receiving SOS alerts from emergency contacts
class AlarmNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _channel = MethodChannel(
    'com.example.my_app/alarm',
  );

  static bool _isInitialized = false;

  /// Initialize the alarm notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // For critical alerts on iOS
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create high-priority notification channel for alarms
    await _createAlarmChannel();

    _isInitialized = true;
    debugPrint('✅ Alarm notification service initialized');
  }

  /// Create a high-priority notification channel for emergency alarms
  static Future<void> _createAlarmChannel() async {
    const channel = AndroidNotificationChannel(
      'emergency_alarm_channel',
      'Emergency Alarms',
      description: 'Critical emergency alerts that override silent mode',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show LOUD emergency alarm notification
  /// This will play sound even on silent mode!
  static Future<void> showEmergencyAlarm({
    required String title,
    required String body,
    String? mapsLink,
    String? sosId,
    String? senderName,
  }) async {
    if (!await StorageService.areNotificationsEnabled()) {
      debugPrint('🔕 Notifications are disabled in settings. Skipping emergency alarm.');
      return;
    }

    await initialize();

    debugPrint('🚨 SHOWING EMERGENCY ALARM: $title');

    final androidDetails = AndroidNotificationDetails(
      'emergency_alarm_channel',
      'Emergency Alarms',
      channelDescription: 'Critical emergency alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]), // Long vibration pattern
      enableLights: true,
      fullScreenIntent: true, // Shows as full-screen alert!
      ongoing: true, // Cannot be swiped away
      autoCancel: false,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: '🚨 EMERGENCY ALERT',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical, // Plays even on silent!
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title,
      body,
      details,
      payload: mapsLink ?? sosId,
    );

    // Also trigger native alarm sound for extra loudness
    try {
      await _channel.invokeMethod('playAlarmSound', {
        'duration': 30000, // 30 seconds
        'vibrate': true,
      });
    } catch (e) {
      debugPrint('Native alarm not available: $e');
    }
  }

  /// Show location update notification (less urgent but still important)
  static Future<void> showLocationUpdate({
    required String senderName,
    required String mapsLink,
    double? latitude,
    double? longitude,
  }) async {
    if (!await StorageService.areNotificationsEnabled()) {
      debugPrint('🔕 Notifications are disabled in settings. Skipping location update.');
      return;
    }

    await initialize();

    debugPrint('📍 Location update from $senderName: $mapsLink');

    const androidDetails = AndroidNotificationDetails(
      'emergency_alarm_channel',
      'Emergency Alarms',
      channelDescription: 'Location updates during emergency',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final locationText = latitude != null && longitude != null
        ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
        : 'View on map';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '📍 Location Update: $senderName',
      'New location: $locationText\nTap to view on map',
      details,
      payload: mapsLink,
    );
  }

  /// Stop the alarm sound and vibration
  static Future<void> stopAlarm() async {
    try {
      await _channel.invokeMethod('stopAlarmSound');
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
    await stopAlarm();
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('http')) {
      // Open maps link
      debugPrint('Opening maps link: $payload');
      // You can use url_launcher to open the link
    }
  }
}

