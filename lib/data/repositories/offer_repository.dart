import '../../models/crop_offer.dart';
import '../../models/negotiation_round.dart';
import '../../models/operation_record.dart';
import '../../models/purchase_request.dart';
import '../mock/mock_data.dart';
import 'repository_exception.dart';

/// Máximo de caracteres de las notas / mensajes de una negociación (igual que en la BD).
const int maxPurchaseRequestNotesLength = 500;

/// Contrato para leer ofertas y gestionar negociaciones (REQ-14 a REQ-17).
///
/// Flujo estilo InDrive:
/// `pending` (turno del exportador) ⇄ `countered` (turno del importador)
/// → `accepted` → ambas partes confirman → `confirmed`.
/// Todos los métodos de negociación lanzan [RepositoryException] con el motivo
/// si la acción no está permitida (no es tu turno, límite de rondas, etc.) y
/// devuelven la negociación actualizada.
abstract class OfferRepository {
  Future<List<CropOffer>> fetchOffers();

  /// REQ-14: el importador envía una solicitud de compra sobre una oferta.
  ///
  /// [volumeMt] es opcional: si no se envía, se pide el volumen completo de la
  /// oferta. Lanza [RepositoryException] con el motivo si la solicitud no es
  /// válida (volumen mayor al disponible, solicitud duplicada, oferta cerrada,
  /// usuario bloqueado o sin rol de importador, etc.).
  Future<void> sendCounterOffer({
    required String offerId,
    required double proposedPricePerMt,
    double? volumeMt,
    String? notes,
  });

  /// REQ-16: contraoferta de quien tiene el turno (máximo 10 rondas).
  /// Si [volumeMt] es null se mantiene el volumen de la propuesta vigente.
  Future<PurchaseRequest> counterOffer({
    required String negotiationId,
    required double pricePerMt,
    double? volumeMt,
    String? message,
  });

  /// REQ-15: quien tiene el turno acepta la propuesta vigente → `accepted`.
  Future<PurchaseRequest> acceptPurchaseRequest(String negotiationId);

  /// REQ-15: quien tiene el turno rechaza la propuesta vigente → `rejected`.
  Future<PurchaseRequest> rejectPurchaseRequest(String negotiationId, {String? reason});

  /// El importador retira su solicitud en curso, o cualquiera de las partes se
  /// echa atrás después de aceptar y antes de confirmar → `cancelled`.
  Future<PurchaseRequest> cancelNegotiation(String negotiationId, {String? reason});

  /// REQ-17: el usuario confirma el acuerdo. Cuando confirman ambas partes la
  /// negociación pasa a `confirmed` y el volumen se descuenta de la oferta.
  Future<PurchaseRequest> confirmNegotiation(String negotiationId);

  /// REQ-16 / REQ-19: historial de propuestas de una negociación, en orden.
  Future<List<NegotiationRound>> fetchNegotiationRounds(String negotiationId);

  /// REQ-14 / REQ-15 / REQ-19: Consultar el listado de negociaciones del usuario.
  Future<List<PurchaseRequest>> fetchMyNegotiations();

  /// REQ-19: operaciones cerradas del usuario (confirmadas, rechazadas y
  /// canceladas), de la más reciente a la más antigua. Todos los filtros son
  /// opcionales; [status] solo acepta confirmed, rejected o cancelled.
  Future<List<OperationRecord>> fetchOperationHistory({
    DateTime? from,
    DateTime? to,
    NegotiationStatus? status,
  });

  /// REQ-19: línea de tiempo de una operación (propuestas, aceptación,
  /// confirmaciones y cierre), en orden cronológico.
  Future<List<TimelineEvent>> fetchNegotiationTimeline(String negotiationId);
}

/// Estados que forman parte del historial de operaciones (REQ-19).
const closedNegotiationStatuses = {
  NegotiationStatus.confirmed,
  NegotiationStatus.rejected,
  NegotiationStatus.cancelled,
};

/// Lanza [RepositoryException] si [status] no es un estado del historial.
void validateHistoryStatus(NegotiationStatus? status) {
  if (status != null && !closedNegotiationStatuses.contains(status)) {
    throw RepositoryException(
        'Estado no válido para el historial: ${status.name} (usa confirmed, rejected o cancelled).');
  }
}

