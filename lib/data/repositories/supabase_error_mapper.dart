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
    return _mapAuthError(error);
  }

  debugPrint('Error no controlado en repositorio: $error');
  return const RepositoryException(_connectionMessage);
}

const _connectionMessage =
    'No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.';

/// Errores de Supabase Auth (códigos: supabase.com/docs/guides/auth/debugging/error-codes).
RepositoryException _mapAuthError(AuthException error) {
  switch (error.code) {
    case 'invalid_credentials':
      return const RepositoryException('Correo o contraseña incorrectos.');
    case 'email_not_confirmed':
      return const RepositoryException(
          'Debes confirmar tu correo antes de iniciar sesión. Revisa tu bandeja de entrada.');
    case 'user_already_exists':
    case 'email_exists':
      return const RepositoryException('Ya existe una cuenta con ese correo.');
    case 'weak_password':
      return const RepositoryException(
          'La contraseña es muy débil. Usa al menos 6 caracteres, combinando letras y números.');
    case 'email_address_invalid':
    case 'validation_failed':
      return const RepositoryException('El correo electrónico no es válido.');
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return const RepositoryException(
          'Demasiados intentos. Espera unos minutos e intenta de nuevo.');
    case 'signup_disabled':
      return const RepositoryException('El registro de cuentas está deshabilitado por ahora.');
    case 'user_banned':
      return const RepositoryException('Tu cuenta está suspendida.');
    case 'session_expired':
    case 'refresh_token_not_found':
      return const RepositoryException('Tu sesión expiró. Inicia sesión de nuevo.');
  }
  // Sin respuesta del servidor (sin internet, DNS, tiempo agotado).
  if (error is AuthRetryableFetchException || (error.statusCode == null && error.code == null)) {
    return const RepositoryException(_connectionMessage);
  }
  debugPrint('AuthException ${error.code} (${error.statusCode}): ${error.message}');
  return const RepositoryException('No se pudo completar la autenticación. Intenta de nuevo.');
}
