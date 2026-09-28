import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import 'auth_repository.dart';
import 'repository_exception.dart';
import 'supabase_error_mapper.dart';

/// Autenticación real con Supabase Auth + perfil de la tabla `profiles`.
/// Cumple con REQ-02, REQ-03, REQ-04 y REQ-05.
///
/// Al iniciar sesión o restaurarla también revisa `blocked_users` (REQ-24):
/// una cuenta bloqueada no puede entrar aunque su contraseña sea correcta.
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase;

  SupabaseAuthRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final User? user;
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      user = response.user;
    } catch (e) {
      throw mapSupabaseError(e);
    }
    if (user == null) {
      throw const RepositoryException('No se pudo iniciar sesión. Intenta de nuevo.');
    }
    return _loadSignedInUser(user);
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
    String? country,
  }) async {
    if (role == UserRole.staff) {
      throw const RepositoryException('Solo puedes registrarte como exportador o importador.');
    }

    final AuthResponse response;
    try {
      response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name.trim(),
          'role': role.name,
          'company_name': _clean(companyName),
          'country': _clean(country),
        },
      );
    } catch (e) {
      throw mapSupabaseError(e);
    }

    final user = response.user;
    if (user == null) {
      throw const RepositoryException('No se pudo crear la cuenta. Intenta de nuevo.');
    }
    // Con la confirmación de correo activa, Supabase no avisa que el correo ya
    // existe: devuelve un usuario "vacío" sin identidades.
    if (user.identities != null && user.identities!.isEmpty) {
      throw const RepositoryException('Ya existe una cuenta con ese correo.');
    }
    // Confirmación de correo activa: la cuenta existe pero aún no hay sesión.
    if (response.session == null) {
      throw RepositoryException(
          'Te enviamos un correo de confirmación a ${email.trim()}. '
          'Confírmalo y luego inicia sesión.');
    }
    return _loadSignedInUser(user);
  }

  @override
  Future<AppUser?> restoreSession() async {
    final user = _supabase.auth.currentSession?.user;
    if (user == null) return null;
    try {
      return await _loadSignedInUser(user);
    } on RepositoryException catch (e) {
      // Cuenta bloqueada: _loadSignedInUser ya cerró la sesión.
      debugPrint('No se restauró la sesión: ${e.message}');
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      // Sin conexión no se puede invalidar el token en el servidor, pero la
      // sesión local sí se cierra.
      await _supabase.auth.signOut(scope: SignOutScope.local);
      debugPrint('signOut global falló, se cerró solo la sesión local: $e');
    }
  }

  /// Perfil del usuario autenticado. Si está bloqueado, cierra la sesión y
  /// lanza [RepositoryException] con el motivo.
  Future<AppUser> _loadSignedInUser(User user) async {
    final Map<String, dynamic>? profile;
    final Map<String, dynamic>? block;
    try {
      profile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      block = await _supabase
          .from('blocked_users')
          .select('reason')
          .eq('user_id', user.id)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw mapSupabaseError(e);
    } catch (e) {
      // Sin conexión: se usa lo que viene en la sesión guardada para no sacar
      // al usuario de la app; el bloqueo se revisa en el siguiente arranque y
      // la BD lo aplica igual en cada operación.
      debugPrint('Perfil no disponible, se usan los datos de la sesión: $e');
      return _userFromMetadata(user);
    }

    if (block != null) {
      await logout();
      final reason = block['reason'] as String?;
      throw RepositoryException(
          'Tu cuenta está bloqueada${reason == null ? '' : ': $reason'}. '
          'Si crees que es un error, escribe a soporte.');
    }

    return profile == null
        ? _userFromMetadata(user) // el trigger de registro aún no creó el perfil
        : AppUser.fromProfile(profile, fallbackEmail: user.email);
  }

  static AppUser _userFromMetadata(User user) {
    final meta = user.userMetadata ?? const {};
    return AppUser(
      id: user.id,
      name: meta['name'] as String? ?? (user.email?.split('@').first ?? 'Usuario'),
      email: user.email ?? '',
      role: parseUserRole(meta['role'] as String?),
      companyName: meta['company_name'] as String?,
      country: meta['country'] as String?,
    );
  }

  static String? _clean(String? text) {
    final trimmed = text?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
