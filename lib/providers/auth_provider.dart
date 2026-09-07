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

  final AuthRepository _repository;

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      _currentUser = await _repository.login(email: email, password: password);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'No pudimos iniciar sesión. Intenta de nuevo.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

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

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
