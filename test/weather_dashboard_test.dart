import 'package:flutter_test/flutter_test.dart';

import 'package:agrotrade_direct/data/repositories/weather_repository.dart';
import 'package:agrotrade_direct/models/weather.dart';

void main() {
  group('Dashboard de clima', () {
    test('usa el respaldo local cuando no se proporciona la clave Google', () async {
      final repository = GoogleWeatherRepository(apiKey: '');

      final regions = await repository.fetchRegions();
      final forecast = await repository.fetchForecast(regions.first.id);

      expect(regions, isNotEmpty);
      expect(forecast.region.name, 'Huila');
      expect(forecast.days, hasLength(7));
      expect(forecast.days.first.maxTempC, isNotNull);
    });

    test('interpreta las estadísticas de Google Weather API', () {
      final forecast = WeatherForecast.fromJson({
        'region': {
          'id': 'huila',
          'name': 'Huila',
          'department': 'Huila',
          'latitude': 1.85,
          'longitude': -76.05,
        },
        'forecast': {
          'daily': {
            'time': ['2026-11-07'],
            'temperature_2m_max': [24],
          },
        },
        'fetched_at': '2026-11-07T12:00:00Z',
      });

      expect(forecast.days.single.maxTempC, 24);
      expect(forecast.region.department, 'Huila');
    });
  });
}
