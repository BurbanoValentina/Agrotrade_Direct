import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_exception.dart';

/// Traduce un error de Supabase a un [RepositoryException] con mensaje en
/// español para el usuario.
///
/// Las reglas de negocio de la base de datos (triggers) lanzan sus errores con
/// el código `P0001` y un mensaje ya redactado para el usuario, así que ese
/// mensaje se muestra tal cual. Ver supabase/migrations/.
RepositoryException mapSupabaseError(Object error) {
  if (error is RepositoryException) return error;

  if (error is PostgrestException) {
    switch (error.code) {
      case 'P0001':
        return RepositoryException(error.message);
      case '42501':
        return const RepositoryException(
            'No tienes permiso para realizar esta acción.');
      case '23505':
        return const RepositoryException('Ya existe un registro con esos datos.');
      case '23514':
        return const RepositoryException('Alguno de los valores no es válido.');
      case '23503':
        return const RepositoryException(
            'El registro relacionado no existe o fue eliminado.');
      case 'PGRST116':
        return const RepositoryException('No se encontró el registro.');
    }
    debugPrint('PostgrestException ${error.code}: ${error.message} ${error.details}');
    return const RepositoryException('Ocurrió un error inesperado. Intenta de nuevo.');
  }

  if (error is AuthException) {
    return RepositoryException(error.message);
  }

  debugPrint('Error no controlado en repositorio: $error');
  return const RepositoryException(
      'No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.');
}
