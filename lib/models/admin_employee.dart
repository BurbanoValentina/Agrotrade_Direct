import 'admin_permission.dart';

/// Empleado interno de la plataforma con credenciales y permisos.
///
/// Las contraseñas son generadas automáticamente por el sistema cuando
/// el admin crea un nuevo empleado.
class AdminEmployee {
  final String id;
  final String name;
  final String email;
  final String password;
  final List<AdminPermission> permissions;
  final bool isSuperAdmin;
  final bool isManager;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  const AdminEmployee({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.permissions,
    this.isSuperAdmin = false,
    this.isManager = false,
    this.isActive = true,
    required this.createdAt,
    required this.createdBy,
  });

  /// Un Super Admin tiene todos los permisos sin importar su lista.
  bool hasPermission(AdminPermission permission) {
    if (isSuperAdmin) return true;
    if (isManager) {
      return permission == AdminPermission.dashboard ||
          permission == AdminPermission.reports;
    }
    return permissions.contains(permission);
  }

  AdminEmployee copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    List<AdminPermission>? permissions,
    bool? isSuperAdmin,
    bool? isManager,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return AdminEmployee(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      permissions: permissions ?? this.permissions,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      isManager: isManager ?? this.isManager,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
