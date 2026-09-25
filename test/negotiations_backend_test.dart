import 'package:flutter_test/flutter_test.dart';
import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/models/crop_offer.dart';
import 'package:agrotrade_direct/models/purchase_request.dart';

const _buyer = MockOfferRepository.demoBuyerId;
const _seller = MockOfferRepository.demoSellerId;

Matcher _rejectedWith(String messagePart) => throwsA(
    isA<RepositoryException>().having((e) => e.message, 'message', contains(messagePart)));

void main() {
  late MockOfferRepository repository;

  setUp(() {
    repository = MockOfferRepository();
  });

  /// El importador demo envía una solicitud y devuelve la negociación creada.
  Future<PurchaseRequest> request(String offerId, double price, {double? volume}) async {
    repository.currentUserId = _buyer;
    await repository.sendCounterOffer(
        offerId: offerId, proposedPricePerMt: price, volumeMt: volume);
    return (await repository.fetchMyNegotiations()).last;
  }

  Future<CropOffer> offer(String id) async =>
      (await repository.fetchOffers()).firstWhere((o) => o.id == id);

  group('REQ-14: Solicitud de compra', () {
    test('el importador envía una solicitud sin volumen (se pide todo)', () async {
      final neg = await request('off-001', 7800);

      expect(neg.offerId, 'off-001');
      expect(neg.proposedPricePerMt, 7800);
      expect(neg.status, NegotiationStatus.pending);
      expect(neg.requestedVolumeMt, 22, reason: 'volumen completo de off-001');
      expect(neg.roundCount, 1);
      expect(neg.isTurnOf(_seller), isTrue);
    });

    test('guarda volumen parcial y notas, y la oferta pasa a negociando', () async {
      await repository.sendCounterOffer(
        offerId: 'off-001',
        proposedPricePerMt: 8000,
        volumeMt: 10,
        notes: 'Entrega FOB Buenaventura',
      );

      final neg = (await repository.fetchMyNegotiations()).last;
      expect(neg.requestedVolumeMt, 10);
      expect(neg.notes, 'Entrega FOB Buenaventura');
      expect((await offer('off-001')).status, OfferStatus.negociando);
    });

    group('rechazos con mensaje claro', () {
      test('precio cero o negativo', () {
        expect(repository.sendCounterOffer(offerId: 'off-001', proposedPricePerMt: 0),
            _rejectedWith('precio propuesto debe ser mayor que cero'));
      });

      test('volumen cero', () {
        expect(
            repository.sendCounterOffer(
                offerId: 'off-001', proposedPricePerMt: 8000, volumeMt: 0),
            _rejectedWith('volumen solicitado debe ser mayor que cero'));
      });

      test('volumen mayor al disponible', () {
        expect(
            repository.sendCounterOffer(
                offerId: 'off-001', proposedPricePerMt: 8000, volumeMt: 99),
            _rejectedWith('supera el disponible'));
      });

      test('notas de más de 500 caracteres', () {
        expect(
            repository.sendCounterOffer(
                offerId: 'off-001', proposedPricePerMt: 8000, notes: 'x' * 501),
            _rejectedWith('500 caracteres'));
      });

      test('oferta que ya no recibe solicitudes', () {
        // off-004 está confirmada en los datos mock.
        expect(repository.sendCounterOffer(offerId: 'off-004', proposedPricePerMt: 5000),
            _rejectedWith('ya no recibe solicitudes'));
      });

      test('oferta inexistente', () {
        expect(repository.sendCounterOffer(offerId: 'no-existe', proposedPricePerMt: 5000),
            _rejectedWith('no existe'));
      });

      test('solicitud duplicada mientras la anterior sigue activa', () async {
        await request('off-001', 8000);
        await expectLater(
            repository.sendCounterOffer(offerId: 'off-001', proposedPricePerMt: 7900),
            _rejectedWith('Ya tienes una solicitud activa'));
      });

      test('se puede volver a solicitar si la anterior fue rechazada', () async {
        final first = await request('off-001', 8000);
        repository.currentUserId = _seller;
        await repository.rejectPurchaseRequest(first.id);

        await request('off-001', 8200);
        expect((await repository.fetchMyNegotiations()).length, 2);
      });
    });
  });

  group('REQ-15 / REQ-16: Contraofertas, aceptar y rechazar', () {
    test('ida y vuelta: cada contraoferta cambia el turno y suma una ronda', () async {
      final neg = await request('off-002', 6000, volume: 10);

      repository.currentUserId = _seller;
      var updated = await repository.counterOffer(
          negotiationId: neg.id, pricePerMt: 6150, message: 'Incluye empaque');
      expect(updated.status, NegotiationStatus.countered);
      expect(updated.roundCount, 2);
      expect(updated.isTurnOf(_buyer), isTrue);

      repository.currentUserId = _buyer;
      updated = await repository.counterOffer(negotiationId: neg.id, pricePerMt: 6100);
      expect(updated.status, NegotiationStatus.pending);
      expect(updated.roundCount, 3);
      expect(updated.proposedPricePerMt, 6100);

      final rounds = await repository.fetchNegotiationRounds(neg.id);
      expect(rounds.map((r) => r.pricePerMt), [6000, 6150, 6100]);
      expect(rounds[1].message, 'Incluye empaque');
      expect(rounds[1].proposedBy, _seller);
    });

    test('no se puede contraofertar ni aceptar fuera de turno', () async {
      final neg = await request('off-002', 6000);

      // Turno del exportador: el importador no puede actuar.
      expect(repository.counterOffer(negotiationId: neg.id, pricePerMt: 6100),
          _rejectedWith('No es tu turno'));
      expect(repository.acceptPurchaseRequest(neg.id), _rejectedWith('No es tu turno'));
    });

    test('un usuario ajeno no puede tocar la negociación', () async {
      final neg = await request('off-002', 6000);
      repository.currentUserId = 'otro-usuario';
      expect(repository.acceptPurchaseRequest(neg.id), _rejectedWith('no participas'));
    });

    test('límite de 10 rondas: después solo se puede aceptar', () async {
      final neg = await request('off-002', 5000, volume: 5);
      for (var round = 2; round <= maxNegotiationRounds; round++) {
        repository.currentUserId = round.isEven ? _seller : _buyer;
        await repository.counterOffer(negotiationId: neg.id, pricePerMt: 5000.0 + round * 50);
      }

      repository.currentUserId = _buyer; // la ronda 10 fue del exportador
      await expectLater(repository.counterOffer(negotiationId: neg.id, pricePerMt: 6000),
          _rejectedWith('límite de 10 rondas'));
      final accepted = await repository.acceptPurchaseRequest(neg.id);
      expect(accepted.status, NegotiationStatus.accepted);
      expect(accepted.roundCount, maxNegotiationRounds);
    });

    test('el exportador rechaza con motivo y la oferta vuelve a activa', () async {
      final neg = await request('off-003', 5000);
      repository.currentUserId = _seller;

      final rejected = await repository.rejectPurchaseRequest(neg.id,
          reason: 'Precio por debajo de los costos de producción');

      expect(rejected.status, NegotiationStatus.rejected);
      expect(rejected.closeReason, 'Precio por debajo de los costos de producción');
      expect((await offer('off-003')).status, OfferStatus.activa);
    });
  });

  group('Cancelaciones', () {
    test('el importador puede retirar su solicitud en curso', () async {
      final neg = await request('off-001', 8000);
      final cancelled = await repository.cancelNegotiation(neg.id, reason: 'Ya compré');
      expect(cancelled.status, NegotiationStatus.cancelled);
    });

    test('el exportador no puede cancelar una solicitud en curso (debe rechazarla)', () async {
      final neg = await request('off-001', 8000);
      repository.currentUserId = _seller;
      expect(repository.cancelNegotiation(neg.id), _rejectedWith('Solo el importador'));
    });

    test('cualquiera puede echarse atrás después de aceptar y antes de confirmar', () async {
      final neg = await request('off-001', 8000);
      repository.currentUserId = _seller;
      await repository.acceptPurchaseRequest(neg.id);

      final cancelled = await repository.cancelNegotiation(neg.id);
      expect(cancelled.status, NegotiationStatus.cancelled);
    });
  });

  group('REQ-17: Confirmación doble', () {
    test('el trato se cierra solo cuando confirman ambas partes', () async {
      final neg = await request('off-001', 8000, volume: 10);
      repository.currentUserId = _seller;
      await repository.acceptPurchaseRequest(neg.id);

      repository.currentUserId = _buyer;
      final half = await repository.confirmNegotiation(neg.id);
      expect(half.status, NegotiationStatus.accepted);
      expect(half.hasConfirmed(_buyer), isTrue);
      expect(half.needsConfirmationFrom(_seller), isTrue);
      await expectLater(repository.confirmNegotiation(neg.id), _rejectedWith('Ya confirmaste'));

      repository.currentUserId = _seller;
      final closed = await repository.confirmNegotiation(neg.id);
      expect(closed.status, NegotiationStatus.confirmed);
      expect(closed.confirmedAt, isNotNull);
    });

    test('no se puede confirmar sin haber aceptado', () async {
      final neg = await request('off-001', 8000);
      expect(repository.confirmNegotiation(neg.id), _rejectedWith('acuerdo aceptado'));
    });

    test('al confirmar se descuenta el volumen y se rechazan las solicitudes que no caben',
        () async {
      // Otro importador pide 15 de los 22 MT.
      repository.currentUserId = 'otro-importador';
      await repository.sendCounterOffer(
          offerId: 'off-001', proposedPricePerMt: 8000, volumeMt: 15);

      // El importador demo cierra un trato por 10 MT.
      final neg = await request('off-001', 8100, volume: 10);
      repository.currentUserId = _seller;
      await repository.acceptPurchaseRequest(neg.id);
      await repository.confirmNegotiation(neg.id);
      repository.currentUserId = _buyer;
      await repository.confirmNegotiation(neg.id);

      final updatedOffer = await offer('off-001');
      expect(updatedOffer.volumeMt, 12);
      expect(updatedOffer.status, OfferStatus.activa);

      repository.currentUserId = 'otro-importador';
      final other = (await repository.fetchMyNegotiations()).single;
      expect(other.status, NegotiationStatus.rejected);
      expect(other.closeReason, contains('Volumen insuficiente'));
    });

    test('si se vende todo el volumen la oferta queda confirmada', () async {
      final neg = await request('off-005', 7900); // 12 MT completos
      repository.currentUserId = _seller;
      await repository.acceptPurchaseRequest(neg.id);
      await repository.confirmNegotiation(neg.id);
      repository.currentUserId = _buyer;
      await repository.confirmNegotiation(neg.id);

      final soldOut = await offer('off-005');
      expect(soldOut.volumeMt, 0);
      expect(soldOut.status, OfferStatus.confirmada);
      expect(repository.sendCounterOffer(offerId: 'off-005', proposedPricePerMt: 7000),
          _rejectedWith('ya no recibe solicitudes'));
    });
  });
}
