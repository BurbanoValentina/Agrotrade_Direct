import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import 'auth_repository.dart';

/// Implementación real de autenticación con Supabase Auth y sincronización con tabla `profiles`.
/// Cumple con REQ-02, REQ-03, REQ-04 y REQ-05.
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase;

  SupabaseAuthRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final authResponse = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = authResponse.user;
    if (user == null) {
      throw const AuthException('No se pudo autenticar el usuario.');
    }

    return _fetchUserProfile(user);
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
    final authResponse = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': name.trim(),
        'role': role.name,
        'company_name': companyName?.trim(),
        'country': country?.trim(),
      },
    );

    final user = authResponse.user;
    if (user == null) {
      throw const AuthException('No se pudo crear la cuenta.');
    }

    return AppUser(
      id: user.id,
      name: name,
      email: email,
      role: role,
      companyName: companyName,
      country: country,
    );
  }

  @override
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  /// Consulta el perfil del usuario autenticado en la tabla `public.profiles`.
  Future<AppUser> _fetchUserProfile(User user) async {
    final profileData = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (profileData == null) {
      // Fallback si aún no se ha ejecutado el trigger o perfil diferido
      final meta = user.userMetadata ?? {};
      final roleStr = meta['role'] as String? ?? 'importador';
      return AppUser(
        id: user.id,
        name: meta['name'] as String? ?? (user.email?.split('@').first ?? 'Usuario'),
        email: user.email ?? '',
        role: roleStr == 'exportador' ? UserRole.exportador : UserRole.importador,
        companyName: meta['company_name'] as String?,
        country: meta['country'] as String?,
      );
    }

    final roleStr = profileData['role'] as String? ?? 'importador';
    return AppUser(
      id: profileData['id'] as String,
      name: profileData['name'] as String? ?? '',
      email: profileData['email'] as String? ?? (user.email ?? ''),
      role: roleStr == 'exportador' ? UserRole.exportador : UserRole.importador,
      companyName: profileData['company_name'] as String?,
      country: profileData['country'] as String?,
    );
  }
}
