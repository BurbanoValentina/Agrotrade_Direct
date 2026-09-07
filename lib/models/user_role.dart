/// Rol del usuario dentro de la plataforma.
///
/// Corresponde a REQ-02 / REQ-03 del backlog: registro independiente para
/// exportador colombiano e importador europeo.
enum UserRole { exportador, importador }

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.exportador:
        return 'Exportador · Colombia';
      case UserRole.importador:
        return 'Importador · UE';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.exportador:
        return 'Exportador';
      case UserRole.importador:
        return 'Importador';
    }
  }
}
