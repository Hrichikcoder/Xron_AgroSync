import 'package:flutter/material.dart';
import 'core/globals.dart';
import 'screens/splash_screen.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

void main() {
  runApp(const SmartIrrigationApp());
}

class SmartIrrigationApp extends StatelessWidget {
  const SmartIrrigationApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  static final ValueNotifier<List<AppNotification>> notificationsNotifier = ValueNotifier([]);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (_, lang, __) {
        return ValueListenableBuilder<int>(
          valueListenable: translationTrigger,
          builder: (_, triggerValue, __) {
            return ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (_, currentMode, __) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  themeMode: currentMode,
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF0D5C2E),
                      brightness: Brightness.light,
                      surface: Colors.white,
                    ),
                    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
                    fontFamily: 'Roboto',
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.dark,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF10B981),
                      brightness: Brightness.dark,
                      surface: const Color(0xFF1E293B),
                    ),
                    scaffoldBackgroundColor: const Color(0xFF0F172A),
                    fontFamily: 'Roboto',
                  ),
                  home: const SplashScreen(),
                );
              },
            );
          },
        );
      },
    );
  }
}