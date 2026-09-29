/// Rol del usuario dentro de la plataforma.
///
/// Corresponde a REQ-02 / REQ-03 del backlog: registro independiente para
/// exportador colombiano e importador europeo. [staff] es el personal del
/// panel de administración (REQ-24 / REQ-33): no se registra desde la app, se
/// asigna al agregarlo a `staff_members` en Supabase.
enum UserRole { exportador, importador, staff }

/// Convierte el texto de la BD (`profiles.role`) en [UserRole].
/// Cualquier valor desconocido se trata como importador (igual que la BD).
UserRole parseUserRole(String? value) {
  return UserRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => UserRole.importador,
  );
}

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.exportador:
        return 'Exportador · Colombia';
      case UserRole.importador:
        return 'Importador · UE';
      case UserRole.staff:
        return 'Equipo AgroTrade';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.exportador:
        return 'Exportador';
      case UserRole.importador:
        return 'Importador';
      case UserRole.staff:
        return 'Staff';
    }
  }
}
