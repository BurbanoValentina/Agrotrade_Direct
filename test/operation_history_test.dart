import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/models/operation_record.dart';
import 'package:agrotrade_direct/models/purchase_request.dart';
import 'package:agrotrade_direct/services/operation_history_exporter.dart';

const _buyer = MockOfferRepository.demoBuyerId;
const _seller = MockOfferRepository.demoSellerId;

OperationRecord _record({
  NegotiationStatus status = NegotiationStatus.confirmed,
  String variety = 'Washed Arabica — Geisha',
  double price = 8000,
  double volume = 10,
  String? reason,
}) {
  return OperationRecord(
    negotiationId: 'neg-1',
    offerId: 'off-001',
    cropType: 'cafe',
    variety: variety,
    originRegion: 'Huila',
    destinationCountry: 'Alemania',
    myRole: 'comprador',
    buyerName: 'Hamburg Imports',
    sellerName: 'Café Primavera',
    counterpartyName: 'Café Primavera',
    counterpartyCompany: 'Primavera SAS',
    status: status,
    statusLabel: status.label,
    pricePerMt: price,
    volumeMt: volume,
    totalUsd: price * volume,
    roundCount: 2,
    createdAt: DateTime(2026, 9, 20, 10),
    closedAt: DateTime(2026, 9, 21, 15, 30),
    closeReason: reason,
  );
}

void main() {
  group('REQ-19: Historial de operaciones', () {
    late MockOfferRepository repo;

    setUp(() => repo = MockOfferRepository());

    Future<String> requestAs(String offerId, double price, double volume) async {
      repo.currentUserId = _buyer;
      await repo.sendCounterOffer(offerId: offerId, proposedPricePerMt: price, volumeMt: volume);
      return (await repo.fetchMyNegotiations()).last.id;
    }

    Future<void> closeDeal(String id) async {
      repo.currentUserId = _seller;
      await repo.acceptPurchaseRequest(id);
      await repo.confirmNegotiation(id);
      repo.currentUserId = _buyer;
      await repo.confirmNegotiation(id);
    }

    test('solo incluye operaciones cerradas, de la más reciente a la más antigua', () async {
      final confirmed = await requestAs('off-001', 8000, 10);
      await closeDeal(confirmed);
      final rejected = await requestAs('off-003', 5000, 5);
      repo.currentUserId = _seller;
      await repo.rejectPurchaseRequest(rejected, reason: 'Precio bajo');
      await requestAs('off-005', 7800, 2); // sigue en curso: no va al historial

      repo.currentUserId = _buyer;
      final history = await repo.fetchOperationHistory();

      expect(history.map((r) => r.status),
          [NegotiationStatus.rejected, NegotiationStatus.confirmed]);
      final deal = history.last;
      expect(deal.myRole, 'comprador');
      expect(deal.totalUsd, 80000);
      expect(history.first.closeReason, 'Precio bajo');
    });

    test('filtra por estado y rechaza estados que no son del historial', () async {
      await closeDeal(await requestAs('off-001', 8000, 10));
      repo.currentUserId = _buyer;
      await repo.cancelNegotiation(await requestAs('off-003', 5000, 5));

      final onlyConfirmed =
          await repo.fetchOperationHistory(status: NegotiationStatus.confirmed);
      expect(onlyConfirmed.single.status, NegotiationStatus.confirmed);

      expect(repo.fetchOperationHistory(status: NegotiationStatus.pending),
          throwsA(isA<RepositoryException>()));
    });

    test('el vendedor ve la misma operación con su rol', () async {
      await closeDeal(await requestAs('off-001', 8000, 10));
      repo.currentUserId = _seller;
      final history = await repo.fetchOperationHistory();
      expect(history.single.myRole, 'vendedor');
    });

    test('la línea de tiempo muestra propuestas, aceptación y confirmaciones en orden', () async {
      final id = await requestAs('off-001', 8000, 10);
      repo.currentUserId = _seller;
      await repo.counterOffer(negotiationId: id, pricePerMt: 8200, message: 'Incluye empaque');
      repo.currentUserId = _buyer;
      await repo.acceptPurchaseRequest(id);
      await repo.confirmNegotiation(id);
      repo.currentUserId = _seller;
      await repo.confirmNegotiation(id);

      final timeline = await repo.fetchNegotiationTimeline(id);
      expect(timeline.map((e) => e.type), [
        'propuesta', 'propuesta', 'aceptada', 'confirmacion', 'confirmacion', 'confirmada',
      ]);
      expect(timeline[1].description, contains('Incluye empaque'));
    });
  });

  group('REQ-30: Exportar historial', () {
    const exporter = OperationHistoryExporter();

    test('CSV para Excel en español: BOM, separador ; y coma decimal', () {
      final bytes = exporter.toCsv([_record(price: 8150.5, volume: 10)]);

      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final lines = utf8.decode(bytes.sublist(3)).split('\r\n');
      expect(lines, hasLength(2));
      expect(lines.first, startsWith('Fecha de cierre;Estado;Mi rol;Producto'));
      expect(lines[1], contains('Confirmada;comprador;Café;Washed Arabica — Geisha'));
      expect(lines[1], contains('8150,50;10,00;81505,00'));
    });

    test('CSV escapa campos con ; o comillas', () {
      final bytes = exporter.toCsv([_record(reason: 'Precio "bajo"; sin acuerdo')]);
      final row = utf8.decode(bytes.sublist(3)).split('\r\n')[1];
      expect(row, endsWith('"Precio ""bajo""; sin acuerdo"'));
    });

    test('PDF válido, incluso con caracteres fuera de Latin-1 y sin operaciones', () async {
      final pdf = await exporter.toPdf(
        [_record(), _record(status: NegotiationStatus.rejected, reason: 'Precio bajo')],
        userName: 'Hamburg Imports',
        from: DateTime(2026, 9, 1),
      );
      expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(pdf.length, greaterThan(1000));

      final empty = await exporter.toPdf([], userName: 'Nadie');
      expect(ascii.decode(empty.sublist(0, 5)), '%PDF-');
    });

    test('los totales solo cuentan tratos confirmados', () {
      final summary = OperationHistorySummary.from([
        _record(price: 8000, volume: 10),
        _record(price: 6000, volume: 5),
        _record(status: NegotiationStatus.rejected, price: 9999, volume: 99),
      ]);
      expect(summary.operations, 3);
      expect(summary.confirmed, 2);
      expect(summary.confirmedVolumeMt, 15);
      expect(summary.confirmedValueUsd, 110000);
    });

    test('nombre de archivo sugerido', () {
      expect(exporter.fileName('csv', now: DateTime(2026, 9, 26)),
          'historial_agrotrade_2026-09-26.csv');
    });
  });
}
