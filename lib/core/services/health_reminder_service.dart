import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'storage_service.dart';

/// Health Reminder Service
/// Sends periodic notifications for water intake, posture, eye breaks, and wellness tips
/// Helps users maintain healthy habits throughout the day
class HealthReminderService {
  static HealthReminderService? _instance;
  static HealthReminderService get instance => _instance ??= HealthReminderService._();
  
  HealthReminderService._();
  
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  Timer? _reminderTimer;
  bool _isRunning = false;
  
  // Settings keys
  static const String _keyRemindersEnabled = 'health_reminders_enabled';
  static const String _keyReminderInterval = 'health_reminder_interval';
  static const String _keyWaterReminders = 'water_reminders_enabled';
  static const String _keyPostureReminders = 'posture_reminders_enabled';
  static const String _keyEyeBreakReminders = 'eye_break_reminders_enabled';
  static const String _keyStretchReminders = 'stretch_reminders_enabled';
  static const String _keyWellnessTips = 'wellness_tips_enabled';
  
  // Default interval: 30 minutes
  static const int _defaultIntervalMinutes = 30;
  
  /// Water reminder messages
  static const List<Map<String, String>> _waterReminders = [
    {
      'title': '💧 Hydration Time!',
      'body': 'Your body needs water! Take a moment to drink a glass of water. Staying hydrated improves focus and energy.',
    },
    {
      'title': '🥤 Water Break',
      'body': 'Have you had water recently? Drinking water helps flush toxins and keeps your skin glowing!',
    },
    {
      'title': '💦 Drink Up!',
      'body': 'Time for a hydration check! Aim for 8 glasses a day. Your body will thank you!',
    },
    {
      'title': '🌊 Stay Hydrated',
      'body': 'Water is life! Take a sip now. Dehydration can cause headaches and fatigue.',
    },
    {
      'title': '💧 Water Reminder',
      'body': 'Keep that water bottle handy! Regular hydration boosts your metabolism and brain function.',
    },
  ];
  
  /// Posture reminder messages
  static const List<Map<String, String>> _postureReminders = [
    {
      'title': '🧘 Posture Check',
      'body': 'Sit up straight! Good posture reduces back pain and improves breathing. Shoulders back, chin up!',
    },
    {
      'title': '🪑 Fix Your Posture',
      'body': 'Are you slouching? Straighten your spine and relax your shoulders. Your back will thank you!',
    },
    {
      'title': '🏋️ Stand Tall',
      'body': 'Quick posture reminder! Align your ears over your shoulders. Feel the difference!',
    },
  ];
  
  /// Eye break reminder messages
  static const List<Map<String, String>> _eyeBreakReminders = [
    {
      'title': '👀 Eye Break Time',
      'body': 'Follow the 20-20-20 rule: Look at something 20 feet away for 20 seconds. Your eyes need rest!',
    },
    {
      'title': '👁️ Rest Your Eyes',
      'body': 'Screen time strains your eyes. Close them for 20 seconds or look at something far away.',
    },
    {
      'title': '🌳 Look Away',
      'body': 'Give your eyes a break! Look out the window or at a distant object. Blink slowly a few times.',
    },
  ];
  
  /// Stretch reminder messages
  static const List<Map<String, String>> _stretchReminders = [
    {
      'title': '🤸 Stretch Break!',
      'body': 'Time to move! Stand up and stretch your arms, neck, and back. Even 30 seconds helps!',
    },
    {
      'title': '💪 Move Your Body',
      'body': 'Sitting too long? Stand up, stretch your legs, and take a short walk. Movement is medicine!',
    },
    {
      'title': '🧘‍♀️ Quick Stretch',
      'body': 'Roll your shoulders, stretch your neck side to side, and reach for the sky. Feel better instantly!',
    },
  ];
  
