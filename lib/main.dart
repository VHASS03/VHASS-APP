import 'package:flutter/material.dart';
import 'theme_controller.dart'; 
import 'screens/Settings/settings.dart';
import 'theme/app_theme.dart';
import 'screens/splash.dart';

void main() {
  runApp(const MyApp());
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
          
          // These now call the function with different brightnesses
          theme: appTheme(Brightness.light), 
          darkTheme: appTheme(Brightness.dark), 
          
          home: const SplashScreen(),
        );
      },
    );
  }
}