import 'package:flutter/material.dart';

// This is the SINGLE source of truth for your theme
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);