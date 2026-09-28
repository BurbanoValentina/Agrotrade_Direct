import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-26 & REQ-39: Proveedor de Tema con Persistencia Local y soporte dinámico.
class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'user_pref_is_dark_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// REQ-39: Cambia el tema y guarda la preferencia en SharedPreferences.
  /// Soporta llamada con parámetro explícito bool o sin parámetros para conmutar.
  Future<void> toggleTheme([bool? isDark]) async {
    final targetIsDark = isDark ?? !isDarkMode;
    _themeMode = targetIsDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _saveThemeToPrefs(targetIsDark);
  }

  /// Establece explícitamente el ThemeMode y persiste el cambio.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _saveThemeToPrefs(mode == ThemeMode.dark);
  }

  /// Guarda en disco la preferencia elegida.
  Future<void> _saveThemeToPrefs(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePrefKey, isDark);
    } catch (_) {
      // Manejo silencioso de error en almacenamiento local
    }
  }

  /// REQ-39: Carga la preferencia guardada al iniciar la app.
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
