import '../../models/admin_permission.dart';
import '../../models/user_warning.dart';
import 'repository_exception.dart';

/// REQ-33: acciones del panel de administrador sobre cuentas.
///
/// * [inviteStaff] y [deleteUser] van por la Edge Function `admin-users`
///   (necesitan la clave service_role, que nunca va en la app).
/// * Las advertencias van por las RPC `warn_user` / `acknowledge_warning`.
///   A las [maxWarningsBeforeSuspension] advertencias la cuenta se suspende sola.
///
/// Todos los métodos lanzan [RepositoryException] con el motivo.
abstract class ModerationRepository {
  /// Invita por correo a un empleado nuevo (crea su propia contraseña desde el
  /// enlace). Requiere `employeeManagement`; un admin normal solo otorga
  /// permisos que él mismo tiene.
  Future<StaffInvitation> inviteStaff({
    required String email,
    String? name,
    List<AdminPermission> permissions = const [],
    bool isSuperAdmin = false,
  });

  /// Borra una cuenta (requiere `userManagement`). No se permite si tiene
  /// tratos confirmados: en ese caso hay que bloquearla.
  Future<void> deleteUser(String userId);

  /// Advierte a un exportador o importador (requiere `userManagement`). Si
  /// viene de un reporte, pasar [reportId] para marcarlo como atendido.
  Future<WarningResult> warnUser(String userId, String reason, {String? reportId});

  /// Admin: advertencias de un usuario, de la más reciente a la más antigua.
  Future<List<UserWarning>> fetchUserWarnings(String userId);

  /// Advertencias del usuario actual (para mostrarle un aviso al entrar).
  Future<List<UserWarning>> fetchMyWarnings();

  /// El usuario marca una advertencia como leída.
  Future<UserWarning> acknowledgeWarning(String warningId);
}

/// Implementación en memoria (UI y pruebas). Replica las reglas de la BD y de
/// la Edge Function: [currentUserId] es quien actúa y [permissions] sus
/// permisos de staff (vacío = usuario normal).
class MockModerationRepository implements ModerationRepository {
  MockModerationRepository({
    this.currentUserId = 'demo-admin',
    Set<AdminPermission>? permissions,
    this.isSuperAdmin = false,
  }) : permissions = permissions ?? {};

  String currentUserId;
  Set<AdminPermission> permissions;
  bool isSuperAdmin;

  /// Usuarios con tratos confirmados (no se pueden borrar).
  final Set<String> usersWithConfirmedDeals = {};

  /// Usuarios suspendidos (automática o manualmente).
  final Set<String> blockedUsers = {};

  final List<UserWarning> _warnings = [];
  final Set<String> _deletedUsers = {};
  final Set<String> _staffEmails = {};
  int _nextId = 1;

  bool _can(AdminPermission p) => isSuperAdmin || permissions.contains(p);

  void _require(AdminPermission p) {
    if (!_can(p)) throw RepositoryException('Requiere el permiso ${p.name}.');
  }

  @override
  Future<StaffInvitation> inviteStaff({
    required String email,
    String? name,
    List<AdminPermission> permissions = const [],
    bool isSuperAdmin = false,
  }) async {
    _require(AdminPermission.employeeManagement);
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      throw const RepositoryException('El correo del empleado no es válido.');
    }
    if (!this.isSuperAdmin) {
      if (isSuperAdmin) {
        throw const RepositoryException('Solo un super admin puede crear otro super admin.');
      }
      final notOwned = permissions.where((p) => !this.permissions.contains(p));
      if (notOwned.isNotEmpty) {
        throw RepositoryException(
            'No puedes otorgar permisos que no tienes: ${notOwned.map((p) => p.name).join(', ')}.');
      }
    }
    if (!isSuperAdmin && permissions.isEmpty) {
      throw const RepositoryException('Asigna al menos un permiso al empleado.');
    }
    if (!_staffEmails.add(normalized)) {
      throw const RepositoryException(
          'Ese correo ya tiene una cuenta en AgroTrade. Usa otro correo para el empleado.');
    }
    return StaffInvitation(
      userId: 'staff-${_nextId++}',
      email: normalized,
      permissions: permissions.map((p) => p.name).toSet().toList(),
      isSuperAdmin: isSuperAdmin,
    );
  }

  @override
  Future<void> deleteUser(String userId) async {
    _require(AdminPermission.userManagement);
    if (userId == currentUserId) {
      throw const RepositoryException('No puedes borrar tu propia cuenta.');
    }
    if (usersWithConfirmedDeals.contains(userId)) {
      throw const RepositoryException(
          'El usuario tiene tratos confirmados que forman parte del historial. Bloquéalo en lugar de borrarlo.');
    }
    _deletedUsers.add(userId);
    _warnings.removeWhere((w) => w.userId == userId);
  }

  @override
  Future<WarningResult> warnUser(String userId, String reason, {String? reportId}) async {
    _require(AdminPermission.userManagement);
    if (userId == currentUserId) {
      throw const RepositoryException('No puedes advertirte a ti mismo.');
    }
    if (_deletedUsers.contains(userId)) {
      throw const RepositoryException('El usuario no existe.');
    }
    if (reason.trim().length < 5) {
      throw const RepositoryException('Escribe el motivo de la advertencia (mínimo 5 caracteres).');
    }
    final warning = UserWarning(
      id: 'warn-${_nextId++}',
      userId: userId,
      reason: reason.trim(),
      reportId: reportId,
      issuedBy: currentUserId,
      createdAt: DateTime.now(),
    );
    _warnings.add(warning);
    final count = _warnings.where((w) => w.userId == userId).length;
    final autoBlocked =
        count >= maxWarningsBeforeSuspension && blockedUsers.add(userId);
    return WarningResult(warningId: warning.id, warningsCount: count, autoBlocked: autoBlocked);
  }

  @override
  Future<List<UserWarning>> fetchUserWarnings(String userId) async {
    _require(AdminPermission.userManagement);
    return _warnings.where((w) => w.userId == userId).toList().reversed.toList();
  }

  @override
  Future<List<UserWarning>> fetchMyWarnings() async {
    return _warnings.where((w) => w.userId == currentUserId).toList().reversed.toList();
  }

  @override
  Future<UserWarning> acknowledgeWarning(String warningId) async {
    final index =
        _warnings.indexWhere((w) => w.id == warningId && w.userId == currentUserId);
    if (index == -1) throw const RepositoryException('La advertencia no existe.');
    final w = _warnings[index];
    final acknowledged = UserWarning(
      id: w.id,
      userId: w.userId,
      reason: w.reason,
      reportId: w.reportId,
      issuedBy: w.issuedBy,
      createdAt: w.createdAt,
      acknowledgedAt: w.acknowledgedAt ?? DateTime.now(),
    );
    _warnings[index] = acknowledged;
    return acknowledged;
  }
}
