import 'package:flutter_test/flutter_test.dart';
import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/models/purchase_request.dart';

void main() {
  group('Backend Negotiation Workflow (REQ-14 y REQ-15)', () {
    late OfferRepository repository;

    setUp(() {
      repository = MockOfferRepository();
    });

    test('REQ-14: El importador puede enviar una solicitud de compra / contraoferta', () async {
      // 1. El importador envía una solicitud sobre una oferta
      final success = await repository.sendCounterOffer(
        offerId: 'off-001',
        proposedPricePerMt: 7800.0,
      );

      expect(success, isTrue, reason: 'La solicitud debe enviarse exitosamente');

      // 2. Verificar que la negociación queda registrada con estado 'pending'
      final negotiations = await repository.fetchMyNegotiations();
      expect(negotiations.isNotEmpty, isTrue);

      final latest = negotiations.last;
      expect(latest.offerId, equals('off-001'));
      expect(latest.proposedPricePerMt, equals(7800.0));
      expect(latest.status, equals(NegotiationStatus.pending));
    });

    test('REQ-15: El exportador puede aceptar una solicitud de compra', () async {
      // 1. Crear una solicitud previa (REQ-14)
      await repository.sendCounterOffer(
        offerId: 'off-002',
        proposedPricePerMt: 6000.0,
      );

      final negotiations = await repository.fetchMyNegotiations();
      final negId = negotiations.last.id;

      // 2. El exportador acepta la solicitud (REQ-15)
      final accepted = await repository.acceptPurchaseRequest(negId);
      expect(accepted, isTrue);

      // 3. Verificar que el estado cambió a 'accepted'
      final updated = await repository.fetchMyNegotiations();
      final target = updated.firstWhere((n) => n.id == negId);
      expect(target.status, equals(NegotiationStatus.accepted));
    });

    test('REQ-15: El exportador puede rechazar una solicitud con motivo', () async {
      // 1. Crear una solicitud previa (REQ-14)
      await repository.sendCounterOffer(
        offerId: 'off-003',
        proposedPricePerMt: 5000.0,
      );

      final negotiations = await repository.fetchMyNegotiations();
      final negId = negotiations.last.id;

      // 2. El exportador rechaza la solicitud (REQ-15)
      final rejected = await repository.rejectPurchaseRequest(
        negId,
        reason: 'Precio por debajo de los costos de producción',
      );
      expect(rejected, isTrue);

      // 3. Verificar que el estado cambió a 'rejected' y se guardó la nota
      final updated = await repository.fetchMyNegotiations();
      final target = updated.firstWhere((n) => n.id == negId);
      expect(target.status, equals(NegotiationStatus.rejected));
      expect(target.notes, equals('Precio por debajo de los costos de producción'));
    });
  });
}
