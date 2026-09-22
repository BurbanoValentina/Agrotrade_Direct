/// Estado de una negociación entre comprador y vendedor.
enum NegotiationStatus { pendiente, aceptada, rechazada, completada }

extension NegotiationStatusLabel on NegotiationStatus {
  String get label {
    switch (this) {
      case NegotiationStatus.pendiente:
        return 'Pendiente';
      case NegotiationStatus.aceptada:
        return 'Aceptada';
      case NegotiationStatus.rechazada:
        return 'Rechazada';
      case NegotiationStatus.completada:
        return 'Completada';
    }
  }
}

/// Registro de una negociación/contraoferta en la plataforma.
class Negotiation {
  final String id;
  final String offerId;
  final String offerVariety;
  final String buyerName;
  final String sellerName;
  final double originalPrice;
  final double proposedPrice;
  final NegotiationStatus status;
  final DateTime createdAt;

  const Negotiation({
    required this.id,
    required this.offerId,
    required this.offerVariety,
    required this.buyerName,
    required this.sellerName,
    required this.originalPrice,
    required this.proposedPrice,
    required this.status,
    required this.createdAt,
  });
}
