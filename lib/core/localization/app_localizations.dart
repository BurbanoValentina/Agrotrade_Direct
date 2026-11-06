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
      'live_market': 'Mercado en Vivo',
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
      'theme_light': 'Modo Claro',
      'theme_dark': 'Modo Oscuro',
      'theme_switch_to_light': 'Cambiar a modo claro (pasteles)',
      'theme_switch_to_dark': 'Cambiar a modo oscuro (cálido)',
      'language_spanish_name': 'Español',
      'language_english_name': 'Inglés',
      'language_switch_to_english': 'Cambiar idioma a inglés',
      'language_switch_to_spanish': 'Cambiar idioma a español',
      'nav_market': 'Mercado',
      'nav_deals': 'Mis Tratos',
      'nav_routes': 'Rutas',
      'nav_profile': 'Perfil',
      'deals_title': 'Mis Negociaciones',
      'deals_subtitle': 'Seguimiento de ofertas y contraofertas activas',
      'deals_description':
          'Aquí podrás gestionar todas tus propuestas comerciales, contraofertas en tiempo real y el historial de acuerdos cerrados.',
      'map_title': 'Rutas y Trazabilidad Transatlántica',
      'map_subtitle':
          'Monitoreo geoespacial en tiempo real (Colombia 🇨🇴 ⇄ Unión Europea 🇪🇺)',
      'shipment_in_transit': 'EN TRÁNSITO MARÍTIMO',
      'shipment_eta': 'ETA: 28 Sep 2026',
      'shipment_title': 'Lote #EXP-2026-089 · Café Washed Arabica',
      'shipment_exporter':
          'Exportación despachada desde Buenaventura · Origen Huila · 22 Toneladas Métricas',
      'shipment_importer':
          'Importación destinada a Hamburgo · Certificación Fair Trade y Rainforest Alliance',
      'origin_port': 'Puerto Origen',
      'destination_port': 'Puerto Destino',
      'atlantic_corridor': 'Corredor Marítimo Atlántico',
      'consumption_layer': 'Consumo',
      'consumption_empty': 'No hay puntos de consumo disponibles.',
      'timeline_title': 'Línea de Tiempo Operativa y Aduanera',
      'timeline_step_1': '1. Verificación e Inspección en Origen',
      'timeline_step_1_subtitle':
          'Finca Primavera (Huila) · Certificación de Calidad y No-Deforestación aprobada',
      'timeline_step_2': '2. Despacho y Carga Marítima',
      'timeline_step_2_subtitle':
          'Puerto de Buenaventura (CO) · Contenedor #CB-9941',
      'timeline_step_3': '3. En Tránsito Marítimo',
      'timeline_step_3_subtitle':
          'Trayecto Atlántico · ETA estimado: 28 Sep 2026',
      'timeline_step_4': '4. Inspección de Aduana UE (EUTR)',
      'timeline_step_4_subtitle':
          'Puerto de Hamburgo (DE) · Revisión de Fitosanitario y Trazabilidad',
      'timeline_step_5': '5. Entrega Confirmada a Importador',
      'timeline_step_5_subtitle':
          'Almacén Central Hamburgo · Traspaso de título de propiedad',
      'in_progress': 'En progreso',
      'pending': 'Pendiente',
      'annual_consumption': 'Consumo anual',
      'tons': 'toneladas',
      'main_import_grade': 'Grado de importación principal',
      'description': 'Descripción',
      'not_specified': 'No especificado',
      'profile_user': 'Usuario AgroTrade',
      'profile_deals': 'Tratos',
      'profile_rating': 'Calificación',
      'profile_volume': 'Volumen',
      'switched_exporter': 'Cambiado a vista Exportador 🇨🇴',
      'switched_importer': 'Cambiado a vista Importador 🇪🇺',
      'certified_exporter': 'Exportador Certificado 🇨🇴',
      'official_importer': 'Importador Oficial UE 🇪🇺',
      'report_irregularity': 'Reportar Irregularidad',
      'logout': 'Cerrar sesión',
      'integration_module': 'Módulo en fase de integración',
      'live': 'EN VIVO',
      'offers_count': 'ofertas',
      'offer_published_success': 'Oferta publicada exitosamente',
      'offer_publish_error': 'Error al publicar la oferta',
      'offer_search_empty': 'Sin resultados para tu búsqueda',
      'offer_search_hint': 'Prueba cambiando las palabras clave o los filtros.',
      'counter_offer_sent': 'Contraoferta de \$PRICE/MT enviada',
      'counter_offer_error': 'No se pudo enviar la contraoferta',
      'admin_dashboard': 'Dashboard',
      'admin_users': 'Usuarios',
      'admin_security': 'Seguridad',
      'admin_market': 'Mercado',
      'admin_settings': 'Ajustes',
      'admin_restricted': 'Acceso Restringido',
      'admin_no_permissions':
          'No tienes permisos asignados. Contacta al Administrador.',
      'admin_panel': 'Panel de Control Interno',
      'admin_logout': 'Cerrar Sesión',
      'login_welcome': '¡Bienvenido de vuelta!',
      'login_subtitle':
          'Ingresa a tu cuenta para gestionar operaciones y mercado.',
      'exporter': 'Exportador',
      'importer': 'Importador',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'password_hint': 'Tu contraseña',
      'login_submit': 'Iniciar sesión',
      'register_prompt': '¿Aún no tienes cuenta?',
      'register_link': 'Crear cuenta',
      'register_title': 'Crear Cuenta Comercial',
      'register_profile_prompt':
          'Selecciona tu perfil para personalizar tu entorno de trabajo:',
      'register_name': 'Nombre completo',
      'register_email': 'Correo electrónico',
      'register_password': 'Contraseña',
      'register_company_exporter': 'Finca / Empresa exportadora',
      'register_company_importer': 'Empresa importadora',
      'register_region_exporter': 'Región cafetera / cacaotera',
      'register_country_importer': 'País de destino (UE)',
      'register_submit': 'Crear Cuenta',
      'register_finish': 'Completar Registro',
      'already_have_account': '¿Ya tienes cuenta? Inicia sesión aquí',
      'colombia': 'Colombia',
      'eu_union': 'Unión Europea',
      'join_network': 'Únete a la Red Comercial',
      'login_to_platform': 'Iniciar sesión',
      'register_success': 'Cuenta creada exitosamente',
      'invalid_email': 'Correo electrónico inválido',
      'required_field': 'Requerido',
      'password_minimum': 'Mínimo 4 caracteres',
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
      'theme_light': 'Light Mode',
      'theme_dark': 'Dark Mode',
      'theme_switch_to_light': 'Switch to light mode (pastel)',
      'theme_switch_to_dark': 'Switch to dark mode (warm)',
      'language_spanish_name': 'Spanish',
      'language_english_name': 'English',
      'language_switch_to_english': 'Switch language to English',
      'language_switch_to_spanish': 'Switch language to Spanish',
      'nav_market': 'Market',
      'nav_deals': 'My Deals',
      'nav_routes': 'Routes',
      'nav_profile': 'Profile',
      'deals_title': 'My Negotiations',
      'deals_subtitle': 'Track active offers and counteroffers',
      'deals_description':
          'Manage your trade proposals, real-time counteroffers, and closed-deal history here.',
      'map_title': 'Transatlantic Routes and Traceability',
      'map_subtitle':
          'Real-time geospatial monitoring (Colombia 🇨🇴 ⇄ European Union 🇪🇺)',
      'shipment_in_transit': 'IN MARITIME TRANSIT',
      'shipment_eta': 'ETA: Sep 28, 2026',
      'shipment_title': 'Lot #EXP-2026-089 · Washed Arabica Coffee',
      'shipment_exporter':
          'Shipment dispatched from Buenaventura · Huila origin · 22 Metric Tons',
      'shipment_importer':
          'Import for Hamburg · Fair Trade and Rainforest Alliance certified',
      'origin_port': 'Origin Port',
      'destination_port': 'Destination Port',
      'atlantic_corridor': 'Atlantic Shipping Corridor',
      'consumption_layer': 'Consumption',
      'consumption_empty': 'No consumption points available.',
      'timeline_title': 'Operational and Customs Timeline',
      'timeline_step_1': '1. Origin Verification and Inspection',
      'timeline_step_1_subtitle':
          'Finca Primavera (Huila) · Quality and deforestation-free certification approved',
      'timeline_step_2': '2. Dispatch and Maritime Loading',
      'timeline_step_2_subtitle':
          'Port of Buenaventura (CO) · Container #CB-9941',
      'timeline_step_3': '3. Maritime Transit',
      'timeline_step_3_subtitle':
          'Atlantic route · Estimated ETA: Sep 28, 2026',
      'timeline_step_4': '4. EU Customs Inspection (EUTR)',
      'timeline_step_4_subtitle':
          'Port of Hamburg (DE) · Phytosanitary and traceability review',
      'timeline_step_5': '5. Delivery Confirmed to Importer',
      'timeline_step_5_subtitle':
          'Hamburg Central Warehouse · Transfer of title',
      'in_progress': 'In progress',
      'pending': 'Pending',
      'annual_consumption': 'Annual consumption',
      'tons': 'tons',
      'main_import_grade': 'Main import grade',
      'description': 'Description',
      'not_specified': 'Not specified',
      'profile_user': 'AgroTrade User',
      'profile_deals': 'Deals',
      'profile_rating': 'Rating',
      'profile_volume': 'Volume',
      'switched_exporter': 'Switched to Exporter view 🇨🇴',
      'switched_importer': 'Switched to Importer view 🇪🇺',
      'certified_exporter': 'Certified Exporter 🇨🇴',
      'official_importer': 'Official EU Importer 🇪🇺',
      'report_irregularity': 'Report an Issue',
      'logout': 'Sign out',
      'integration_module': 'Module under integration',
      'live': 'LIVE',
      'offers_count': 'offers',
      'offer_published_success': 'Offer published successfully',
      'offer_publish_error': 'Could not publish offer',
      'offer_search_empty': 'No results for your search',
      'offer_search_hint': 'Try changing your keywords or filters.',
      'counter_offer_sent': 'Counteroffer of \$PRICE/MT sent',
      'counter_offer_error': 'Could not send counteroffer',
      'admin_dashboard': 'Dashboard',
      'admin_users': 'Users',
      'admin_security': 'Security',
      'admin_market': 'Market',
      'admin_settings': 'Settings',
      'admin_restricted': 'Access Restricted',
      'admin_no_permissions':
          'No permissions assigned. Contact the administrator.',
      'admin_panel': 'Internal Control Panel',
      'admin_logout': 'Sign Out',
      'login_welcome': 'Welcome back!',
      'login_subtitle': 'Sign in to manage your operations and market.',
      'exporter': 'Exporter',
      'importer': 'Importer',
      'email': 'Email address',
      'password': 'Password',
      'password_hint': 'Your password',
      'login_submit': 'Sign in',
      'register_prompt': "Don't have an account?",
      'register_link': 'Create account',
      'register_title': 'Create a Business Account',
      'register_profile_prompt':
          'Select your profile to personalize your workspace:',
      'register_name': 'Full name',
      'register_email': 'Email address',
      'register_password': 'Password',
      'register_company_exporter': 'Farm / Exporting company',
      'register_company_importer': 'Importing company',
      'register_region_exporter': 'Coffee / cacao region',
      'register_country_importer': 'Destination country (EU)',
      'register_submit': 'Create Account',
      'register_finish': 'Complete Registration',
      'already_have_account': 'Already have an account? Sign in here',
      'colombia': 'Colombia',
      'eu_union': 'European Union',
      'join_network': 'Join the Trade Network',
      'login_to_platform': 'Sign in',
      'register_success': 'Account created successfully',
      'invalid_email': 'Invalid email address',
      'required_field': 'Required',
      'password_minimum': 'At least 4 characters',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
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