/// Validación local de una solicitud antes de enviarla (evita una llamada a
/// la BD por errores evidentes). La BD repite estas reglas de todos modos.
void validatePurchaseRequestInput({
  required double proposedPricePerMt,
  double? volumeMt,
  String? notes,
}) {
  if (proposedPricePerMt <= 0) {
    throw const RepositoryException('El precio propuesto debe ser mayor que cero.');
  }
  if (volumeMt != null && volumeMt <= 0) {
    throw const RepositoryException('El volumen solicitado debe ser mayor que cero.');
  }
  if (notes != null && notes.length > maxPurchaseRequestNotesLength) {
    throw const RepositoryException(
        'Las notas no pueden superar los $maxPurchaseRequestNotesLength caracteres.');
  }
}

/// Implementación en memoria con datos de ejemplo para pruebas offline.
///
/// Replica las reglas de la BD (migraciones 20260925040000_purchase_request_rules
/// y 20260926000000_negotiation_flow). Como no hay login real, las acciones se
/// hacen en nombre de [currentUserId]: por defecto el importador demo; en las
/// pruebas se cambia a [demoSellerId] para actuar como exportador.
class MockOfferRepository implements OfferRepository {
  MockOfferRepository({this.currentUserId = demoBuyerId});

  static const demoBuyerId = 'demo-buyer';
  static const demoSellerId = 'demo-seller';

  /// Usuario en cuyo nombre se ejecutan las acciones.
  String currentUserId;

  final List<CropOffer> _offers = mockOffers.map(_withDemoSeller).toList();
  final List<PurchaseRequest> _negotiations = [];
  final List<NegotiationRound> _rounds = [];
  int _nextId = 1;

  static CropOffer _withDemoSeller(CropOffer o) =>
      o.sellerId.isEmpty ? _copyOffer(o, sellerId: demoSellerId) : o;

  static CropOffer _copyOffer(CropOffer o,
      {String? sellerId, double? volumeMt, OfferStatus? status}) {
    return CropOffer(
      id: o.id,
      sellerId: sellerId ?? o.sellerId,
      cropType: o.cropType,
      variety: o.variety,
      originRegion: o.originRegion,
      originCountry: o.originCountry,
      askPricePerMt: o.askPricePerMt,
      volumeMt: volumeMt ?? o.volumeMt,
      destinationCountry: o.destinationCountry,
      certifications: o.certifications,
      sellerName: o.sellerName,
      sellerRating: o.sellerRating,
      sellerTrades: o.sellerTrades,
      status: status ?? o.status,
      postedAt: o.postedAt,
    );
  }

  CropOffer? _offer(String id) => _offers.where((o) => o.id == id).firstOrNull;

  void _setOffer(CropOffer updated) {
    _offers[_offers.indexWhere((o) => o.id == updated.id)] = updated;
  }

  /// activa ⇄ negociando según haya negociaciones vivas (igual que la BD).
  void _refreshOfferStatus(String offerId) {
    final offer = _offer(offerId);
    if (offer == null ||
        (offer.status != OfferStatus.activa && offer.status != OfferStatus.negociando)) {
      return;
    }
    final hasLive =
        _negotiations.any((n) => n.offerId == offerId && n.status.isLive);
    _setOffer(_copyOffer(offer,
        status: hasLive ? OfferStatus.negociando : OfferStatus.activa));
  }

  PurchaseRequest _myNegotiation(String id) {
    final neg = _negotiations.where((n) => n.id == id).firstOrNull;
    if (neg == null || (currentUserId != neg.buyerId && currentUserId != neg.sellerId)) {
      throw const RepositoryException('La negociación no existe o no participas en ella.');
    }
    return neg;
  }

  PurchaseRequest _save(PurchaseRequest updated) {
    _negotiations[_negotiations.indexWhere((n) => n.id == updated.id)] = updated;
    return updated;
  }

  void _addRound(PurchaseRequest neg, double price, double volume, String? message) {
    _rounds.add(NegotiationRound(
      id: 'round-${_nextId++}',
      negotiationId: neg.id,
      roundNumber: neg.roundCount,
      proposedBy: currentUserId,
      pricePerMt: price,
      volumeMt: volume,
      message: (message == null || message.trim().isEmpty) ? null : message.trim(),
      createdAt: DateTime.now(),
    ));
  }

