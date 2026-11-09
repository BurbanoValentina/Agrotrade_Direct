import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agrotrade_direct/data/repositories/notification_repository.dart';
import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/data/repositories/weather_repository.dart';
import 'package:agrotrade_direct/models/app_notification.dart';
import 'package:agrotrade_direct/models/crop_offer.dart';
import 'package:agrotrade_direct/models/purchase_request.dart';
import 'package:agrotrade_direct/models/weather.dart';

const _seller = MockOfferRepository.demoSellerId;
const _buyer = MockOfferRepository.demoBuyerId;

Matcher _rejectedWith(String part) => throwsA(
    isA<RepositoryException>().having((e) => e.message, 'message', contains(part)));

/// Trato confirmado por ambas partes en el mock (15 MT de una oferta de 20).
Future<(MockOfferRepository, PurchaseRequest)> _confirmedDeal() async {
  final repo = MockOfferRepository(currentUserId: _seller);
  final offer = await repo.publishOffer(CropOffer(
    id: 'tmp',
    cropType: CropType.cafe,
    variety: 'Geisha',
    originRegion: 'Huila',
    originCountry: 'Colombia',
    askPricePerMt: 8400,
    volumeMt: 20,
    destinationCountry: 'Alemania',
    certifications: const [],
    sellerName: 'Exportador Demo',
    sellerRating: 5,
    sellerTrades: 0,
    status: OfferStatus.activa,
    postedAt: DateTime(2026, 11, 5),
  ));
  repo.currentUserId = _buyer;
  await repo.sendCounterOffer(offerId: offer.id, proposedPricePerMt: 8300, volumeMt: 15);
  final neg = (await repo.fetchMyNegotiations()).single;
  repo.currentUserId = _seller;
  await repo.acceptPurchaseRequest(neg.id);
  await repo.confirmNegotiation(neg.id);
  repo.currentUserId = _buyer;
  final confirmed = await repo.confirmNegotiation(neg.id);
  return (repo, confirmed);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('REQ-49: estado del envío', () {
    test('el exportador avanza el envío y el importador confirma la entrega', () async {
      final (repo, deal) = await _confirmedDeal();
      expect(deal.nextShippingStep, ShippingStatus.preparando);
      expect(deal.canAdvanceShipping(_seller), isTrue);
      expect(deal.canAdvanceShipping(_buyer), isFalse);

      repo.currentUserId = _seller;
      var updated = await repo.updateShippingStatus(deal.id, ShippingStatus.preparando);
      expect(updated.shippingStatus, ShippingStatus.preparando);
      updated = await repo.updateShippingStatus(deal.id, ShippingStatus.enPuerto,
          note: 'Contenedor MSCU1234567');
      expect(updated.nextShippingStep, ShippingStatus.entregado);
      expect(updated.canAdvanceShipping(_buyer), isTrue);

      repo.currentUserId = _buyer;
      updated = await repo.updateShippingStatus(deal.id, ShippingStatus.entregado);
      expect(updated.shippingStatus, ShippingStatus.entregado);
      expect(updated.nextShippingStep, isNull);
    });

    test('mismas reglas y mensajes que la base de datos', () async {
      final (repo, deal) = await _confirmedDeal();
      // await: el mock lee currentUserId al ejecutarse, no al llamarse.
      repo.currentUserId = _buyer;
      await expectLater(repo.updateShippingStatus(deal.id, ShippingStatus.preparando),
          _rejectedWith('Solo el exportador'));
      await expectLater(repo.updateShippingStatus(deal.id, ShippingStatus.entregado),
          _rejectedWith('aún no ha sido embarcada'));

      repo.currentUserId = _seller;
      await expectLater(repo.updateShippingStatus(deal.id, ShippingStatus.entregado),
          _rejectedWith('Solo el importador'));
      await repo.updateShippingStatus(deal.id, ShippingStatus.embarcado);
      await expectLater(repo.updateShippingStatus(deal.id, ShippingStatus.preparando),
          _rejectedWith('solo puede avanzar'));
    });

    test('no hay envío en un trato sin confirmar', () async {
      final neg = PurchaseRequest(
        id: 'n1',
        offerId: 'o1',
        buyerId: _buyer,
        sellerId: _seller,
        proposedPricePerMt: 8000,
        requestedVolumeMt: 10,
        status: NegotiationStatus.accepted,
        createdAt: DateTime(2026, 11, 5),
        updatedAt: DateTime(2026, 11, 5),
      );
      expect(neg.nextShippingStep, isNull);
      expect(() => validateShippingUpdate(neg, ShippingStatus.preparando, _seller),
          _rejectedWith('tratos confirmados'));
    });

    test('lee shipping_status de Supabase (en_puerto)', () {
      final neg = PurchaseRequest.fromJson({
        'id': 'n1',
        'offer_id': 'o1',
        'buyer_id': _buyer,
        'seller_id': _seller,
        'proposed_price_per_mt': 8000,
        'requested_volume_mt': 10,
        'status': 'confirmed',
        'created_at': '2026-11-05T10:00:00Z',
        'updated_at': '2026-11-05T10:00:00Z',
        'shipping_status': 'en_puerto',
        'shipping_updated_at': '2026-11-06T10:00:00Z',
      });
      expect(neg.shippingStatus, ShippingStatus.enPuerto);
      expect(neg.shippingStatus!.dbValue, 'en_puerto');
      expect(neg.shippingStatus!.label, 'En puerto de destino');
    });
  });

  group('REQ-20 / REQ-49: notificaciones', () {
    test('fromJson con datos para navegar y tipo desconocido como sistema', () {
      final n = AppNotification.fromJson({
        'id': 'x1',
        'user_id': 'u1',
        'type': 'envio',
        'title': 'Actualización de envío',
        'body': 'Geisha (15 MT): Embarcado.',
        'data': {'negotiation_id': 'n1', 'shipping_status': 'embarcado'},
        'read_at': null,
        'created_at': '2026-11-06T10:00:00Z',
      });
      expect(n.type, NotificationType.envio);
      expect(n.negotiationId, 'n1');
      expect(n.isRead, isFalse);
      expect(AppNotification.fromJson({'id': 'x2', 'type': 'otro', 'created_at': '2026-11-06T10:00:00Z'}).type,
          NotificationType.sistema);
    });

    test('la bandeja respeta preferencias, cuenta y marca leídas', () async {
      final repo = MockNotificationRepository(currentUserId: 'u1');
      final live = <AppNotification>[];
      final sub = repo.watchNew().listen(live.add);

      await repo.savePreferences(const AlertPreferences(weatherAlerts: false));
      expect(repo.deliver(userId: 'u1', type: NotificationType.clima, title: 'Alerta de helada', body: '...'),
          isNull);
      repo.deliver(userId: 'u1', type: NotificationType.envio, title: 'Actualización de envío', body: '...');
      repo.deliver(userId: 'u1', type: NotificationType.negociacion, title: 'Nueva contraoferta', body: '...');
      repo.deliver(userId: 'u2', type: NotificationType.negociacion, title: 'De otro usuario', body: '...');
      await Future<void>.delayed(Duration.zero);

      expect(await repo.unreadCount(), 2);
      expect(live.map((n) => n.title), ['Actualización de envío', 'Nueva contraoferta']);
      await repo.markAllAsRead();
      expect(await repo.unreadCount(), 0);
      expect((await repo.fetchNotifications()).length, 2);
      await sub.cancel();
    });

    test('sin preferencias guardadas, todo encendido', () {
      final prefs = AlertPreferences.fromJson(null);
      expect(prefs.weatherAlerts, isTrue);
      expect(prefs.shippingAlerts, isTrue);
    });
  });

  group('REQ-48: clima', () {
    test('lee la respuesta de la Edge Function weather', () {
      final forecast = WeatherForecast.fromJson({
        'region': {'id': 'huila', 'name': 'Huila', 'department': 'Huila', 'latitude': 1.85, 'longitude': -76.05},
        'forecast': {
          'daily': {
            'time': ['2026-11-06', '2026-11-07'],
            'weather_code': [61, 0],
            'temperature_2m_max': [26.4, 28.1],
            'temperature_2m_min': [14.2, 15],
            'precipitation_sum': [62.3, 0],
            'wind_speed_10m_max': [18, 12.5],
          },
        },
        'fetched_at': '2026-11-06T12:00:00Z',
        'cached': true,
        'stale': false,
      });
      expect(forecast.region.name, 'Huila');
      expect(forecast.days, hasLength(2));
      expect(forecast.days.first.precipitationMm, 62.3);
      expect(forecast.days.first.description, 'Lluvia');
      expect(forecast.days.last.description, 'Despejado');
      expect(forecast.cached, isTrue);
    });

    test('alerta de clima con su tipo', () {
      final alert = WeatherAlert.fromJson({
        'id': 'a1',
        'region_id': 'huila',
        'alert_date': '2026-11-07',
        'kind': 'calor_extremo',
        'value': 36,
        'threshold': 35,
        'message': 'Calor extremo en Huila el 07/11: máxima de 36 °C.',
        'created_at': '2026-11-06T12:00:00Z',
      });
      expect(alert.kind, WeatherAlertKind.calorExtremo);
      expect(alert.kind.label, 'Calor extremo');
    });

    test('solo el personal autorizado lanza la revisión de alertas', () async {
      final repo = MockWeatherRepository();
      expect(repo.runAlertCheck(), _rejectedWith('permiso de configuración'));
      repo.canRunAlertCheck = true;
      expect((await repo.runAlertCheck())['alerts_created'], 1);
      expect((await repo.fetchForecast('huila')).days, hasLength(7));
    });
  });
}
