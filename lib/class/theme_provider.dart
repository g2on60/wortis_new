import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  final String _themePreferenceKey = 'theme_mode';
  
  ThemeProvider() {
    _loadThemePreference();
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themePreferenceKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = !_isDarkMode;
    await prefs.setBool(_themePreferenceKey, _isDarkMode);
    notifyListeners();
  }

  ThemeData getLightTheme() {
    return ThemeData(
      primaryColor: const Color(0xFF006699),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF006699),
        elevation: 0,
      ),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF006699),
        secondary: Color(0xFF006699),
      ),
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      primaryColor: const Color(0xFF006699),
      scaffoldBackgroundColor: const Color.fromARGB(255, 87, 86, 86),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF006699),
        elevation: 0,
      ),
      
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF006699),
        secondary: Color(0xFF006699),
      ),
    );
  }
}