  void _requireTurn(PurchaseRequest neg, String otherwise) {
    if (!neg.status.isLive || neg.status == NegotiationStatus.accepted) {
      throw RepositoryException(
          'Esta negociación no está esperando respuesta (estado: ${neg.status.name}).');
    }
    if (!neg.isTurnOf(currentUserId)) throw RepositoryException(otherwise);
  }

  @override
  Future<List<CropOffer>> fetchOffers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List<CropOffer>.from(_offers);
  }

  @override
  Future<void> sendCounterOffer({
    required String offerId,
    required double proposedPricePerMt,
    double? volumeMt,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    validatePurchaseRequestInput(
      proposedPricePerMt: proposedPricePerMt,
      volumeMt: volumeMt,
      notes: notes,
    );

    final offer = _offer(offerId);
    if (offer == null) {
      throw const RepositoryException('La oferta no existe o fue eliminada.');
    }
    if (offer.status != OfferStatus.activa && offer.status != OfferStatus.negociando) {
      throw RepositoryException(
          'Esta oferta ya no recibe solicitudes (estado: ${offer.status.name}).');
    }
    final requested = volumeMt ?? offer.volumeMt;
    if (requested > offer.volumeMt) {
      throw RepositoryException(
          'El volumen solicitado ($requested MT) supera el disponible (${offer.volumeMt} MT).');
    }
    final hasActive = _negotiations.any((n) =>
        n.offerId == offerId && n.buyerId == currentUserId && n.status.isLive);
    if (hasActive) {
      throw const RepositoryException('Ya tienes una solicitud activa para esta oferta.');
    }

    final now = DateTime.now();
    final neg = PurchaseRequest(
      id: 'neg-${_nextId++}',
      offerId: offerId,
      buyerId: currentUserId,
      sellerId: offer.sellerId,
      proposedPricePerMt: proposedPricePerMt,
      requestedVolumeMt: requested,
      notes: notes,
      status: NegotiationStatus.pending,
      createdAt: now,
      updatedAt: now,
      lastProposedBy: currentUserId,
    );
    _negotiations.add(neg);
    _addRound(neg, proposedPricePerMt, requested, notes);
    _refreshOfferStatus(offerId);
  }

  @override
  Future<PurchaseRequest> counterOffer({
    required String negotiationId,
    required double pricePerMt,
    double? volumeMt,
    String? message,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final neg = _myNegotiation(negotiationId);
    if (neg.status != NegotiationStatus.pending && neg.status != NegotiationStatus.countered) {
      throw RepositoryException(
          'Esta negociación ya no admite contraofertas (estado: ${neg.status.name}).');
    }
    _requireTurn(neg, 'No es tu turno: espera la respuesta de la otra parte.');
    if (neg.roundCount >= maxNegotiationRounds) {
      throw const RepositoryException(
          'Se alcanzó el límite de $maxNegotiationRounds rondas: solo puedes aceptar o rechazar.');
    }
    final volume = volumeMt ?? neg.requestedVolumeMt;
    validatePurchaseRequestInput(proposedPricePerMt: pricePerMt, volumeMt: volume, notes: message);
    final available = _offer(neg.offerId)?.volumeMt ?? 0;
    if (volume > available) {
      throw RepositoryException('El volumen ($volume MT) supera el disponible ($available MT).');
    }

    final updated = _save(neg.copyWith(
      proposedPricePerMt: pricePerMt,
      requestedVolumeMt: volume,
      roundCount: neg.roundCount + 1,
      lastProposedBy: currentUserId,
      status: currentUserId == neg.sellerId
          ? NegotiationStatus.countered
          : NegotiationStatus.pending,
      updatedAt: DateTime.now(),
    ));
    _addRound(updated, pricePerMt, volume, message);
    return updated;
  }

  @override
  Future<PurchaseRequest> acceptPurchaseRequest(String negotiationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final neg = _myNegotiation(negotiationId);
    _requireTurn(neg, 'No es tu turno: no puedes aceptar tu propia propuesta.');
    final available = _offer(neg.offerId)?.volumeMt ?? 0;
    if (neg.requestedVolumeMt > available) {
      throw RepositoryException(
          'El volumen (${neg.requestedVolumeMt} MT) ya no está disponible (quedan $available MT).');
    }
    final now = DateTime.now();
    return _save(neg.copyWith(
        status: NegotiationStatus.accepted, acceptedAt: now, updatedAt: now));
  }

  @override
  Future<PurchaseRequest> rejectPurchaseRequest(String negotiationId, {String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final neg = _myNegotiation(negotiationId);
    _requireTurn(neg, 'No es tu turno: espera la respuesta de la otra parte.');
    final updated = _save(neg.copyWith(
      status: NegotiationStatus.rejected,
      closeReason: reason,
      updatedAt: DateTime.now(),
    ));
    _refreshOfferStatus(neg.offerId);
    return updated;
  }

  @override
  Future<PurchaseRequest> cancelNegotiation(String negotiationId, {String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final neg = _myNegotiation(negotiationId);
    if (neg.status == NegotiationStatus.pending || neg.status == NegotiationStatus.countered) {
      if (currentUserId != neg.buyerId) {
        throw const RepositoryException(
            'Solo el importador puede cancelar una solicitud en curso; el exportador puede rechazarla en su turno.');
      }
    } else if (neg.status != NegotiationStatus.accepted) {
      throw RepositoryException('Esta negociación ya está cerrada (estado: ${neg.status.name}).');
    }
    final updated = _save(neg.copyWith(
      status: NegotiationStatus.cancelled,
      closeReason: reason,
      updatedAt: DateTime.now(),
    ));
    _refreshOfferStatus(neg.offerId);
    return updated;
  }

  @override
  Future<PurchaseRequest> confirmNegotiation(String negotiationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var neg = _myNegotiation(negotiationId);
    if (neg.status != NegotiationStatus.accepted) {
      throw RepositoryException(
          'Solo se puede confirmar un acuerdo aceptado (estado: ${neg.status.name}).');
    }
    if (neg.hasConfirmed(currentUserId)) {
      throw const RepositoryException(
          'Ya confirmaste este trato; falta la confirmación de la otra parte.');
    }

    final now = DateTime.now();
    neg = _save(currentUserId == neg.buyerId
        ? neg.copyWith(buyerConfirmedAt: now, updatedAt: now)
        : neg.copyWith(sellerConfirmedAt: now, updatedAt: now));
    if (neg.buyerConfirmedAt == null || neg.sellerConfirmedAt == null) return neg;

    // Segunda confirmación: se cierra el trato.
    final offer = _offer(neg.offerId)!;
    if (neg.requestedVolumeMt > offer.volumeMt) {
      throw RepositoryException(
          'El volumen (${neg.requestedVolumeMt} MT) ya no está disponible (quedan ${offer.volumeMt} MT). Cancela y negocia de nuevo.');
    }
    final remaining = offer.volumeMt - neg.requestedVolumeMt;
    neg = _save(neg.copyWith(status: NegotiationStatus.confirmed, confirmedAt: now));
    _setOffer(_copyOffer(offer,
        volumeMt: remaining,
        status: remaining == 0 ? OfferStatus.confirmada : offer.status));

    for (final other in List.of(_negotiations)) {
      if (other.offerId == offer.id &&
          other.id != neg.id &&
          other.status.isLive &&
          other.requestedVolumeMt > remaining) {
        _save(other.copyWith(
          status: NegotiationStatus.rejected,
          closeReason:
              'Volumen insuficiente: la oferta quedó con $remaining MT tras otro trato confirmado.',
          updatedAt: now,
        ));
      }
    }
    _refreshOfferStatus(offer.id);
    return neg;
  }

  @override
  Future<List<NegotiationRound>> fetchNegotiationRounds(String negotiationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _myNegotiation(negotiationId);
    return _rounds.where((r) => r.negotiationId == negotiationId).toList()
      ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
  }

  @override
  Future<List<PurchaseRequest>> fetchMyNegotiations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_negotiations.where(
        (n) => n.buyerId == currentUserId || n.sellerId == currentUserId));
  }

  static String _demoName(String userId) => switch (userId) {
        demoBuyerId => 'Importador Demo',
        demoSellerId => 'Exportador Demo',
        _ => userId,
      };

  @override
  Future<List<OperationRecord>> fetchOperationHistory({
    DateTime? from,
    DateTime? to,
    NegotiationStatus? status,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    validateHistoryStatus(status);

    final records = <OperationRecord>[];
    for (final n in _negotiations) {
      if (!closedNegotiationStatuses.contains(n.status)) continue;
      if (n.buyerId != currentUserId && n.sellerId != currentUserId) continue;
      if (status != null && n.status != status) continue;
      final closedAt = n.confirmedAt ?? n.updatedAt;
      if (from != null && closedAt.isBefore(from)) continue;
      if (to != null && closedAt.isAfter(to)) continue;

      final offer = _offer(n.offerId);
      final isBuyer = n.buyerId == currentUserId;
      records.add(OperationRecord(
        negotiationId: n.id,
        offerId: n.offerId,
        cropType: offer?.cropType.name ?? 'cafe',
        variety: offer?.variety ?? '',
        originRegion: offer?.originRegion ?? '',
        destinationCountry: offer?.destinationCountry ?? '',
        myRole: isBuyer ? 'comprador' : 'vendedor',
        buyerName: _demoName(n.buyerId),
        sellerName: offer?.sellerName ?? _demoName(n.sellerId),
        counterpartyName:
            isBuyer ? (offer?.sellerName ?? _demoName(n.sellerId)) : _demoName(n.buyerId),
        status: n.status,
        statusLabel: n.status.label,
        pricePerMt: n.proposedPricePerMt,
        volumeMt: n.requestedVolumeMt,
        totalUsd: n.estimatedTotalUsd,
        roundCount: n.roundCount,
        createdAt: n.createdAt,
        closedAt: closedAt,
        closeReason: n.closeReason,
      ));
    }
    records.sort((a, b) => b.closedAt.compareTo(a.closedAt));
    return records;
  }

  @override
  Future<List<TimelineEvent>> fetchNegotiationTimeline(String negotiationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final n = _myNegotiation(negotiationId);

    final events = <TimelineEvent>[
      for (final r in _rounds.where((r) => r.negotiationId == negotiationId))
        TimelineEvent(
          at: r.createdAt,
          type: 'propuesta',
          actorId: r.proposedBy,
          actorName: _demoName(r.proposedBy ?? ''),
          description: (r.roundNumber == 1
                  ? 'Solicitud inicial: ${r.pricePerMt} USD/MT por ${r.volumeMt} MT'
                  : 'Ronda ${r.roundNumber}: contraoferta de ${r.pricePerMt} USD/MT por ${r.volumeMt} MT') +
              (r.message == null ? '' : ' — "${r.message}"'),
          pricePerMt: r.pricePerMt,
          volumeMt: r.volumeMt,
        ),
      if (n.acceptedAt != null)
        TimelineEvent(
          at: n.acceptedAt!,
          type: 'aceptada',
          description: 'Propuesta aceptada; falta la confirmación de ambas partes',
        ),
      if (n.buyerConfirmedAt != null)
        TimelineEvent(
          at: n.buyerConfirmedAt!,
          type: 'confirmacion',
          actorId: n.buyerId,
          actorName: _demoName(n.buyerId),
          description: 'Confirmó el trato (comprador)',
        ),
      if (n.sellerConfirmedAt != null)
        TimelineEvent(
          at: n.sellerConfirmedAt!,
          type: 'confirmacion',
          actorId: n.sellerId,
          actorName: _demoName(n.sellerId),
          description: 'Confirmó el trato (vendedor)',
        ),
      if (n.status == NegotiationStatus.confirmed)
        TimelineEvent(
          at: n.confirmedAt ?? n.updatedAt,
          type: 'confirmada',
          description: 'Trato confirmado por ambas partes',
        ),
      if (n.status == NegotiationStatus.rejected || n.status == NegotiationStatus.cancelled)
        TimelineEvent(
          at: n.updatedAt,
          type: n.status == NegotiationStatus.rejected ? 'rechazada' : 'cancelada',
          description: (n.status == NegotiationStatus.rejected
                  ? 'Negociación rechazada'
                  : 'Negociación cancelada') +
              (n.closeReason == null ? '' : ': ${n.closeReason}'),
        ),
    ];
    events.sort((a, b) => a.at.compareTo(b.at));
    return events;
  }
}
