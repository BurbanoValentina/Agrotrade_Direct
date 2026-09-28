import 'package:flutter/material.dart';

/// REQ-26: Proveedor de estado para alternar el tema claro / oscuro en toda la app.
/// Expone la lógica que consume la pantalla de Configuración (REQ-44 de Valery).
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark; // Tema predeterminado del proyecto

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Alterna entre tema claro y tema oscuro
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // Redibuja toda la jerarquía de widgets en MaterialApp
  }
}
