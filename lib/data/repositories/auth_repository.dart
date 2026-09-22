import '../../models/app_user.dart';
import '../../models/user_role.dart';

/// Contrato de autenticación.
///
/// IMPORTANTE PARA EL BACKEND DEV: cuando conectes Supabase, crea una clase
/// `SupabaseAuthRepository implements AuthRepository` en un archivo nuevo
/// (ej. `supabase_auth_repository.dart`) e implementa estos mismos métodos
/// usando `supabase_flutter`. Luego solo cambia una línea en `main.dart`
/// (ver README) — ninguna pantalla necesita modificarse.
abstract class AuthRepository {
  Future<AppUser> login({required String email, required String password});

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
    String? country,
  });

  Future<void> logout();
}

/// Implementación falsa en memoria, solo para desarrollar la UI (REQ-04).
/// No valida contraseñas de verdad: sirve para navegar el flujo completo.
class MockAuthRepository implements AuthRepository {
  final Map<String, AppUser> _usersByEmail = {};

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final existing = _usersByEmail[email.toLowerCase()];
    if (existing != null) return existing;

    // Si no existe (demo), se crea un exportador de ejemplo para poder
    // seguir probando la app sin tener que registrarse primero.
    final demoUser = AppUser(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Usuario Demo',
      email: email,
      role: UserRole.exportador,
    );
    _usersByEmail[email.toLowerCase()] = demoUser;
    return demoUser;
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
    await Future.delayed(const Duration(milliseconds: 500));
    final user = AppUser(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
      companyName: companyName,
      country: country,
    );
    _usersByEmail[email.toLowerCase()] = user;
    return user;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
