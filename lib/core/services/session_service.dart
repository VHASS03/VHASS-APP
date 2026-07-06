import 'package:flutter/material.dart';
import '../navigation/app_navigator.dart';
import '../../screens/auth/login_screen.dart';
import 'wake_word_service.dart';
import 'storage_service.dart';

/// Handles expired sessions and redirects users to login.
class SessionService {
  static bool _isHandlingSessionExpiry = false;

  static Future<void> handleExpired({bool showMessage = true}) async {
    if (_isHandlingSessionExpiry) return;
    _isHandlingSessionExpiry = true;

    try {
      // ignore: avoid_print
      print('🔒 Session expired — clearing auth and redirecting to login');

      try {
        await WakeWordService.stopService();
      } catch (_) {}

      await StorageService.clearAll();

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );

      if (!showMessage) return;

      final context = appNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your session expired. Please log in again with your phone number.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _isHandlingSessionExpiry = false;
    }
  }
}
