import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'wellness_service.dart';
import 'storage_service.dart';

/// Period Notification Service
/// Provides consoling messages, advice, and self-care tips during menstrual periods
/// Sends supportive notifications to help users feel cared for
class PeriodNotificationService {
  static final PeriodNotificationService _instance =
      PeriodNotificationService._internal();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory PeriodNotificationService() => _instance;
  PeriodNotificationService._internal();

  // Consoling messages for period days
  static const List<Map<String, String>> _periodConsolingMessages = [
    {
      'title': '💝 You\'re Amazing!',
      'body':
          'Your body is doing incredible work right now. Take it easy and be kind to yourself today. You deserve all the rest and care. 💗',
    },
    {
      'title': '🌸 Self-Care Reminder',
      'body':
          'This is your gentle reminder to drink warm water, have some comfort food, and rest when you need to. Your well-being matters! 🫂',
    },
    {
      'title': '✨ Strength & Grace',
      'body':
          'You handle so much with such grace. It\'s okay to slow down. Take breaks, stretch gently, and give yourself a warm hug. 💕',
    },
    {
      'title': '🌷 You\'re Doing Great',
      'body':
          'Feeling tired or emotional is completely normal. Honor your body\'s needs today. You\'re stronger than you know! 🌟',
    },
    {
      'title': '💫 Gentle Day Ahead',
      'body':
          'Today, prioritize YOU. Light exercise, warm beverages, and cozy comfort can help. You deserve to feel good. 🤗',
    },
    {
      'title': '🩷 Sending Warmth',
      'body':
          'Just a reminder that you\'re not alone. Many feel the same way. Rest, relax, and know this phase will pass. 💝',
    },
    {
      'title': '🌺 Be Gentle With Yourself',
      'body':
          'Your body is working hard. Treat yourself with extra kindness today - a warm bath, your favorite show, or just rest. 🛁',
    },
    {
      'title': '💖 You Matter',
      'body':
          'It\'s okay if today feels harder. Take one moment at a time. You\'re capable and wonderful, even on tough days! 🌈',
    },
  ];

  // Health tips and advice during periods
  static const List<Map<String, String>> _periodHealthTips = [
    {
      'title': '💧 Hydration Tip',
      'body':
          'Staying hydrated helps reduce bloating and cramps. Try warm water with lemon or herbal teas like ginger or chamomile. 🍵',
    },
    {
      'title': '🍫 Nutrition Advice',
      'body':
          'Craving chocolate? Dark chocolate can actually help! It\'s rich in magnesium which may ease cramps. Enjoy in moderation! 🍫',
    },
    {
      'title': '🧘 Gentle Movement',
      'body':
          'Light yoga or a gentle walk can help relieve period pain. Try child\'s pose or cat-cow stretches for comfort. 🧘‍♀️',
    },
    {
      'title': '🌡️ Heat Therapy',
      'body':
          'A hot water bottle or heating pad on your lower abdomen can work wonders for cramps. Warmth relaxes muscles! 🔥',
    },
    {
      'title': '🥗 Iron-Rich Foods',
      'body':
          'You lose iron during your period. Eat spinach, lentils, or red meat to replenish. Pair with vitamin C for better absorption! 🥬',
    },
    {
      'title': '😴 Rest Is Medicine',
      'body':
          'Your body needs extra rest during this time. Don\'t feel guilty about taking naps or going to bed early. Sleep heals! 🌙',
    },
    {
      'title': '🚫 What to Avoid',
      'body':
          'Try to limit caffeine, salt, and alcohol during your period. They can worsen bloating, cramps, and mood swings. 💪',
    },
    {
      'title': '🌿 Natural Remedies',
      'body':
          'Ginger tea can help reduce nausea and pain. Cinnamon may help regulate your cycle. Nature has many helpers! 🌿',
    },
    {
      'title': '💊 Pain Management',
      'body':
          'Over-the-counter pain relievers work best when taken at the first sign of cramps. Consult your doctor for persistent pain. 💊',
    },
    {
      'title': '🎵 Mood Boosters',
      'body':
          'Feeling low? Listen to your favorite music, watch something funny, or call a friend. Small joys make big differences! 🎶',
    },
  ];

