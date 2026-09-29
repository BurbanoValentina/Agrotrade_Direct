import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/repository_exception.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

/// Maneja el estado de sesión: usuario actual, carga y errores.
///
/// Se inyecta un [AuthRepository] para que este provider no sepa de dónde
/// vienen los datos. [initialUser] es la sesión restaurada al abrir la app
/// (ver `main.dart`), así el usuario no tiene que iniciar sesión cada vez.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository, {AppUser? initialUser}) : _currentUser = initialUser;

  // Instancia del repositorio de autenticación inyectado (Inversión de Dependencias)
  final AuthRepository _repository;

  // Variables privadas para el manejo del estado interno
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters públicos (Encapsulamiento): Exponen acceso de solo lectura al estado
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  /// Motivo del último error (ej. "Correo o contraseña incorrectos.").
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  /// REQ-04: Ejecuta el inicio de sesión contra el repositorio de datos.
  /// Retorna `true` si la autenticación fue exitosa o `false` si falló.
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      // Petición asíncrona al repositorio para obtener el usuario
      _currentUser = await _repository.login(email: email, password: password);
      _errorMessage = null; // Limpia errores previos si la llamada es exitosa
      return true;
    } catch (e) {
      // Captura excepciones y establece el mensaje de error para la UI
      _errorMessage = 'No pudimos iniciar sesión. Intenta de nuevo.';
      return false;
    } finally {
      // Garantiza que el estado de carga cambie a false independientemente del resultado
      _setLoading(false);
    }
  Future<bool> login(String email, String password) {
    return _run(
      () => _repository.login(email: email, password: password),
      fallbackError: 'No pudimos iniciar sesión. Intenta de nuevo.',
    );
  }

  /// REQ-02 / REQ-03: Registra un nuevo usuario en la plataforma.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
    String? country,
  }) {
    return _run(
      () => _repository.register(
        name: name,
        email: email,
        password: password,
        role: role,
        companyName: companyName,
        country: country,
      ),
      fallbackError: 'No pudimos crear la cuenta. Intenta de nuevo.',
    );
  }

  /// Cambia la contraseña (REQ-43, y primer ingreso de empleados invitados:
  /// ver [AppUser.mustSetPassword]). Devuelve `false` con [errorMessage].
  Future<bool> changePassword(String newPassword) async {
    _setLoading(true);
    try {
      await _repository.changePassword(newPassword);
      _currentUser = _currentUser?.copyWith(mustSetPassword: false);
      _errorMessage = null;
      return true;
    } on RepositoryException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cierra la sesión activa y limpia los datos del usuario.
  /// Vuelve a leer la sesión guardada (ej. al volver a la app).
  Future<void> restoreSession() async {
    try {
      _currentUser = await _repository.restoreSession();
    } on RepositoryException catch (e) {
      _errorMessage = e.message;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } on RepositoryException catch (e) {
      _errorMessage = e.message;
    }
    _currentUser = null;
    notifyListeners(); // Notifica a los escuchas para redibujar la UI al cerrar sesión
  }

  /// Método privado para actualizar la bandera de carga y notificar a los oyentes.
  Future<bool> _run(Future<AppUser> Function() action, {required String fallbackError}) async {
    _setLoading(true);
    try {
      _currentUser = await action();
      _errorMessage = null;
      return true;
    } on RepositoryException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      debugPrint('Error inesperado de autenticación: $e');
      _errorMessage = fallbackError;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners(); // Dispara el rediseño de widgets asociados a context.watch()
  }
}