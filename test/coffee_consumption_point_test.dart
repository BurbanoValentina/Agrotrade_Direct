import 'package:flutter_test/flutter_test.dart';

import 'package:agrotrade_direct/models/coffee_consumption_point.dart';

void main() {
  group('CoffeeConsumptionPoint.fromJson', () {
    test('maps database columns to the model', () {
      final point = CoffeeConsumptionPoint.fromJson({
        'id': 42,
        'city_name': 'Hamburgo',
        'country': 'Alemania',
        'latitude': '53.5511',
        'longitude': 9.9937,
        'annual_consumption_tons': 125000,
        'main_import_grade': 'Arábica lavado',
        'description': 'Puerto principal de importación.',
      });

      expect(point.id, '42');
      expect(point.cityName, 'Hamburgo');
      expect(point.country, 'Alemania');
      expect(point.latitude, 53.5511);
      expect(point.longitude, 9.9937);
      expect(point.annualConsumptionTons, 125000);
      expect(point.mainImportGrade, 'Arábica lavado');
      expect(point.description, 'Puerto principal de importación.');
    });

    test('uses safe defaults for missing or invalid values', () {
      final point = CoffeeConsumptionPoint.fromJson({
        'cityName': null,
        'latitude': 'invalid',
      });

      expect(point.id, isEmpty);
      expect(point.cityName, 'Ciudad desconocida');
      expect(point.country, isEmpty);
      expect(point.latitude, 0);
      expect(point.longitude, 0);
      expect(point.annualConsumptionTons, 0);
      expect(point.mainImportGrade, isEmpty);
      expect(point.description, isEmpty);
    });
  });
}
