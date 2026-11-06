/// Tipo de notificación (mismos valores que `notifications.type`).
///
/// * [negociacion]: solicitudes, contraofertas, aceptación, confirmación,
///   rechazo o cancelación (REQ-20). Siempre se entregan.
/// * [envio]: avance del envío de un trato confirmado (REQ-49).
/// * [clima]: alerta climática en la región de origen (REQ-48 / REQ-49).
enum NotificationType { negociacion, envio, clima, sistema }

extension NotificationTypeLabel on NotificationType {
  String get label => switch (this) {
        NotificationType.negociacion => 'Negociación',
        NotificationType.envio => 'Envío',
        NotificationType.clima => 'Clima',
        NotificationType.sistema => 'Sistema',
      };
}

/// Notificación de la bandeja del usuario. Solo la base de datos las crea;
/// la app las lee, las marca como leídas o las borra.
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;

  /// Datos para navegar: `negotiation_id`, `offer_id`, `region_id`,
  /// `shipping_status`, `kind`, ...
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  /// Negociación relacionada (para abrirla en My Deals), si la hay.
  String? get negotiationId => data['negotiation_id'] as String?;

  /// Región de clima relacionada, si la hay.
  String? get regionId => data['region_id'] as String?;

  AppNotification markedRead(DateTime at) => AppNotification(
        id: id,
        userId: userId,
        type: type,
        title: title,
        body: body,
        data: data,
        readAt: readAt ?? at,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.sistema,
      ),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Preferencias de alertas del usuario (pantalla de Configuración, REQ-43).
/// Sin fila en la base de datos, todo está encendido.
class AlertPreferences {
  final bool weatherAlerts;
  final bool shippingAlerts;

  const AlertPreferences({this.weatherAlerts = true, this.shippingAlerts = true});

  AlertPreferences copyWith({bool? weatherAlerts, bool? shippingAlerts}) => AlertPreferences(
        weatherAlerts: weatherAlerts ?? this.weatherAlerts,
        shippingAlerts: shippingAlerts ?? this.shippingAlerts,
      );

  factory AlertPreferences.fromJson(Map<String, dynamic>? json) => AlertPreferences(
        weatherAlerts: json?['weather_alerts'] as bool? ?? true,
        shippingAlerts: json?['shipping_alerts'] as bool? ?? true,
      );
}
