import 'dart:math';

import '../../models/admin_employee.dart';
import '../../models/admin_permission.dart';
import '../../models/app_user.dart';
import '../../models/blocked_user.dart';
import '../../models/crop_offer.dart';
import '../../models/negotiation.dart';
import '../../models/suspicious_activity.dart';
import '../mock/mock_admin_data.dart';
import '../mock/mock_data.dart';

/// Contrato del repositorio de administración.
abstract class AdminRepository {
  Future<AdminEmployee?> loginEmployee(String email, String password);
  Future<List<AdminEmployee>> getEmployees();
  Future<AdminEmployee> createEmployee(String name, String email, String createdBy);
  Future<void> updateEmployee(AdminEmployee employee);
  Future<void> deleteEmployee(String id);

  Future<List<AppUser>> getRegisteredUsers();
  Future<void> deleteUser(String userId);

  Future<List<BlockedUser>> getBlockedUsers();
  Future<void> blockUser(BlockedUser blocked);
  Future<void> unblockUser(String userId);
  bool isUserBlocked(String email);

  Future<List<SuspiciousActivity>> getSuspiciousActivities();
  Future<void> updateActivityStatus(String id, AlertStatus status);

  Future<List<CropOffer>> getOffers();
  Future<void> deleteOffer(String offerId);

  Future<List<Negotiation>> getNegotiations();

  Future<DashboardStats> getDashboardStats();

  Future<PlatformConfig> getPlatformConfig();
  Future<void> updatePlatformConfig(PlatformConfig config);
}

/// Implementación mock en memoria para desarrollo de la UI.
class MockAdminRepository implements AdminRepository {
  final List<AdminEmployee> _employees = List.from(mockEmployees);
  final List<AppUser> _users = List.from(mockRegisteredUsers);
  final List<BlockedUser> _blockedUsers = List.from(mockBlockedUsers);
  final List<SuspiciousActivity> _alerts = List.from(mockAlerts);
  final List<CropOffer> _offers = List.from(mockOffers);
  final List<Negotiation> _negotiations = List.from(mockNegotiations);
  PlatformConfig _config = defaultPlatformConfig;

  static final _random = Random();

  /// Genera una contraseña aleatoria segura de 10 caracteres.
  static String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';
    const special = '#\$@!%&*';

    final buffer = StringBuffer();
    buffer.write(upper[_random.nextInt(upper.length)]);
    buffer.write(chars[_random.nextInt(chars.length)]);
    buffer.write(chars[_random.nextInt(chars.length)]);
    buffer.write(digits[_random.nextInt(digits.length)]);
    buffer.write(special[_random.nextInt(special.length)]);
    for (var i = 0; i < 5; i++) {
    const all = chars + upper + digits;
      buffer.write(all[_random.nextInt(all.length)]);
    }
    return buffer.toString();
  }

  @override
  Future<AdminEmployee?> loginEmployee(String email, String password) async {
    final employee = _employees.where(
      (e) =>
          e.email.toLowerCase() == email.toLowerCase() &&
          e.password == password &&
          e.isActive,
    );
    return employee.isNotEmpty ? employee.first : null;
  }

  @override
  Future<List<AdminEmployee>> getEmployees() async {
    return List.from(_employees);
  }

  @override
  Future<AdminEmployee> createEmployee(
      String name, String email, String createdBy) async {
    final employee = AdminEmployee(
      id: 'emp-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      password: _generatePassword(),
      permissions: const [AdminPermission.dashboard],
      isSuperAdmin: false,
      isActive: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    _employees.add(employee);
    return employee;
  }

  @override
  Future<void> updateEmployee(AdminEmployee employee) async {
    final index = _employees.indexWhere((e) => e.id == employee.id);
    if (index != -1) {
      _employees[index] = employee;
    }
  }

  @override
  Future<void> deleteEmployee(String id) async {
    _employees.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<AppUser>> getRegisteredUsers() async {
    return List.from(_users);
  }

  @override
  Future<void> deleteUser(String userId) async {
    _users.removeWhere((u) => u.id == userId);
  }

  @override
  Future<List<BlockedUser>> getBlockedUsers() async {
    return List.from(_blockedUsers);
  }

  @override
  Future<void> blockUser(BlockedUser blocked) async {
    _blockedUsers.add(blocked);
    _users.removeWhere((u) => u.id == blocked.userId);
  }

  @override
  Future<void> unblockUser(String userId) async {
    _blockedUsers.removeWhere((b) => b.userId == userId);
  }

  @override
  bool isUserBlocked(String email) {
    return _blockedUsers
        .any((b) => b.userEmail.toLowerCase() == email.toLowerCase());
  }

  @override
  Future<List<SuspiciousActivity>> getSuspiciousActivities() async {
    return List.from(_alerts);
  }

  @override
  Future<void> updateActivityStatus(String id, AlertStatus status) async {
    final index = _alerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(status: status);
    }
  }

  @override
  Future<List<CropOffer>> getOffers() async {
    return List.from(_offers);
  }

  @override
  Future<void> deleteOffer(String offerId) async {
    _offers.removeWhere((o) => o.id == offerId);
  }

  @override
  Future<List<Negotiation>> getNegotiations() async {
    return List.from(_negotiations);
  }

  @override
  Future<DashboardStats> getDashboardStats() async {
    final pendingAlerts =
        _alerts.where((a) => a.status == AlertStatus.pendiente).length;
    return DashboardStats(
      totalUsers: _users.length,
      activeOffers:
          _offers.where((o) => o.status == OfferStatus.activa).length,
      activeNegotiations: _negotiations
          .where((n) => n.status == NegotiationStatus.pendiente)
          .length,
      blockedUsers: _blockedUsers.length,
      pendingAlerts: pendingAlerts,
      totalVolumeMt: _offers.fold(0, (sum, o) => sum + o.volumeMt),
      totalValueUsd: _offers.fold(0, (sum, o) => sum + o.estimatedTotalUsd),
    );
  }

  @override
  Future<PlatformConfig> getPlatformConfig() async {
    return _config;
  }

  @override
  Future<void> updatePlatformConfig(PlatformConfig config) async {
    _config = config;
  }
}
