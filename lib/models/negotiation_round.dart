/// Una propuesta dentro del ida y vuelta de una negociación (REQ-16).
///
/// La ronda 1 es la solicitud original del importador; cada contraoferta
/// agrega una ronda nueva (máximo `maxNegotiationRounds`).
class NegotiationRound {
  final String id;
  final String negotiationId;
  final int roundNumber;
  final String? proposedBy;
  final double pricePerMt;
  final double volumeMt;
  final String? message;
  final DateTime createdAt;

  const NegotiationRound({
    required this.id,
    required this.negotiationId,
    required this.roundNumber,
    required this.proposedBy,
    required this.pricePerMt,
    required this.volumeMt,
    this.message,
    required this.createdAt,
  });

  factory NegotiationRound.fromJson(Map<String, dynamic> json) {
    return NegotiationRound(
      id: json['id'] as String,
      negotiationId: json['negotiation_id'] as String,
      roundNumber: (json['round_number'] as num).toInt(),
      proposedBy: json['proposed_by'] as String?,
      pricePerMt: (json['price_per_mt'] as num).toDouble(),
      volumeMt: (json['volume_mt'] as num).toDouble(),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
