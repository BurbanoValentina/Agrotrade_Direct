import 'package:flutter/material.dart';

/// REQ-31: Provider de estado reactivo para conmutar el idioma global (ES / EN).
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('es');

  Locale get locale => _locale;
  bool get isSpanish => _locale.languageCode == 'es';

  void setLocale(Locale newLocale) {
    if (!['es', 'en'].contains(newLocale.languageCode)) return;
    _locale = newLocale;
    notifyListeners();
  }

  void toggleLanguage() {
    _locale = _locale.languageCode == 'es'
        ? const Locale('en')
        : const Locale('es');
    notifyListeners();
  }
}