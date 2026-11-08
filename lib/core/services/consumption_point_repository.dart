import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/coffee_consumption_point.dart';
import '../../data/repositories/supabase_error_mapper.dart';

abstract class ConsumptionPointRepository {
  Future<List<CoffeeConsumptionPoint>> fetchConsumptionPoints();
}

/// Lee puntos de consumo desde `coffee_consumption_points` en Supabase.
///
/// El cliente puede inyectarse en pruebas; si no se proporciona, se utiliza
/// el cliente inicializado por la aplicación.
class SupabaseConsumptionPointRepository implements ConsumptionPointRepository {
  SupabaseConsumptionPointRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<List<CoffeeConsumptionPoint>> fetchConsumptionPoints() async {
    try {
      final response =
          await _supabase.from('coffee_consumption_points').select();

      return (response as List<dynamic>)
          .map(
            (json) => CoffeeConsumptionPoint.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }
}