  /// General wellness tips
  static const List<Map<String, String>> _wellnessTips = [
    {
      'title': '🌟 Wellness Tip',
      'body': 'Take 3 deep breaths right now. Inhale for 4 counts, hold for 4, exhale for 4. Instant calm!',
    },
    {
      'title': '😊 Mood Booster',
      'body': 'Smile! Even a fake smile can trick your brain into feeling happier. Try it now!',
    },
    {
      'title': '🧠 Mental Break',
      'body': 'Close your eyes and think of something you\'re grateful for. Gratitude improves mental health!',
    },
    {
      'title': '🌿 Mindfulness Moment',
      'body': 'Take 30 seconds to notice your surroundings. What do you see, hear, and feel? Be present.',
    },
    {
      'title': '☀️ Get Some Light',
      'body': 'Natural light boosts mood and Vitamin D! Step outside or sit by a window for a few minutes.',
    },
    {
      'title': '🍎 Healthy Snack Time',
      'body': 'Feeling peckish? Choose a healthy snack like fruits, nuts, or yogurt. Fuel your body right!',
    },
    {
      'title': '😤 Breathing Exercise',
      'body': 'Stressed? Try box breathing: Inhale 4 sec, hold 4 sec, exhale 4 sec, hold 4 sec. Repeat 3 times.',
    },
    {
      'title': '🚶 Walk Break',
      'body': 'A short 5-minute walk can boost your energy and creativity. Get moving!',
    },
  ];
  
  /// Initialize the health reminder notification channel
  static Future<void> initialize() async {
    print('🏥 [HealthReminder] Initializing Health Reminder Service');
    
    if (Platform.isAndroid) {
      const AndroidNotificationChannel healthChannel = AndroidNotificationChannel(
        'health_reminders',
        'Health Reminders',
        description: 'Periodic health and wellness reminders',
        importance: Importance.defaultImportance,
        enableVibration: true,
        playSound: true,
        ledColor: Color.fromARGB(255, 76, 175, 80),
      );
      
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(healthChannel);
      
      print('✅ [HealthReminder] Notification channel created');
    }
  }
  
  /// Start periodic health reminders
  Future<void> startReminders() async {
    if (_isRunning) {
      print('⚠️ [HealthReminder] Already running');
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyRemindersEnabled) ?? true;
    
    if (!enabled) {
      print('⚠️ [HealthReminder] Reminders disabled in settings');
      return;
    }
    
    final intervalMinutes = prefs.getInt(_keyReminderInterval) ?? _defaultIntervalMinutes;
    
    print('🏥 [HealthReminder] Starting reminders every $intervalMinutes minutes');
    
    _isRunning = true;
    
    // Send first reminder after half the interval
    Future.delayed(Duration(minutes: intervalMinutes ~/ 2), () {
      if (_isRunning) _sendRandomReminder();
    });
    
    // Set up periodic timer
    _reminderTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (timer) => _sendRandomReminder(),
    );
    
