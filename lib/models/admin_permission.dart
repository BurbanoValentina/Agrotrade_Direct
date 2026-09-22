/// Permisos granulares para empleados del panel de administración.
///
/// Cada permiso habilita una sección específica del panel admin.
/// Un Super Admin tiene todos los permisos automáticamente.
enum AdminPermission {
  dashboard,
  userManagement,
  employeeManagement,
  offerManagement,
  negotiationManagement,
  reports,
  settings,
  security,
}

extension AdminPermissionLabel on AdminPermission {
  String get label {
    switch (this) {
      case AdminPermission.dashboard:
        return 'Dashboard';
      case AdminPermission.userManagement:
        return 'Gestión de Usuarios';
      case AdminPermission.employeeManagement:
        return 'Gestión de Empleados';
      case AdminPermission.offerManagement:
        return 'Gestión de Ofertas';
      case AdminPermission.negotiationManagement:
        return 'Negociaciones';
      case AdminPermission.reports:
        return 'Reportes';
      case AdminPermission.settings:
        return 'Ajustes';
      case AdminPermission.security:
        return 'Seguridad';
    }
  }

  String get description {
    switch (this) {
      case AdminPermission.dashboard:
        return 'Ver estadísticas generales de la plataforma';
      case AdminPermission.userManagement:
        return 'Ver, activar/desactivar, eliminar y bloquear usuarios';
      case AdminPermission.employeeManagement:
        return 'Crear empleados, asignar permisos y otorgar Super Admin';
      case AdminPermission.offerManagement:
        return 'Ver, editar y eliminar ofertas del mercado';
      case AdminPermission.negotiationManagement:
        return 'Ver el estado de todas las negociaciones';
      case AdminPermission.reports:
        return 'Ver y generar reportes de la plataforma';
      case AdminPermission.settings:
        return 'Configurar parámetros de la plataforma';
      case AdminPermission.security:
        return 'Alertas de actividad sospechosa y bloqueo de perfiles';
    }
  }

  IconLabel get iconLabel {
    switch (this) {
      case AdminPermission.dashboard:
        return IconLabel.dashboard;
      case AdminPermission.userManagement:
        return IconLabel.people;
      case AdminPermission.employeeManagement:
        return IconLabel.badge;
      case AdminPermission.offerManagement:
        return IconLabel.storefront;
      case AdminPermission.negotiationManagement:
        return IconLabel.handshake;
      case AdminPermission.reports:
        return IconLabel.barChart;
      case AdminPermission.settings:
        return IconLabel.settings;
      case AdminPermission.security:
        return IconLabel.shield;
    }
  }
}

/// Helper para asociar íconos con permisos sin importar flutter/material.
enum IconLabel {
  dashboard,
  people,
  badge,
  storefront,
  handshake,
  barChart,
  settings,
  shield,
}
