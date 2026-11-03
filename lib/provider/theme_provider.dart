import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  // Start with system default; will be overridden once prefs are loaded.
  // This prevents the dark→light flash on first render.
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoaded = false;
  static const String _themeKey = "theme_preference";

  ThemeMode get themeMode => _themeMode;
  bool get isLoaded => _isLoaded;

  ThemeProvider() {
    _loadTheme();
  }

  void toggleTheme(bool isDarkMode) async {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDarkMode);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getBool(_themeKey);
    if (savedValue == null) {
      // First launch: default to dark mode and save it
      _themeMode = ThemeMode.dark;
      await prefs.setBool(_themeKey, true);
    } else {
      _themeMode = savedValue ? ThemeMode.dark : ThemeMode.light;
    }
    _isLoaded = true;
    notifyListeners();
  }
}
