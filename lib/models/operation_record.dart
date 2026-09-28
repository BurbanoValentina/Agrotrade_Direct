import 'purchase_request.dart';

/// Una operación cerrada del historial (REQ-19): confirmada, rechazada o
/// cancelada, vista desde el usuario que consulta.
///
/// Viene de `rpc('my_operation_history')` y es lo que se exporta a CSV / PDF
/// (REQ-30).
class OperationRecord {
  final String negotiationId;
  final String offerId;
  final String cropType; // 'cafe' | 'cacao'
  final String variety;
  final String originRegion;
  final String destinationCountry;

  /// 'comprador', 'vendedor' o 'admin' (consulta de todas las operaciones).
  final String myRole;
  final String buyerName;
  final String sellerName;
  final String counterpartyName;
  final String? counterpartyCompany;
  final NegotiationStatus status;
  final String statusLabel;
  final double pricePerMt;
  final double volumeMt;
  final double totalUsd;
  final int roundCount;
  final DateTime createdAt;
  final DateTime closedAt;
  final String? closeReason;

  const OperationRecord({
    required this.negotiationId,
    required this.offerId,
    required this.cropType,
    required this.variety,
    required this.originRegion,
    required this.destinationCountry,
    required this.myRole,
    required this.buyerName,
    required this.sellerName,
    required this.counterpartyName,
    this.counterpartyCompany,
    required this.status,
    required this.statusLabel,
    required this.pricePerMt,
    required this.volumeMt,
    required this.totalUsd,
    required this.roundCount,
    required this.createdAt,
    required this.closedAt,
    this.closeReason,
  });

  String get cropLabel => cropType == 'cacao' ? 'Cacao' : 'Café';

  factory OperationRecord.fromJson(Map<String, dynamic> json) {
    final status = NegotiationStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => NegotiationStatus.cancelled,
    );
    return OperationRecord(
      negotiationId: json['negotiation_id'] as String,
      offerId: json['offer_id'] as String,
      cropType: json['crop_type'] as String,
      variety: json['variety'] as String,
      originRegion: json['origin_region'] as String? ?? '',
      destinationCountry: json['destination_country'] as String? ?? '',
      myRole: json['my_role'] as String,
      buyerName: json['buyer_name'] as String? ?? '',
      sellerName: json['seller_name'] as String? ?? '',
      counterpartyName: json['counterparty_name'] as String? ?? '',
      counterpartyCompany: json['counterparty_company'] as String?,
      status: status,
      statusLabel: json['status_label'] as String? ?? status.label,
      pricePerMt: (json['price_per_mt'] as num).toDouble(),
      volumeMt: (json['volume_mt'] as num).toDouble(),
      totalUsd: (json['total_usd'] as num).toDouble(),
      roundCount: (json['round_count'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      closedAt: DateTime.parse(json['closed_at'] as String),
      closeReason: json['close_reason'] as String?,
    );
  }
}

/// Un evento de la línea de tiempo de una operación (REQ-19).
///
/// [type]: 'propuesta', 'aceptada', 'confirmacion', 'confirmada', 'rechazada'
/// o 'cancelada'. [pricePerMt] / [volumeMt] solo vienen en las propuestas.
class TimelineEvent {
  final DateTime at;
  final String type;
  final String? actorId;
  final String? actorName;
  final String description;
  final double? pricePerMt;
  final double? volumeMt;

  const TimelineEvent({
    required this.at,
    required this.type,
    this.actorId,
    this.actorName,
    required this.description,
    this.pricePerMt,
    this.volumeMt,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      at: DateTime.parse(json['event_at'] as String),
      type: json['event_type'] as String,
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String?,
      description: json['description'] as String,
      pricePerMt: (json['price_per_mt'] as num?)?.toDouble(),
      volumeMt: (json['volume_mt'] as num?)?.toDouble(),
    );
  }
}