    print('✅ [HealthReminder] Reminders started');
  }
  
  /// Stop periodic reminders
  void stopReminders() {
    print('🛑 [HealthReminder] Stopping reminders');
    _reminderTimer?.cancel();
    _reminderTimer = null;
    _isRunning = false;
  }
  
  /// Send a random health reminder based on enabled categories
  Future<void> _sendRandomReminder() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get enabled categories
    final waterEnabled = prefs.getBool(_keyWaterReminders) ?? true;
    final postureEnabled = prefs.getBool(_keyPostureReminders) ?? true;
    final eyeBreakEnabled = prefs.getBool(_keyEyeBreakReminders) ?? true;
    final stretchEnabled = prefs.getBool(_keyStretchReminders) ?? true;
    final wellnessEnabled = prefs.getBool(_keyWellnessTips) ?? true;
    
    // Build list of available reminders
    final List<Map<String, String>> availableReminders = [];
    
    if (waterEnabled) availableReminders.addAll(_waterReminders);
    if (postureEnabled) availableReminders.addAll(_postureReminders);
    if (eyeBreakEnabled) availableReminders.addAll(_eyeBreakReminders);
    if (stretchEnabled) availableReminders.addAll(_stretchReminders);
    if (wellnessEnabled) availableReminders.addAll(_wellnessTips);
    
    if (availableReminders.isEmpty) {
      print('⚠️ [HealthReminder] No reminder categories enabled');
      return;
    }
    
    // Pick random reminder
    final random = Random();
    final reminder = availableReminders[random.nextInt(availableReminders.length)];
    
    await _showNotification(
      title: reminder['title']!,
      body: reminder['body']!,
    );
  }
  
  /// Show notification
  static Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    if (!await StorageService.areNotificationsEnabled()) {
      print('🏥 [HealthReminder] Notifications are disabled in settings. Skipping.');
      return;
    }

    try {
      if (Platform.isAndroid) {
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'health_reminders',
          'Health Reminders',
          channelDescription: 'Periodic health and wellness reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(''),
          color: Color.fromARGB(255, 76, 175, 80),
        );
        
        final NotificationDetails details = NotificationDetails(
          android: androidDetails,
        );
        
        await _notificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          details,
          payload: 'health_reminder',
        );
        
        print('🏥 [HealthReminder] Sent: $title');
      } else if (Platform.isIOS) {
        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
        );
        
        final NotificationDetails details = NotificationDetails(
          iOS: iosDetails,
        );
        
        await _notificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          details,
          payload: 'health_reminder',
        );
        
        print('🏥 [HealthReminder] Sent (iOS): $title');
      }
    } catch (e) {
      print('❌ [HealthReminder] Error sending notification: $e');
    }
  }
  
  /// Send specific reminder type
  static Future<void> sendWaterReminder() async {
    final random = Random();
    final reminder = _waterReminders[random.nextInt(_waterReminders.length)];
    await _showNotification(title: reminder['title']!, body: reminder['body']!);
  }
  
  static Future<void> sendPostureReminder() async {
    final random = Random();
    final reminder = _postureReminders[random.nextInt(_postureReminders.length)];
    await _showNotification(title: reminder['title']!, body: reminder['body']!);
  }
  
  static Future<void> sendEyeBreakReminder() async {
    final random = Random();
    final reminder = _eyeBreakReminders[random.nextInt(_eyeBreakReminders.length)];
    await _showNotification(title: reminder['title']!, body: reminder['body']!);
  }
  
  static Future<void> sendStretchReminder() async {
    final random = Random();
    final reminder = _stretchReminders[random.nextInt(_stretchReminders.length)];
    await _showNotification(title: reminder['title']!, body: reminder['body']!);
  }
  
  static Future<void> sendWellnessTip() async {
    final random = Random();
    final tip = _wellnessTips[random.nextInt(_wellnessTips.length)];
    await _showNotification(title: tip['title']!, body: tip['body']!);
  }
  
  // ============ Settings Management ============
  
  /// Enable/disable all reminders
  static Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemindersEnabled, enabled);
    
    if (enabled) {
      instance.startReminders();
    } else {
      instance.stopReminders();
    }
  }
  
  /// Set reminder interval in minutes
  static Future<void> setReminderInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderInterval, minutes);
    
    // Restart with new interval
    if (instance._isRunning) {
      instance.stopReminders();
      instance.startReminders();
    }
  }
  
  /// Enable/disable water reminders
  static Future<void> setWaterRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWaterReminders, enabled);
  }
  
  /// Enable/disable posture reminders
  static Future<void> setPostureRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPostureReminders, enabled);
  }
  
  /// Enable/disable eye break reminders
  static Future<void> setEyeBreakRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEyeBreakReminders, enabled);
  }
  
  /// Enable/disable stretch reminders
  static Future<void> setStretchRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStretchReminders, enabled);
  }
  
  /// Enable/disable wellness tips
  static Future<void> setWellnessTipsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWellnessTips, enabled);
  }
  
  /// Get current settings
  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_keyRemindersEnabled) ?? true,
      'intervalMinutes': prefs.getInt(_keyReminderInterval) ?? _defaultIntervalMinutes,
      'waterReminders': prefs.getBool(_keyWaterReminders) ?? true,
      'postureReminders': prefs.getBool(_keyPostureReminders) ?? true,
      'eyeBreakReminders': prefs.getBool(_keyEyeBreakReminders) ?? true,
      'stretchReminders': prefs.getBool(_keyStretchReminders) ?? true,
      'wellnessTips': prefs.getBool(_keyWellnessTips) ?? true,
    };
  }
  
  /// Check if reminders are running
  bool get isRunning => _isRunning;
}

