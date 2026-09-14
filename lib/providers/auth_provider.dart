import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

/// Maneja el estado de sesión: usuario actual, carga y errores.
///
/// Se inyecta un [AuthRepository] (mock hoy, Supabase mañana) para que este
/// provider no sepa de dónde vienen los datos.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  // Instancia del repositorio de autenticación inyectado (Inversión de Dependencias)
  final AuthRepository _repository;

  // Variables privadas para el manejo del estado interno
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters públicos (Encapsulamiento): Exponen acceso de solo lectura al estado
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
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
  }

  /// REQ-02 / REQ-03: Registra un nuevo usuario en la plataforma.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
    String? country,
  }) async {
    _setLoading(true);
    try {
      _currentUser = await _repository.register(
        name: name,
        email: email,
        password: password,
        role: role,
        companyName: companyName,
        country: country,
      );
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'No pudimos crear la cuenta. Intenta de nuevo.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cierra la sesión activa y limpia los datos del usuario.
  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    notifyListeners(); // Notifica a los escuchas para redibujar la UI al cerrar sesión
  }

  /// Método privado para actualizar la bandera de carga y notificar a los oyentes.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners(); // Dispara el rediseño de widgets asociados a context.watch()
  }
}