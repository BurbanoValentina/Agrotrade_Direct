/// Estado del ciclo de vida de una negociación (REQ-14 a REQ-17, REQ-19).
///
/// * [pending]: le toca responder al exportador.
/// * [countered]: le toca responder al importador.
/// * [accepted]: hay acuerdo; falta que ambas partes confirmen.
/// * [confirmed]: trato cerrado (el volumen se descontó de la oferta).
enum NegotiationStatus {
  pending,
  countered,
  accepted,
  confirmed,
  rejected,
  cancelled,
}

extension NegotiationStatusLabel on NegotiationStatus {
  String get label {
    switch (this) {
      case NegotiationStatus.pending:
        return 'Pendiente';
      case NegotiationStatus.countered:
        return 'Contraofertada';
      case NegotiationStatus.accepted:
        return 'Aceptada';
      case NegotiationStatus.confirmed:
        return 'Confirmada';
      case NegotiationStatus.rejected:
        return 'Rechazada';
      case NegotiationStatus.cancelled:
        return 'Cancelada';
    }
  }

  /// La negociación sigue en curso (se puede responder, aceptar o confirmar).
  bool get isLive =>
      this == NegotiationStatus.pending ||
      this == NegotiationStatus.countered ||
      this == NegotiationStatus.accepted;
}

/// Máximo de rondas de propuesta por negociación (igual que en la BD).
const int maxNegotiationRounds = 10;

/// REQ-49: pasos del envío de un trato confirmado, en orden. El exportador
/// avanza hasta [enPuerto]; el importador confirma [entregado].
enum ShippingStatus { preparando, embarcado, enPuerto, entregado }

extension ShippingStatusX on ShippingStatus {
  /// Valor en la columna `negotiations.shipping_status`.
  String get dbValue => this == ShippingStatus.enPuerto ? 'en_puerto' : name;

  String get label => switch (this) {
        ShippingStatus.preparando => 'En preparación',
        ShippingStatus.embarcado => 'Embarcado',
        ShippingStatus.enPuerto => 'En puerto de destino',
        ShippingStatus.entregado => 'Entregado',
      };

  /// Quién marca este paso: el importador solo confirma la entrega.
  bool get isBuyerStep => this == ShippingStatus.entregado;

  static ShippingStatus? fromDb(String? value) =>
      ShippingStatus.values.where((s) => s.dbValue == value).firstOrNull;
}

/// Solicitud de compra y su negociación estilo InDrive (REQ-14 a REQ-17).
///
/// [proposedPricePerMt] y [requestedVolumeMt] son siempre los términos de la
/// última propuesta; el historial completo está en `NegotiationRound`.
class PurchaseRequest {
  final String id;
  final String offerId;
  final String buyerId;
  final String sellerId;
  final double proposedPricePerMt;
  final double requestedVolumeMt;
  final String? notes;
  final NegotiationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int roundCount;
  final String? lastProposedBy;
  final DateTime? acceptedAt;
  final DateTime? buyerConfirmedAt;
  final DateTime? sellerConfirmedAt;
  final DateTime? confirmedAt;

  /// Motivo del rechazo o la cancelación.
  final String? closeReason;

  /// REQ-49: estado del envío (solo tratos confirmados; null = sin iniciar).
  final ShippingStatus? shippingStatus;
  final DateTime? shippingUpdatedAt;

  // Información enriquecida para mostrar en "My Deals"
  final String? offerVariety;
  final String? sellerName;
  final String? buyerName;

  const PurchaseRequest({
    required this.id,
    required this.offerId,
    required this.buyerId,
    required this.sellerId,
    required this.proposedPricePerMt,
    required this.requestedVolumeMt,
    this.notes,
    this.status = NegotiationStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.roundCount = 1,
    this.lastProposedBy,
    this.acceptedAt,
    this.buyerConfirmedAt,
    this.sellerConfirmedAt,
    this.confirmedAt,
    this.closeReason,
    this.shippingStatus,
    this.shippingUpdatedAt,
    this.offerVariety,
    this.sellerName,
    this.buyerName,
  });

  double get estimatedTotalUsd => proposedPricePerMt * requestedVolumeMt;

  /// Usuario al que le toca responder, o `null` si no hay turno pendiente.
  String? get awaitingUserId => switch (status) {
        NegotiationStatus.pending => sellerId,
        NegotiationStatus.countered => buyerId,
        _ => null,
      };

  /// Si [userId] puede aceptar, rechazar o contraofertar ahora.
  bool isTurnOf(String userId) => awaitingUserId == userId;

