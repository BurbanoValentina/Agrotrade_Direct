import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-26 & REQ-39: Proveedor de Tema con Persistencia Local.
class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'user_pref_is_dark_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// REQ-39: Guardar la preferencia de tema en SharedPreferences
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePrefKey, isDark);
    } catch (_) {
      // Manejo silencioso en caso de error de lectura/escritura
    }
  }

  /// REQ-39: Cargar la preferencia guardada al iniciar la app
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_themePrefKey);
      if (isDark != null) {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        notifyListeners();
      }
    } catch (_) {
      // Retorna tema por defecto si no hay preferencia previa
    }
  }
}
