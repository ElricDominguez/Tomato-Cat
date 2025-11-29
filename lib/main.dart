import 'package:flutter/material.dart';
import 'timer_screen.dart';

void main() {
  runApp(const TomatoCatApp());
}

class TomatoCatApp extends StatefulWidget {
  const TomatoCatApp({super.key});

  @override
  State<TomatoCatApp> createState() => _TomatoCatAppState();
}

class _TomatoCatAppState extends State<TomatoCatApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tomato Cat Pomodoro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,

      // LIGHT THEME
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F2E9), // Bauhaus warm
        useMaterial3: true,
      ),

      // DARK THEME
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      home: TimerScreen(
        themeMode: _themeMode,
        onThemeChanged: _setThemeMode,
      ),
    );
  }
}
