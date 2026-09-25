import 'package:flutter_test/flutter_test.dart';
import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/models/purchase_request.dart';

void main() {
  group('Backend Negotiation Workflow (REQ-14 y REQ-15)', () {
    late OfferRepository repository;

    setUp(() {
      repository = MockOfferRepository();
    });

    test('REQ-14: El importador puede enviar una solicitud de compra / contraoferta', () async {
      // 1. El importador envía una solicitud sobre una oferta (sin volumen)
      await repository.sendCounterOffer(
        offerId: 'off-001',
        proposedPricePerMt: 7800.0,
      );

      // 2. Verificar que la negociación queda registrada con estado 'pending'
      final negotiations = await repository.fetchMyNegotiations();
      expect(negotiations.isNotEmpty, isTrue);

      final latest = negotiations.last;
      expect(latest.offerId, equals('off-001'));
      expect(latest.proposedPricePerMt, equals(7800.0));
      expect(latest.status, equals(NegotiationStatus.pending));
      // Sin volumen explícito se pide el volumen completo de la oferta (22 MT).
      expect(latest.requestedVolumeMt, equals(22.0));
    });

    test('REQ-14: La solicitud guarda volumen parcial y notas', () async {
      await repository.sendCounterOffer(
        offerId: 'off-001',
        proposedPricePerMt: 8000.0,
        volumeMt: 10,
        notes: 'Entrega FOB Buenaventura',
      );

      final latest = (await repository.fetchMyNegotiations()).last;
      expect(latest.requestedVolumeMt, equals(10.0));
      expect(latest.notes, equals('Entrega FOB Buenaventura'));
    });

    group('REQ-14: Rechazos con mensaje claro', () {
      Future<void> expectRejected(Future<void> Function() send, String messagePart) {
        return expectLater(
          send(),
          throwsA(isA<RepositoryException>()
              .having((e) => e.message, 'message', contains(messagePart))),
        );
      }

      test('precio cero o negativo', () {
        return expectRejected(
          () => repository.sendCounterOffer(offerId: 'off-001', proposedPricePerMt: 0),
          'precio propuesto debe ser mayor que cero',
        );
      });

      test('volumen cero', () {
        return expectRejected(
          () => repository.sendCounterOffer(
              offerId: 'off-001', proposedPricePerMt: 8000, volumeMt: 0),
          'volumen solicitado debe ser mayor que cero',
        );
      });

      test('volumen mayor al disponible', () {
        return expectRejected(
          () => repository.sendCounterOffer(
              offerId: 'off-001', proposedPricePerMt: 8000, volumeMt: 99),
          'supera el disponible',
        );
      });

      test('notas de más de 500 caracteres', () {
        return expectRejected(
          () => repository.sendCounterOffer(
              offerId: 'off-001', proposedPricePerMt: 8000, notes: 'x' * 501),
          '500 caracteres',
        );
      });

      test('oferta que ya no recibe solicitudes', () {
        // off-004 está confirmada en los datos mock.
        return expectRejected(
          () => repository.sendCounterOffer(offerId: 'off-004', proposedPricePerMt: 5000),
          'ya no recibe solicitudes',
        );
      });

      test('oferta inexistente', () {
        return expectRejected(
          () => repository.sendCounterOffer(offerId: 'no-existe', proposedPricePerMt: 5000),
          'no existe',
        );
      });

      test('solicitud duplicada mientras la anterior sigue activa', () async {
        await repository.sendCounterOffer(offerId: 'off-001', proposedPricePerMt: 8000);
        await expectRejected(
          () => repository.sendCounterOffer(offerId: 'off-001', proposedPricePerMt: 7900),
          'Ya tienes una solicitud activa',
        );
      });

      test('se puede volver a solicitar si la anterior fue rechazada', () async {
        await repository.sendCounterOffer(offerId: 'off-001', proposedPricePerMt: 8000);
        final first = (await repository.fetchMyNegotiations()).last;
        await repository.rejectPurchaseRequest(first.id);

        await repository.sendCounterOffer(offerId: 'off-001', proposedPricePerMt: 8200);
        expect((await repository.fetchMyNegotiations()).length, equals(2));
      });
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
