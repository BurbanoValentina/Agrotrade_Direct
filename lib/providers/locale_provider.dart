import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-31 & REQ-39: Proveedor de Idioma con Persistencia Local.
class LocaleProvider extends ChangeNotifier {
  static const String _languagePrefKey = 'user_pref_language_code';

  Locale _locale = const Locale('es');

  LocaleProvider() {
    _loadLocaleFromPrefs();
  }

  Locale get locale => _locale;
  bool get isSpanish => _locale.languageCode == 'es';

  /// REQ-39: Guardar la preferencia de idioma en SharedPreferences
  Future<void> setLocale(Locale newLocale) async {
    if (!['es', 'en'].contains(newLocale.languageCode)) return;
    _locale = newLocale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languagePrefKey, newLocale.languageCode);
    } catch (_) {}
  }

  /// REQ-39: Alternar idioma y persistir el cambio
  Future<void> toggleLanguage() async {
    final newCode = _locale.languageCode == 'es' ? 'en' : 'es';
    await setLocale(Locale(newCode));
  }

  /// REQ-39: Cargar la preferencia de idioma al iniciar la app
  Future<void> _loadLocaleFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString(_languagePrefKey);
      if (langCode != null && ['es', 'en'].contains(langCode)) {
        _locale = Locale(langCode);
        notifyListeners();
      }
    } catch (_) {}
  }
}
