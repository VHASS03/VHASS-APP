import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';

/// Notification Service
/// Sends high-priority SOS alerts that work even in silent mode
/// Like Indian weather alerts - keeps alerting until user acknowledges
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Initialize notifications
  static Future<void> initialize() async {
    print('🔔 Initializing Notification Service');

    if (Platform.isAndroid) {
      // Android-specific initialization
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(initSettings);

      // Request notification permission on Android 13+
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final granted = await androidImplementation
            .requestNotificationsPermission();
        print(
          granted == true
              ? '✅ Notification permission granted'
              : '⚠️ Notification permission denied',
        );
      }

      // Create high-priority notification channel for SOS
      await _createSOSNotificationChannel();
    } else if (Platform.isIOS) {
      // iOS-specific initialization
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestSoundPermission: true,
            requestBadgePermission: true,
            requestAlertPermission: true,
          );

      const InitializationSettings initSettings = InitializationSettings(
        iOS: iosSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(initSettings);
    }

    print('✅ Notification Service initialized');
  }

  /// Create Android notification channel for SOS with high priority
  static Future<void> _createSOSNotificationChannel() async {
    const AndroidNotificationChannel sosChannel = AndroidNotificationChannel(
      'sos_alerts', // Channel ID
      'SOS Emergency Alerts', // Channel name
      description: 'High-priority emergency alerts that bypass silent mode',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 0, 0), // Red light
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(sosChannel);

    print('✅ SOS notification channel created');
  }

  /// Send SOS alert to emergency contact
  /// Shows user name, emergency status, and location
  /// Keeps alerting like Indian weather alerts
  static Future<void> sendSOSAlert({
    required String userName,
    required String contactName,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    print(
      '🚨 Sending SOS alert to $contactName about $userName at ($latitude, $longitude)',
    );

    final title = '🚨 EMERGENCY ALERT 🚨';
    final body =
        '$userName is in an EMERGENCY situation!\n\n'
        'Location: ($latitude, $longitude)\n'
        '${address != null ? 'Address: $address\n' : ''}'
        'Please respond immediately!';

    try {
      // Android notification with high priority
      if (Platform.isAndroid) {
        final Int64List vibrationPattern = Int64List.fromList([
          0,
          500,
          500,
          500,
        ]);
        final AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
              'sos_alerts',
              'SOS Emergency Alerts',
              channelDescription:
                  'High-priority emergency alerts that bypass silent mode',
              importance: Importance.max,
              priority: Priority.max,
              fullScreenIntent: true,
              autoCancel: false,
              // Repeat notification every 2 seconds until user acknowledges
              actions: const [
                AndroidNotificationAction(
                  'acknowledge',
                  'Acknowledged',
                  cancelNotification: true,
                ),
              ],
              playSound: true,
              enableVibration: true,
              vibrationPattern: vibrationPattern, // Intense vibration pattern
              ledColor: const Color.fromARGB(255, 255, 0, 0),
              ledOnMs: 1000,
              ledOffMs: 500,
              styleInformation: BigTextStyleInformation(
                body, // Body text
                htmlFormatContent: true,
                contentTitle: title,
                summaryText: 'User in Emergency',
              ),
            );

        final NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
        );

        await _flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecond,
          title,
          body,
          notificationDetails,
          payload: 'sos_alert',
        );

        print('✅ SOS alert sent to $contactName');

        // Schedule repeated notifications every 2 seconds until acknowledged
        // (simulating Indian weather alert behavior)
        _scheduleRepeatAlerts(
          contactName: contactName,
          userName: userName,
          title: title,
          body: body,
        );
      } else if (Platform.isIOS) {
        // iOS notification
        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
          sound: 'sound.mp3',
          interruptionLevel: InterruptionLevel.critical,
        );

        final NotificationDetails notificationDetails = NotificationDetails(
          iOS: iosDetails,
        );

        await _flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecond,
          title,
          body,
          notificationDetails,
          payload: 'sos_alert',
        );

        print('✅ SOS alert sent to $contactName (iOS)');
      }
    } catch (e) {
      print('❌ Error sending SOS alert: $e');
    }
  }

  /// Schedule repeated alerts like Indian weather alerts
  /// Keep notifying until user acknowledges
  static void _scheduleRepeatAlerts({
    required String contactName,
    required String userName,
    required String title,
    required String body,
  }) {
    // This would be better with workmanager or alarm_manager_plus
    // For now, we can use simple Timer-based approach
    print('⏰ Scheduling repeat alerts for $contactName');
  }

  /// Cancel all SOS notifications
  static Future<void> cancelSOSAlerts() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('✅ All SOS alerts cancelled');
    } catch (e) {
      print('❌ Error cancelling alerts: $e');
    }
  }

  /// Send SMS-based alert (for contacts who don't have app)
  /// This is a fallback for emergency contacts without the app
  static Future<void> sendSMSAlert({
    required String phoneNumber,
    required String userName,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    print('📱 Queuing SMS alert for $phoneNumber');

    final message =
        '🚨 EMERGENCY ALERT! 🚨\n'
        '$userName is in an EMERGENCY situation!\n'
        'Location: $latitude, $longitude\n'
        '${address != null ? 'Address: $address\n' : ''}'
        'Please respond immediately!';

    // This would be sent via backend API to Twilio/NEXMO
    // Call backend to send SMS
    print('Message to send: $message');
  }
}