  /// Initialize the period notification channel
  static Future<void> initialize() async {
    print('🌸 Initializing Period Notification Service');

    if (Platform.isAndroid) {
      const AndroidNotificationChannel periodChannel =
          AndroidNotificationChannel(
        'period_support',
        'Period Support & Wellness',
        description: 'Consoling messages and health tips during your period',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        ledColor: Color.fromARGB(255, 233, 30, 99),
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(periodChannel);

      print('✅ Period notification channel created');
    }
  }

  /// Check if user is on period and send appropriate notification
  static Future<void> checkAndNotify() async {
    try {
      final userId = await StorageService.getUserId();
      if (userId == null || userId.isEmpty) {
        print('⚠️ No user ID found for period notifications');
        return;
      }

      final wellnessData = await WellnessService.loadUserWellnessData(userId);
      final lastPeriodDate = wellnessData['lastPeriodDate'] as DateTime;
      final periodLength = wellnessData['periodLength'] as int;

      final today = DateTime.now();
      final daysSinceLastPeriod = DateTime(today.year, today.month, today.day)
          .difference(DateTime(
              lastPeriodDate.year, lastPeriodDate.month, lastPeriodDate.day))
          .inDays;

      final isOnPeriod = daysSinceLastPeriod >= 0 && daysSinceLastPeriod < periodLength;

      if (isOnPeriod) {
        final currentPeriodDay = daysSinceLastPeriod + 1;
        await sendPeriodSupportNotification(currentPeriodDay, periodLength);
        print('🌸 User is on period day $currentPeriodDay - notification sent');
      } else {
        print('📅 User is not currently on period');
      }
    } catch (e) {
      print('❌ Error checking period status: $e');
    }
  }

  /// Send a supportive notification during period
  static Future<void> sendPeriodSupportNotification(
    int currentDay,
    int totalDays,
  ) async {
    final random = Random();

    // Alternate between consoling messages and health tips
    final bool showConsoling = random.nextBool();
    final messages =
        showConsoling ? _periodConsolingMessages : _periodHealthTips;
    final message = messages[random.nextInt(messages.length)];

    await _showNotification(
      title: message['title']!,
      body: message['body']!,
      subtitle: 'Day $currentDay of $totalDays',
    );
  }

  /// Send a specific consoling message
  static Future<void> sendConsolingMessage() async {
    final random = Random();
    final message =
        _periodConsolingMessages[random.nextInt(_periodConsolingMessages.length)];

    await _showNotification(
      title: message['title']!,
      body: message['body']!,
    );
  }

  /// Send a specific health tip
  static Future<void> sendHealthTip() async {
    final random = Random();
    final tip = _periodHealthTips[random.nextInt(_periodHealthTips.length)];

    await _showNotification(
      title: tip['title']!,
      body: tip['body']!,
    );
  }

  /// Send period start reminder
  static Future<void> sendPeriodStartReminder(DateTime expectedDate) async {
    final daysUntil =
        expectedDate.difference(DateTime.now()).inDays;

    if (daysUntil <= 3 && daysUntil > 0) {
      await _showNotification(
        title: '📅 Period Reminder',
        body:
            'Your period is expected in $daysUntil day${daysUntil > 1 ? 's' : ''}. Stock up on essentials and prepare for self-care! 💝',
      );
    } else if (daysUntil == 0) {
      await _showNotification(
        title: '🌸 Period Expected Today',
        body:
            'Your period may start today. Remember to be gentle with yourself and have your comfort items ready! 💗',
      );
    }
  }

  /// Internal method to show notification
  static Future<void> _showNotification({
    required String title,
    required String body,
    String? subtitle,
  }) async {
    if (!await StorageService.areNotificationsEnabled()) {
      print('🌸 [PeriodNotification] Notifications are disabled in settings. Skipping.');
      return;
    }

    try {
      if (Platform.isAndroid) {
        final AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          'period_support',
          'Period Support & Wellness',
          channelDescription:
              'Consoling messages and health tips during your period',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: subtitle ?? 'Wellness Support',
          ),
          color: const Color.fromARGB(255, 233, 30, 99),
          ledColor: const Color.fromARGB(255, 233, 30, 99),
          ledOnMs: 1000,
          ledOffMs: 500,
        );

        final NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
        );

        await _notificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          notificationDetails,
          payload: 'period_support',
        );

        print('🌸 Period support notification sent: $title');
      } else if (Platform.isIOS) {
        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        );

        final NotificationDetails notificationDetails = NotificationDetails(
          iOS: iosDetails,
        );

        await _notificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          notificationDetails,
          payload: 'period_support',
        );

        print('🌸 Period support notification sent (iOS): $title');
      }
    } catch (e) {
      print('❌ Error sending period notification: $e');
    }
  }

  /// Get a random consoling message (for display in app)
  static Map<String, String> getRandomConsolingMessage() {
    final random = Random();
    return _periodConsolingMessages[
        random.nextInt(_periodConsolingMessages.length)];
  }

  /// Get a random health tip (for display in app)
  static Map<String, String> getRandomHealthTip() {
    final random = Random();
    return _periodHealthTips[random.nextInt(_periodHealthTips.length)];
  }

  /// Get all consoling messages
  static List<Map<String, String>> getAllConsolingMessages() {
    return _periodConsolingMessages;
  }

  /// Get all health tips
  static List<Map<String, String>> getAllHealthTips() {
    return _periodHealthTips;
  }
}

