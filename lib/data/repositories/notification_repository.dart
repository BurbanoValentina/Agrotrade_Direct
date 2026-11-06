import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_notification.dart';
import 'repository_exception.dart';
import 'supabase_error_mapper.dart';

/// REQ-20 / REQ-49: bandeja de notificaciones y preferencias de alertas.
///
/// Las notificaciones las crea la base de datos (migración
/// 20261105030000_notifications_shipping y 20261105040000_weather_alerts):
/// cambios de negociación, pasos del envío y alertas de clima.
abstract class NotificationRepository {
  /// Notificaciones del usuario, de la más reciente a la más antigua.
  Future<List<AppNotification>> fetchNotifications({int limit = 50});

  /// Cuántas notificaciones sin leer tiene el usuario (para el globo del ícono).
  Future<int> unreadCount();

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead();

  Future<void> deleteNotification(String notificationId);

  /// Notificaciones nuevas en tiempo real (Supabase Realtime). Cancelar la
  /// suscripción cierra el canal.
  Stream<AppNotification> watchNew();

  Future<AlertPreferences> fetchPreferences();

  Future<AlertPreferences> savePreferences(AlertPreferences preferences);
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw const RepositoryException('Debes iniciar sesión.');
    return user.id;
  }

  @override
  Future<List<AppNotification>> fetchNotifications({int limit = 50}) async {
    _userId;
    try {
      final rows = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List<dynamic>)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<int> unreadCount() async {
    _userId;
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .isFilter('read_at', null)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    _userId;
    try {
      await _supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId)
          .isFilter('read_at', null);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final userId = _userId;
    try {
      await _supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .isFilter('read_at', null);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    _userId;
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Stream<AppNotification> watchNew() {
    final userId = _userId;
    late final RealtimeChannel channel;
    final controller = StreamController<AppNotification>(
      onCancel: () => _supabase.removeChannel(channel),
    );
    channel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) =>
              controller.add(AppNotification.fromJson(payload.newRecord)),
        )
        .subscribe();
    return controller.stream;
  }

  @override
  Future<AlertPreferences> fetchPreferences() async {
    final userId = _userId;
    try {
      final row = await _supabase
          .from('alert_preferences')
          .select('weather_alerts, shipping_alerts')
          .eq('user_id', userId)
          .maybeSingle();
      return AlertPreferences.fromJson(row);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<AlertPreferences> savePreferences(AlertPreferences preferences) async {
    final userId = _userId;
    try {
      final row = await _supabase
          .from('alert_preferences')
          .upsert({
            'user_id': userId,
            'weather_alerts': preferences.weatherAlerts,
            'shipping_alerts': preferences.shippingAlerts,
          })
          .select('weather_alerts, shipping_alerts')
          .single();
      return AlertPreferences.fromJson(row);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }
}

/// Bandeja en memoria para la UI sin conexión y las pruebas. [deliver] simula
/// una notificación creada por la base de datos (respeta las preferencias).
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({this.currentUserId = 'demo-user', List<AppNotification>? initial})
      : _items = [...?initial];

  String currentUserId;
  final List<AppNotification> _items;
  final _controller = StreamController<AppNotification>.broadcast();
  final Map<String, AlertPreferences> _preferences = {};
  int _nextId = 1;

  List<AppNotification> get _mine =>
      _items.where((n) => n.userId == currentUserId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Crea una notificación para [userId] como lo haría la base de datos.
  /// Devuelve null si el usuario apagó ese tipo de alerta.
  AppNotification? deliver({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) {
    final prefs = _preferences[userId] ?? const AlertPreferences();
    if ((type == NotificationType.clima && !prefs.weatherAlerts) ||
        (type == NotificationType.envio && !prefs.shippingAlerts)) {
      return null;
    }
    final notification = AppNotification(
      id: 'notif-${_nextId++}',
      userId: userId,
      type: type,
      title: title,
      body: body,
      data: data,
      createdAt: DateTime.now(),
    );
    _items.add(notification);
    if (userId == currentUserId) _controller.add(notification);
    return notification;
  }

  @override
  Future<List<AppNotification>> fetchNotifications({int limit = 50}) async =>
      _mine.take(limit).toList();

  @override
  Future<int> unreadCount() async => _mine.where((n) => !n.isRead).length;

  void _update(bool Function(AppNotification) where) {
    final now = DateTime.now();
    for (var i = 0; i < _items.length; i++) {
      final n = _items[i];
      if (n.userId == currentUserId && where(n)) _items[i] = n.markedRead(now);
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async =>
      _update((n) => n.id == notificationId);

  @override
  Future<void> markAllAsRead() async => _update((_) => true);

  @override
  Future<void> deleteNotification(String notificationId) async =>
      _items.removeWhere((n) => n.id == notificationId && n.userId == currentUserId);

  @override
  Stream<AppNotification> watchNew() =>
      _controller.stream.where((n) => n.userId == currentUserId);

  @override
  Future<AlertPreferences> fetchPreferences() async =>
      _preferences[currentUserId] ?? const AlertPreferences();

  @override
  Future<AlertPreferences> savePreferences(AlertPreferences preferences) async =>
      _preferences[currentUserId] = preferences;
}
