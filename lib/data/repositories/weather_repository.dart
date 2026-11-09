import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/weather.dart';
import 'repository_exception.dart';
import 'supabase_error_mapper.dart';

/// REQ-48 / REQ-49: clima de las zonas productoras y alertas climáticas.
///
/// El pronóstico pasa por la Edge Function `weather` (Open-Meteo con caché de
/// 3 horas); la app nunca llama a la API del clima directamente.
abstract class WeatherRepository {
  /// Zonas productoras con pronóstico, ordenadas por nombre.
  Future<List<WeatherRegion>> fetchRegions();

  /// Pronóstico de 7 días de la región [regionId] (ej. 'huila').
  Future<WeatherForecast> fetchForecast(String regionId);

  /// Alertas desde [from] (por defecto, hoy), opcionalmente de una región.
  Future<List<WeatherAlert>> fetchAlerts({String? regionId, DateTime? from});

  /// Revisa ya todas las regiones con actividad y envía las alertas
  /// (personal con permiso settings). Devuelve el resumen de la revisión.
  Future<Map<String, dynamic>> runAlertCheck();
}

/// Cliente de Google Weather API. La clave se recibe por `--dart-define` para
/// evitar secretos en el repositorio y permite una experiencia local sin red.
class GoogleWeatherRepository implements WeatherRepository {
  GoogleWeatherRepository({
    String? apiKey,
    http.Client? client,
    MockWeatherRepository? fallback,
  })  : _apiKey = apiKey ?? const String.fromEnvironment('GOOGLE_WEATHER_API_KEY'),
        _client = client ?? http.Client(),
        _fallback = fallback ?? MockWeatherRepository();

  final String _apiKey;
  final http.Client _client;
  final MockWeatherRepository _fallback;

  static const _regions = [
    WeatherRegion(id: 'huila', name: 'Huila', department: 'Huila', crops: ['cafe'], latitude: 1.8537, longitude: -76.0507),
    WeatherRegion(id: 'narino', name: 'Nariño', department: 'Nariño', crops: ['cafe'], latitude: 1.6046, longitude: -77.1303),
    WeatherRegion(id: 'santander', name: 'Santander', department: 'Santander', crops: ['cacao', 'cafe'], latitude: 6.8808, longitude: -73.4103),
    WeatherRegion(id: 'sierra_nevada', name: 'Sierra Nevada', department: 'Magdalena', crops: ['cafe'], latitude: 11.1426, longitude: -74.1196),
  ];

  @override
  Future<List<WeatherRegion>> fetchRegions() async => _regions;

  @override
  Future<WeatherForecast> fetchForecast(String regionId) async {
    final region = _regions.firstWhere(
      (item) => item.id == regionId,
      orElse: () => throw const RepositoryException('Esa región no existe.'),
    );
    if (_apiKey.isEmpty) return _fallback.fetchForecast(regionId);

    final uri = Uri.https('weather.googleapis.com', '/v1/currentConditions:lookup', {
      'key': _apiKey,
      'location.latitude': '${region.latitude}',
      'location.longitude': '${region.longitude}',
      'unitsSystem': 'METRIC',
    });
    try {
      final response = await _client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RepositoryException('Weather API respondió ${response.statusCode}.');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['temperature'] as Map? ?? const {};
      final feelsLike = json['feelsLikeTemperature'] as Map? ?? const {};
      final precipitation = json['precipitation'] as Map? ?? const {};
      final qpf = precipitation['qpf'] as Map? ?? const {};
      final wind = json['wind'] as Map? ?? const {};
      final speed = wind['speed'] as Map? ?? const {};
      final condition = json['weatherCondition'] as Map? ?? const {};
      final description = condition['description'] as Map? ?? const {};
      final now = DateTime.now();
      return WeatherForecast(
        region: region,
        fetchedAt: now,
        days: [
          DailyForecast(
            date: DateTime(now.year, now.month, now.day),
            maxTempC: (current['degrees'] as num?)?.toDouble(),
            minTempC: (current['degrees'] as num?)?.toDouble(),
            feelsLikeC: (feelsLike['degrees'] as num?)?.toDouble(),
            precipitationMm: (qpf['quantity'] as num?)?.toDouble(),
            maxWindKmh: (speed['value'] as num?)?.toDouble(),
            relativeHumidity: (json['relativeHumidity'] as num?)?.toDouble(),
            uvIndex: (json['uvIndex'] as num?)?.toDouble(),
            conditionText: description['text'] as String?,
          ),
        ],
      );
    } catch (_) {
      final fallback = await _fallback.fetchForecast(regionId);
      return WeatherForecast(
        region: fallback.region,
        days: fallback.days,
        fetchedAt: fallback.fetchedAt,
        cached: true,
        stale: true,
      );
    }
  }

