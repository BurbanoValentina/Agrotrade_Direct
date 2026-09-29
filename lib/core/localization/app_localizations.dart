import 'package:flutter/material.dart';

/// REQ-31: Diccionario y traducciones centralizadas para Español e Inglés.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('es'));
  }

  static const _localizedValues = <String, Map<String, String>>{
    'es': {
      'app_title': 'AgroTrade Direct',
      'live_market': 'Live Market',
      'active_offers': 'ofertas activas de Colombia',
      'search_placeholder': 'Buscar variedad, origen...',
      'all': 'Todos',
      'coffee': 'Café',
      'cacao': 'Cacao',
      'publish_offer': 'Publicar Oferta',
      'make_offer': 'Hacer Oferta',
      'no_offers': 'No hay ofertas disponibles',
      'my_deals': 'Mis Tratos',
      'settings': 'Configuración',
      'language': 'Idioma',
      'spanish': 'Español',
      'english': 'Inglés',
      'theme': 'Tema',
    },
    'en': {
      'app_title': 'AgroTrade Direct',
      'live_market': 'Live Market',
      'active_offers': 'active offers from Colombia',
      'search_placeholder': 'Search variety, origin...',
      'all': 'All',
      'coffee': 'Coffee',
      'cacao': 'Cacao',
      'publish_offer': 'Publish Offer',
      'make_offer': 'Make an Offer',
      'no_offers': 'No offers available',
      'my_deals': 'My Deals',
      'settings': 'Settings',
      'language': 'Language',
      'spanish': 'Spanish',
      'english': 'English',
      'theme': 'Theme',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['es', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const LocalizationsDelegate<AppLocalizations> appLocalizationsDelegate =
    _AppLocalizationsDelegate();
    