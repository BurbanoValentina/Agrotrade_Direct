/// Estado del ciclo de vida de una negociación (REQ-14 a REQ-17, REQ-19).
enum NegotiationStatus {
  pending,
  accepted,
  rejected,
  countered,
  cancelled,
}

extension NegotiationStatusLabel on NegotiationStatus {
  String get label {
    switch (this) {
      case NegotiationStatus.pending:
        return 'Pendiente';
      case NegotiationStatus.accepted:
        return 'Aceptada';
      case NegotiationStatus.rejected:
        return 'Rechazada';
      case NegotiationStatus.countered:
        return 'Contraofertada';
      case NegotiationStatus.cancelled:
        return 'Cancelada';
    }
  }
}

/// Solicitud de compra o contraoferta realizada por un importador (REQ-14).
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
    this.offerVariety,
    this.sellerName,
    this.buyerName,
  });

  double get estimatedTotalUsd => proposedPricePerMt * requestedVolumeMt;

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

  static NegotiationStatus _parseStatus(String? status) {
    switch (status) {
      case 'accepted':
        return NegotiationStatus.accepted;
      case 'rejected':
        return NegotiationStatus.rejected;
      case 'countered':
        return NegotiationStatus.countered;
      case 'cancelled':
        return NegotiationStatus.cancelled;
      case 'pending':
      default:
        return NegotiationStatus.pending;
    }
  }
}
