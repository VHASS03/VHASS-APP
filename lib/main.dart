import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/services/notification_service.dart';
import 'core/services/sos_alert_service.dart';
import 'core/services/storage_service.dart';
import 'core/config/api_config.dart';
import 'theme_controller.dart';
import 'theme/app_theme.dart';
import 'screens/splash.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications for SOS alerts
  await NotificationService.initialize();

  // Initialize SOS alert service to listen for incoming alerts from contacts
  _initializeSOSAlertService();

  // Request permissions on app startup
  await _requestPermissions();

  runApp(const MyApp());
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

Future<void> _requestPermissions() async {
  await [
    Permission.phone,
    Permission.location,
    Permission.microphone,
    Permission.contacts,
    Permission.notification, // Request notification permission for Android 13+
  ].request();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: appTheme(Brightness.light),
          darkTheme: appTheme(Brightness.dark),
          home: const SplashScreen(),
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
