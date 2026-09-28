import '../../models/app_user.dart';
import '../../models/user_role.dart';
import 'repository_exception.dart';

/// Contrato de autenticación (REQ-02 a REQ-04).
///
/// Implementaciones: [MockAuthRepository] (en memoria) y
/// `SupabaseAuthRepository`. Todos los métodos lanzan [RepositoryException]
/// con un mensaje para el usuario (ej. "Correo o contraseña incorrectos.").
abstract class AuthRepository {
  Future<AppUser> login({required String email, required String password});

  /// Crea la cuenta como exportador o importador ([UserRole.staff] no se
  /// puede registrar desde la app). Si el proyecto exige confirmar el correo,
  /// lanza [RepositoryException] pidiendo confirmarlo antes de iniciar sesión.
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
    String? country,
  });

  /// Usuario de la sesión guardada en el dispositivo, o `null` si no hay
  /// sesión (o si la cuenta fue bloqueada). Se llama al abrir la app.
  Future<AppUser?> restoreSession();

  Future<void> logout();
}

/// Implementación falsa en memoria, solo para desarrollar la UI (REQ-04).
/// No valida contraseñas de verdad: sirve para navegar el flujo completo.
class MockAuthRepository implements AuthRepository {
  final Map<String, AppUser> _usersByEmail = {};
  AppUser? _session;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final existing = _usersByEmail[email.toLowerCase()];
    if (existing != null) return _session = existing;

    // Si no existe (demo), se crea un exportador de ejemplo para poder
    // seguir probando la app sin tener que registrarse primero.
    final demoUser = AppUser(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Usuario Demo',
      email: email,
      role: UserRole.exportador,
    );
    _usersByEmail[email.toLowerCase()] = demoUser;
    return _session = demoUser;
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
    if (role == UserRole.staff) {
      throw const RepositoryException('Solo puedes registrarte como exportador o importador.');
    }
    if (_usersByEmail.containsKey(email.toLowerCase())) {
      throw const RepositoryException('Ya existe una cuenta con ese correo.');
    }
    final user = AppUser(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
      companyName: companyName,
      country: country,
    );
    _usersByEmail[email.toLowerCase()] = user;
    return _session = user;
  }

  @override
  Future<AppUser?> restoreSession() async => _session;

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _session = null;
  }
}
