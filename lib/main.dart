import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ves_exchange_calculator/components/calculator_screen.dart';
import 'package:ves_exchange_calculator/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  static const _kThemeModeKey = 'themeMode';

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_kThemeModeKey);
    setState(() {
      if (stored == 'light') {
        _themeMode = ThemeMode.light;
      } else if (stored == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (stored == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });

    SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString(
        _kThemeModeKey,
        _themeMode == ThemeMode.light
            ? 'light'
            : _themeMode == ThemeMode.dark
                ? 'dark'
                : 'system',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Calculator',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: CalculatorScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}