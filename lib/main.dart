import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/services/notification_service.dart';
import 'core/services/sos_alert_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/period_notification_service.dart';
import 'core/services/contacts_service.dart';
import 'core/services/health_reminder_service.dart';
import 'core/config/api_config.dart';
import 'core/navigation/app_navigator.dart';
import 'theme_controller.dart';
import 'theme/app_theme.dart';
import 'screens/splash.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isLoggedIn = false;
  try {
    isLoggedIn = await StorageService.isLoggedIn();
  } catch (e) {
    print('⚠️ Failed to read login status on startup: $e');
  }

  // Launch UI immediately so app boots without hanging on mobile
  runApp(MyApp(isLoggedIn: isLoggedIn));

  // Run background service initializations asynchronously
  _initializeServicesAsync();
}

/// Initialize background services & permissions after UI mounts to ensure fast mobile boot
Future<void> _initializeServicesAsync() async {
  try {
    await NotificationService.initialize();
  } catch (e) {
    print('⚠️ Failed to initialize NotificationService: $e');
  }

  try {
    await PeriodNotificationService.initialize();
  } catch (e) {
    print('⚠️ Failed to initialize PeriodNotificationService: $e');
  }

  try {
    await HealthReminderService.initialize();
  } catch (e) {
    print('⚠️ Failed to initialize HealthReminderService: $e');
  }

  _initializeSOSAlertService();
  _prefetchEmergencyContacts();
  _checkPeriodNotifications();
  _startHealthReminders();

  try {
    await _requestPermissions();
  } catch (e) {
    print('⚠️ Failed to request startup permissions: $e');
  }
}

/// Initialize SOS alert service to receive alerts from contacts
Future<void> _initializeSOSAlertService() async {
  try {
    final token = await StorageService.getToken();
    if (token != null) {
      await SOSAlertService.initializeSOSAlerts(ApiConfig.socketUrl, token);
      print('✅ SOS alert service initialized');
    }
  } catch (e) {
    print('⚠️ Failed to initialize SOS alert service: $e');
  }
}

/// Check if user is on period and send supportive notifications
Future<void> _checkPeriodNotifications() async {
  try {
    final token = await StorageService.getToken();
    if (token != null) {
      // Check and send period notifications if applicable
      await PeriodNotificationService.checkAndNotify();
      print('🌸 Period notification check completed');
    }
  } catch (e) {
    print('⚠️ Failed to check period notifications: $e');
  }
}

/// Start health reminders (water, posture, eye breaks, wellness tips)
Future<void> _startHealthReminders() async {
  try {
    final token = await StorageService.getToken();
    if (token != null) {
      // Start periodic health reminders
      await HealthReminderService.instance.startReminders();
      print('🏥 Health reminders started');
    }
  } catch (e) {
    print('⚠️ Failed to start health reminders: $e');
  }
}

Future<void> _requestPermissions() async {
  await [
    Permission.phone,
    Permission.location,
    Permission.microphone,
    Permission.contacts,
    Permission.notification, // Request notification permission for Android 13+
    Permission.bluetoothScan, // Bluetooth permissions for SOS device
    Permission.bluetoothConnect,
  ].request();
}

/// Preload emergency contacts:
/// - Runs as soon as app starts (after token is available)
/// - Uses daily staleness check so data is refreshed once per day
/// - Keeps a warm cache so SOS doesn't wait for network before calling
Future<void> _prefetchEmergencyContacts() async {
  try {
    final token = await StorageService.getToken();
    if (token == null) {
      print('ℹ️ No token yet, skipping contacts prefetch');
      return;
    }

    // Fire-and-forget: don't block app startup
    // This runs on an async "thread" while splash/home load.
    // ignore: unawaited_futures
    ContactsService.preloadContactsIfStale();
    print('📥 Contacts prefetch started in background');
  } catch (e) {
    print('⚠️ Failed to prefetch contacts: $e');
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Syava AI',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: appTheme(Brightness.light),
          darkTheme: appTheme(Brightness.dark),
          home: isLoggedIn ? const HomeScreen() : const SplashScreen(),
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
          },
        );
      },
    );
  }
}
