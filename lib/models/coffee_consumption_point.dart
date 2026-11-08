/// Punto geográfico de consumo/importación de café (REQ-50).
class CoffeeConsumptionPoint {
  const CoffeeConsumptionPoint({
    required this.id,
    required this.cityName,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.annualConsumptionTons,
    required this.mainImportGrade,
    required this.description,
  });

  final String id;
  final String cityName;
  final String country;
  final double latitude;
  final double longitude;
  final double annualConsumptionTons;
  final String mainImportGrade;
  final String description;

  factory CoffeeConsumptionPoint.fromJson(Map<String, dynamic> json) {
    return CoffeeConsumptionPoint(
      id: _stringValue(json['id']),
      cityName: _stringValue(json['city_name'] ?? json['cityName'],
          fallback: 'Ciudad desconocida'),
      country: _stringValue(json['country']),
      latitude: _numberValue(json['latitude']),
      longitude: _numberValue(json['longitude']),
      annualConsumptionTons: _numberValue(
        json['annual_consumption_tons'] ?? json['annualConsumptionTons'],
      ),
      mainImportGrade: _stringValue(
        json['main_import_grade'] ?? json['mainImportGrade'],
      ),
      description: _stringValue(json['description']),
    );
  }

  static String _stringValue(Object? value, {String fallback = ''}) =>
      value?.toString() ?? fallback;

  static double _numberValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
