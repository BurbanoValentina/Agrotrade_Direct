import 'package:flutter/foundation.dart';

import '../data/mock/mock_admin_data.dart';
import '../data/repositories/admin_repository.dart';
import '../models/admin_employee.dart';
import '../models/admin_permission.dart';
import '../models/app_user.dart';
import '../models/blocked_user.dart';
import '../models/crop_offer.dart';
import '../models/negotiation.dart';
import '../models/suspicious_activity.dart';

/// Provider principal del Panel de Administración.
///
/// Maneja el estado de sesión del empleado, CRUD de empleados y usuarios,
/// alertas de seguridad, bloqueo de perfiles, y configuración de plataforma.
class AdminProvider extends ChangeNotifier {
  AdminProvider(this._repository);

  final AdminRepository _repository;

  // ── Estado de sesión del empleado ─────────────────────────────────
  AdminEmployee? _currentEmployee;
  bool _isLoading = false;
  String? _errorMessage;

  AdminEmployee? get currentEmployee => _currentEmployee;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentEmployee != null;

  bool hasPermission(AdminPermission permission) {
    return _currentEmployee?.hasPermission(permission) ?? false;
  }

  bool get isSuperAdmin => _currentEmployee?.isSuperAdmin ?? false;

  // ── Datos cargados ────────────────────────────────────────────────
  List<AdminEmployee> _employees = [];
  List<AppUser> _users = [];
  List<BlockedUser> _blockedUsers = [];
  List<SuspiciousActivity> _alerts = [];
  List<CropOffer> _offers = [];
  List<Negotiation> _negotiations = [];
  DashboardStats? _stats;
  PlatformConfig _config = defaultPlatformConfig;

  List<AdminEmployee> get employees => _employees;
  List<AppUser> get users => _users;
  List<BlockedUser> get blockedUsers => _blockedUsers;
  List<SuspiciousActivity> get alerts => _alerts;
  List<CropOffer> get offers => _offers;
  List<Negotiation> get negotiations => _negotiations;
  DashboardStats? get stats => _stats;
  PlatformConfig get config => _config;

  int get pendingAlertsCount =>
      _alerts.where((a) => a.status == AlertStatus.pendiente).length;

  // ── Autenticación del empleado ────────────────────────────────────

  Future<bool> loginEmployee(String email, String password) async {
    _setLoading(true);
    try {
      _currentEmployee =
          await _repository.loginEmployee(email, password);
      if (_currentEmployee == null) {
        _errorMessage = 'Credenciales inválidas. Verifica tu correo y contraseña.';
        return false;
      }
      _errorMessage = null;
      // Cargar todos los datos iniciales
      await _loadAllData();
      return true;
    } catch (e) {
      _errorMessage = 'Error al iniciar sesión. Intenta de nuevo.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    _currentEmployee = null;
    _employees = [];
    _users = [];
    _blockedUsers = [];
    _alerts = [];
    _offers = [];
    _negotiations = [];
    _stats = null;
    notifyListeners();
  }

  // ── Carga de datos ────────────────────────────────────────────────

  Future<void> _loadAllData() async {
    _employees = await _repository.getEmployees();
    _users = await _repository.getRegisteredUsers();
    _blockedUsers = await _repository.getBlockedUsers();
    _alerts = await _repository.getSuspiciousActivities();
    _offers = await _repository.getOffers();
    _negotiations = await _repository.getNegotiations();
    _stats = await _repository.getDashboardStats();
    _config = await _repository.getPlatformConfig();
  }

  Future<void> refreshData() async {
    _setLoading(true);
    try {
      await _loadAllData();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshStats() async {
    _stats = await _repository.getDashboardStats();
    notifyListeners();
  }

  // ── CRUD de empleados ─────────────────────────────────────────────

  /// Crea un nuevo empleado con contraseña autogenerada.
  /// Devuelve el empleado creado (contiene la contraseña generada).
  Future<AdminEmployee?> createEmployee(String name, String email) async {
    _setLoading(true);
    try {
      final employee = await _repository.createEmployee(
        name,
        email,
        _currentEmployee?.name ?? 'Admin',
      );
      _employees = await _repository.getEmployees();
      _errorMessage = null;
      notifyListeners();
      return employee;
    } catch (e) {
      _errorMessage = 'Error al crear empleado.';
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateEmployeePermissions(
    String employeeId,
    List<AdminPermission> permissions,
    bool isSuperAdmin,
  ) async {
    final index = _employees.indexWhere((e) => e.id == employeeId);
    if (index == -1) return;

    final updated = _employees[index].copyWith(
      permissions: permissions,
      isSuperAdmin: isSuperAdmin,
    );
    await _repository.updateEmployee(updated);
    _employees[index] = updated;
    notifyListeners();
  }

  Future<void> toggleEmployeeActive(String employeeId) async {
    final index = _employees.indexWhere((e) => e.id == employeeId);
    if (index == -1) return;

    final updated =
        _employees[index].copyWith(isActive: !_employees[index].isActive);
    await _repository.updateEmployee(updated);
    _employees[index] = updated;
    notifyListeners();
  }

  Future<void> deleteEmployee(String employeeId) async {
    await _repository.deleteEmployee(employeeId);
    _employees.removeWhere((e) => e.id == employeeId);
    notifyListeners();
  }

  // ── Gestión de usuarios ───────────────────────────────────────────

  Future<void> deleteUser(String userId) async {
    await _repository.deleteUser(userId);
    _users.removeWhere((u) => u.id == userId);
    await refreshStats();
  }

  // ── Bloqueo de usuarios ───────────────────────────────────────────

  Future<void> blockUser(
    String userId,
    String userName,
    String userEmail,
    String reason,
  ) async {
    final blocked = BlockedUser(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      reason: reason,
      blockedAt: DateTime.now(),
      blockedBy: _currentEmployee?.name ?? 'Admin',
    );
    await _repository.blockUser(blocked);
    _blockedUsers.add(blocked);
    _users.removeWhere((u) => u.id == userId);
    await refreshStats();
  }

  Future<void> unblockUser(String userId) async {
    await _repository.unblockUser(userId);
    _blockedUsers.removeWhere((b) => b.userId == userId);
    await refreshStats();
  }

  bool isUserBlocked(String email) {
    return _repository.isUserBlocked(email);
  }

  // ── Alertas de seguridad ──────────────────────────────────────────

  Future<void> updateAlertStatus(String alertId, AlertStatus status) async {
    await _repository.updateActivityStatus(alertId, status);
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(status: status);
    }
    notifyListeners();
  }

  // ── Gestión de ofertas ────────────────────────────────────────────

  Future<void> deleteOffer(String offerId) async {
    await _repository.deleteOffer(offerId);
    _offers.removeWhere((o) => o.id == offerId);
    await refreshStats();
  }

  // ── Configuración de plataforma ───────────────────────────────────

  Future<void> updateConfig(PlatformConfig config) async {
    await _repository.updatePlatformConfig(config);
    _config = config;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