  /// Si [userId] puede contraofertar (es su turno y quedan rondas).
  bool canCounter(String userId) =>
      isTurnOf(userId) && roundCount < maxNegotiationRounds;

  /// Si [userId] ya confirmó el acuerdo.
  bool hasConfirmed(String userId) =>
      (userId == buyerId && buyerConfirmedAt != null) ||
      (userId == sellerId && sellerConfirmedAt != null);

  /// Si [userId] debe confirmar el acuerdo (aceptado y aún sin su confirmación).
  bool needsConfirmationFrom(String userId) =>
      status == NegotiationStatus.accepted &&
      (userId == buyerId || userId == sellerId) &&
      !hasConfirmed(userId);

  /// REQ-49: siguiente paso del envío, o null si no hay (sin confirmar o entregado).
  ShippingStatus? get nextShippingStep {
    if (status != NegotiationStatus.confirmed) return null;
    final current = shippingStatus?.index ?? -1;
    return current + 1 < ShippingStatus.values.length
        ? ShippingStatus.values[current + 1]
        : null;
  }

  /// Si [userId] puede marcar [nextShippingStep] (exportador o, para la
  /// entrega, el importador una vez embarcada la carga).
  bool canAdvanceShipping(String userId) {
    final next = nextShippingStep;
    if (next == null) return false;
    return next.isBuyerStep ? userId == buyerId : userId == sellerId;
  }

  PurchaseRequest copyWith({
    double? proposedPricePerMt,
    double? requestedVolumeMt,
    NegotiationStatus? status,
    DateTime? updatedAt,
    int? roundCount,
    String? lastProposedBy,
    DateTime? acceptedAt,
    DateTime? buyerConfirmedAt,
    DateTime? sellerConfirmedAt,
    DateTime? confirmedAt,
    String? closeReason,
    ShippingStatus? shippingStatus,
    DateTime? shippingUpdatedAt,
  }) {
    return PurchaseRequest(
      id: id,
      offerId: offerId,
      buyerId: buyerId,
      sellerId: sellerId,
      proposedPricePerMt: proposedPricePerMt ?? this.proposedPricePerMt,
      requestedVolumeMt: requestedVolumeMt ?? this.requestedVolumeMt,
      notes: notes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      roundCount: roundCount ?? this.roundCount,
      lastProposedBy: lastProposedBy ?? this.lastProposedBy,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      buyerConfirmedAt: buyerConfirmedAt ?? this.buyerConfirmedAt,
      sellerConfirmedAt: sellerConfirmedAt ?? this.sellerConfirmedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      closeReason: closeReason ?? this.closeReason,
      shippingStatus: shippingStatus ?? this.shippingStatus,
      shippingUpdatedAt: shippingUpdatedAt ?? this.shippingUpdatedAt,
      offerVariety: offerVariety,
      sellerName: sellerName,
      buyerName: buyerName,
    );
  }

  factory PurchaseRequest.fromJson(Map<String, dynamic> json) {
    return PurchaseRequest(
      id: json['id'] as String,
      offerId: json['offer_id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      proposedPricePerMt: (json['proposed_price_per_mt'] as num).toDouble(),
      requestedVolumeMt: (json['requested_volume_mt'] as num).toDouble(),
      notes: json['notes'] as String?,
      status: _parseStatus(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      roundCount: (json['round_count'] as num?)?.toInt() ?? 1,
      lastProposedBy: json['last_proposed_by'] as String?,
      acceptedAt: _parseDate(json['accepted_at']),
      buyerConfirmedAt: _parseDate(json['buyer_confirmed_at']),
      sellerConfirmedAt: _parseDate(json['seller_confirmed_at']),
      confirmedAt: _parseDate(json['confirmed_at']),
      closeReason: json['close_reason'] as String?,
      shippingStatus: ShippingStatusX.fromDb(json['shipping_status'] as String?),
      shippingUpdatedAt: _parseDate(json['shipping_updated_at']),
      offerVariety: json['offers']?['variety'] as String?,
      sellerName: json['seller']?['name'] as String?,
      buyerName: json['buyer']?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'offer_id': offerId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'proposed_price_per_mt': proposedPricePerMt,
      'requested_volume_mt': requestedVolumeMt,
      'notes': notes,
      'status': status.name,
    };
  }

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  static NegotiationStatus _parseStatus(String? status) {
    return NegotiationStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => NegotiationStatus.pending,
    );
  }
}
