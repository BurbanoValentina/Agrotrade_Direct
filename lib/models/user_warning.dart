/// Máximo de advertencias antes de la suspensión automática (igual que la BD).
const int maxWarningsBeforeSuspension = 3;

/// Advertencia de un admin a un usuario (REQ-33).
class UserWarning {
  final String id;
  final String userId;
  final String reason;
  final String? reportId;
  final String? issuedBy;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;

  const UserWarning({
    required this.id,
    required this.userId,
    required this.reason,
    this.reportId,
    this.issuedBy,
    required this.createdAt,
    this.acknowledgedAt,
  });

  bool get isAcknowledged => acknowledgedAt != null;

  factory UserWarning.fromJson(Map<String, dynamic> json) {
    return UserWarning(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      reason: json['reason'] as String,
      reportId: json['report_id'] as String?,
      issuedBy: json['issued_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      acknowledgedAt: json['acknowledged_at'] == null
          ? null
          : DateTime.parse(json['acknowledged_at'] as String),
    );
  }
}

/// Resultado de advertir a un usuario.
class WarningResult {
  const WarningResult({
    required this.warningId,
    required this.warningsCount,
    required this.autoBlocked,
  });

  final String warningId;

  /// Advertencias acumuladas por el usuario (incluida esta).
  final int warningsCount;

  /// Si esta advertencia provocó la suspensión automática de la cuenta.
  final bool autoBlocked;

  factory WarningResult.fromJson(Map<String, dynamic> json) {
    return WarningResult(
      warningId: json['warning_id'] as String,
      warningsCount: (json['warnings_count'] as num).toInt(),
      autoBlocked: json['auto_blocked'] as bool,
    );
  }
}

/// Resultado de invitar a un empleado nuevo al panel admin.
class StaffInvitation {
  const StaffInvitation({
    required this.userId,
    required this.email,
    required this.permissions,
    required this.isSuperAdmin,
  });

  final String userId;
  final String email;
  final List<String> permissions;
  final bool isSuperAdmin;

  factory StaffInvitation.fromJson(Map<String, dynamic> json) {
    return StaffInvitation(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      permissions: (json['permissions'] as List<dynamic>).cast<String>(),
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
    );
  }
}
