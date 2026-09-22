/// Tipos de actividad sospechosa detectada en la plataforma.
enum SuspiciousType {
  precioAnomalo,
  multiplesCuentas,
  patronInusual,
  intentoFraude,
}

extension SuspiciousTypeLabel on SuspiciousType {
  String get label {
    switch (this) {
      case SuspiciousType.precioAnomalo:
        return 'Precio Anómalo';
      case SuspiciousType.multiplesCuentas:
        return 'Múltiples Cuentas';
      case SuspiciousType.patronInusual:
        return 'Patrón Inusual';
      case SuspiciousType.intentoFraude:
        return 'Intento de Fraude';
    }
  }
}

/// Severidad de la alerta de actividad sospechosa.
enum AlertSeverity { baja, media, alta, critica }

extension AlertSeverityLabel on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.baja:
        return 'Baja';
      case AlertSeverity.media:
        return 'Media';
      case AlertSeverity.alta:
        return 'Alta';
      case AlertSeverity.critica:
        return 'Crítica';
    }
  }
}

/// Estado de una alerta de seguridad.
enum AlertStatus { pendiente, revisada, descartada, accionTomada }

extension AlertStatusLabel on AlertStatus {
  String get label {
    switch (this) {
      case AlertStatus.pendiente:
        return 'Pendiente';
      case AlertStatus.revisada:
        return 'Revisada';
      case AlertStatus.descartada:
        return 'Descartada';
      case AlertStatus.accionTomada:
        return 'Acción Tomada';
    }
  }
}

/// Alerta de actividad sospechosa detectada por la plataforma.
class SuspiciousActivity {
  final String id;
  final SuspiciousType type;
  final String description;
  final String relatedUserId;
  final String relatedUserName;
  final AlertSeverity severity;
  final AlertStatus status;
  final DateTime detectedAt;

  const SuspiciousActivity({
    required this.id,
    required this.type,
    required this.description,
    required this.relatedUserId,
    required this.relatedUserName,
    required this.severity,
    required this.status,
    required this.detectedAt,
  });

  SuspiciousActivity copyWith({
    String? id,
    SuspiciousType? type,
    String? description,
    String? relatedUserId,
    String? relatedUserName,
    AlertSeverity? severity,
    AlertStatus? status,
    DateTime? detectedAt,
  }) {
    return SuspiciousActivity(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      relatedUserId: relatedUserId ?? this.relatedUserId,
      relatedUserName: relatedUserName ?? this.relatedUserName,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }
}