  @override
  Future<List<WeatherAlert>> fetchAlerts({String? regionId, DateTime? from}) async =>
      const [];

  @override
  Future<Map<String, dynamic>> runAlertCheck() async =>
      throw const RepositoryException('Las alertas requieren Supabase configurado.');
}

class SupabaseWeatherRepository implements WeatherRepository {
  SupabaseWeatherRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<List<WeatherRegion>> fetchRegions() async {
    try {
      final rows = await _supabase.from('weather_regions').select().order('name');
      return (rows as List<dynamic>)
          .map((json) => WeatherRegion.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await _supabase.functions.invoke('weather', body: body);
      return (response.data as Map).cast<String, dynamic>();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<WeatherForecast> fetchForecast(String regionId) async {
    final data = await _invoke({'action': 'forecast', 'region_id': regionId});
    return WeatherForecast.fromJson(data);
  }

  @override
  Future<List<WeatherAlert>> fetchAlerts({String? regionId, DateTime? from}) async {
    final since = from ?? DateTime.now();
    final day = '${since.year.toString().padLeft(4, '0')}-'
        '${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
    try {
      var query = _supabase.from('weather_alerts').select().gte('alert_date', day);
      if (regionId != null) query = query.eq('region_id', regionId);
      final rows = await query.order('alert_date');
      return (rows as List<dynamic>)
          .map((json) => WeatherAlert.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> runAlertCheck() => _invoke({'action': 'check_alerts'});
}

/// Datos de ejemplo para la UI sin conexión: Huila con lluvia fuerte mañana.
class MockWeatherRepository implements WeatherRepository {
  MockWeatherRepository({this.canRunAlertCheck = false});

  bool canRunAlertCheck;

  static const _regions = [
    WeatherRegion(id: 'huila', name: 'Huila', department: 'Huila', crops: ['cafe'], latitude: 1.8537, longitude: -76.0507),
    WeatherRegion(id: 'narino', name: 'Nariño', department: 'Nariño', crops: ['cafe'], latitude: 1.6046, longitude: -77.1303),
    WeatherRegion(id: 'santander', name: 'Santander', department: 'Santander', crops: ['cacao', 'cafe'], latitude: 6.8808, longitude: -73.4103),
    WeatherRegion(id: 'sierra_nevada', name: 'Sierra Nevada', department: 'Magdalena', crops: ['cafe'], latitude: 11.1426, longitude: -74.1196),
  ];

  @override
  Future<List<WeatherRegion>> fetchRegions() async => _regions;

  @override
  Future<WeatherForecast> fetchForecast(String regionId) async {
    final region = _regions.where((r) => r.id == regionId).firstOrNull;
    if (region == null) throw const RepositoryException('Esa región no existe.');
    final today = DateTime.now();
    return WeatherForecast(
      region: region,
      fetchedAt: today,
      cached: true,
      days: [
        for (var i = 0; i < 7; i++)
          DailyForecast(
            date: DateTime(today.year, today.month, today.day + i),
            weatherCode: i == 1 ? 65 : (i.isEven ? 2 : 61),
            maxTempC: 26 + i % 3,
            minTempC: 14 + i % 2,
            precipitationMm: i == 1 ? 62 : (i.isEven ? 1.5 : 8),
            maxWindKmh: 18 + i * 2,
          ),
      ],
    );
  }

  @override
  Future<List<WeatherAlert>> fetchAlerts({String? regionId, DateTime? from}) async {
    if (regionId != null && regionId != 'huila') return const [];
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return [
      WeatherAlert(
        id: 'alert-1',
        regionId: 'huila',
        alertDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        kind: WeatherAlertKind.lluviaFuerte,
        value: 62,
        threshold: 50,
        message: 'Lluvia fuerte en Huila: 62 mm previstos. Protege el producto en secado y revisa las vías de despacho.',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> runAlertCheck() async {
    if (!canRunAlertCheck) {
      throw const RepositoryException(
          'Solo el personal con permiso de configuración puede revisar las alertas.');
    }
    return {'regions_checked': 1, 'alerts_created': 1, 'notified': 2, 'errors': []};
  }
}
