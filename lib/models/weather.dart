/// REQ-48: zona productora con pronóstico (tabla `weather_regions`).
class WeatherRegion {
  final String id; // 'huila', 'sierra_nevada', ...
  final String name;
  final String department;
  final List<String> crops; // 'cafe', 'cacao'
  final double latitude;
  final double longitude;

  const WeatherRegion({
    required this.id,
    required this.name,
    required this.department,
    this.crops = const [],
    required this.latitude,
    required this.longitude,
  });

  factory WeatherRegion.fromJson(Map<String, dynamic> json) => WeatherRegion(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        department: json['department'] as String? ?? '',
        crops: (json['crops'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      );
}

/// Un día del pronóstico (datos diarios de Open-Meteo).
class DailyForecast {
  final DateTime date;
  final int? weatherCode;
  final double? maxTempC;
  final double? minTempC;
  final double? precipitationMm;
  final double? maxWindKmh;
  final double? relativeHumidity;
  final double? uvIndex;
  final double? feelsLikeC;
  final String? conditionText;

  const DailyForecast({
    required this.date,
    this.weatherCode,
    this.maxTempC,
    this.minTempC,
    this.precipitationMm,
    this.maxWindKmh,
    this.relativeHumidity,
    this.uvIndex,
    this.feelsLikeC,
    this.conditionText,
  });

  /// Descripción en español del código WMO de Open-Meteo.
  String get description => conditionText ?? describeWeatherCode(weatherCode);
}

/// Códigos WMO usados por Open-Meteo (https://open-meteo.com/en/docs).
String describeWeatherCode(int? code) {
  if (code == null) return 'Sin datos';
  if (code == 0) return 'Despejado';
  if (code <= 2) return 'Parcialmente nublado';
  if (code == 3) return 'Nublado';
  if (code == 45 || code == 48) return 'Niebla';
  if (code >= 51 && code <= 57) return 'Llovizna';
  if (code >= 61 && code <= 67) return 'Lluvia';
  if (code >= 71 && code <= 77) return 'Nieve';
  if (code >= 80 && code <= 82) return 'Chubascos';
  if (code >= 95) return 'Tormenta';
  return 'Variable';
}

/// Respuesta de la Edge Function `weather` (acción forecast).
class WeatherForecast {
  final WeatherRegion region;
  final List<DailyForecast> days;
  final DateTime fetchedAt;

  /// Viene de la caché (menos de 3 horas) en vez de una consulta nueva.
  final bool cached;

  /// El servicio del clima falló y se muestra la última copia guardada.
  final bool stale;

  const WeatherForecast({
    required this.region,
    required this.days,
    required this.fetchedAt,
    this.cached = false,
    this.stale = false,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final daily = (json['forecast'] as Map?)?['daily'] as Map? ?? const {};
    final times = (daily['time'] as List?) ?? const [];
    double? at(String field, int i) {
      final values = daily[field] as List?;
      return values == null || i >= values.length ? null : (values[i] as num?)?.toDouble();
    }

    return WeatherForecast(
      region: WeatherRegion.fromJson((json['region'] as Map).cast<String, dynamic>()),
      days: [
        for (var i = 0; i < times.length; i++)
          DailyForecast(
            date: DateTime.parse(times[i] as String),
            weatherCode: at('weather_code', i)?.toInt(),
            maxTempC: at('temperature_2m_max', i),
            minTempC: at('temperature_2m_min', i),
            precipitationMm: at('precipitation_sum', i),
            maxWindKmh: at('wind_speed_10m_max', i),
          ),
      ],
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      cached: json['cached'] as bool? ?? false,
      stale: json['stale'] as bool? ?? false,
    );
  }
}

/// Tipo de alerta climática (mismos valores que `weather_alerts.kind`).
enum WeatherAlertKind { lluviaFuerte, helada, calorExtremo, vientoFuerte }

extension WeatherAlertKindX on WeatherAlertKind {
  String get dbValue => switch (this) {
        WeatherAlertKind.lluviaFuerte => 'lluvia_fuerte',
        WeatherAlertKind.helada => 'helada',
        WeatherAlertKind.calorExtremo => 'calor_extremo',
        WeatherAlertKind.vientoFuerte => 'viento_fuerte',
      };

  String get label => switch (this) {
        WeatherAlertKind.lluviaFuerte => 'Lluvia fuerte',
        WeatherAlertKind.helada => 'Helada',
        WeatherAlertKind.calorExtremo => 'Calor extremo',
        WeatherAlertKind.vientoFuerte => 'Viento fuerte',
      };
}

/// Alerta climática publicada (tabla `weather_alerts`, REQ-49).
class WeatherAlert {
  final String id;
  final String regionId;
  final DateTime alertDate;
  final WeatherAlertKind kind;
  final double value;
  final double threshold;
  final String message;
  final DateTime createdAt;

  const WeatherAlert({
    required this.id,
    required this.regionId,
    required this.alertDate,
    required this.kind,
    required this.value,
    required this.threshold,
    required this.message,
    required this.createdAt,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) => WeatherAlert(
        id: json['id'] as String,
        regionId: json['region_id'] as String,
        alertDate: DateTime.parse(json['alert_date'] as String),
        kind: WeatherAlertKind.values.firstWhere(
          (k) => k.dbValue == json['kind'],
          orElse: () => WeatherAlertKind.lluviaFuerte,
        ),
        value: (json['value'] as num).toDouble(),
        threshold: (json['threshold'] as num).toDouble(),
        message: json['message'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
