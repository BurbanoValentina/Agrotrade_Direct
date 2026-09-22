/// Tipo de commodity (REQ-06: registrar café y cacao).
enum CropType { cafe, cacao }

extension CropTypeLabel on CropType {
  String get label => this == CropType.cafe ? 'Café' : 'Cacao';
}

/// Estado de una oferta / negociación (REQ-16, REQ-18).
enum OfferStatus { activa, negociando, confirmada, enTransito }

extension OfferStatusLabel on OfferStatus {
  String get label {
    switch (this) {
      case OfferStatus.activa:
        return 'ACTIVE';
      case OfferStatus.negociando:
        return 'NEGOTIATING';
      case OfferStatus.confirmada:
        return 'CONFIRMED';
      case OfferStatus.enTransito:
        return 'IN TRANSIT';
    }
  }
}

/// Una oferta publicada por un exportador (REQ-07, REQ-08, REQ-09, REQ-10).
///
/// Cuando exista backend real, `OfferRepository` (ver
/// data/repositories/offer_repository.dart) debe seguir devolviendo listas
/// de este mismo modelo — así ninguna pantalla necesita cambiar.
class CropOffer {
  final String id;
  final CropType cropType;
  final String variety; // ej. "Washed Arabica — Geisha"
  final String originRegion; // ej. "Huila"
  final String originCountry; // ej. "Colombia"
  final double askPricePerMt; // USD por tonelada métrica
  final double volumeMt;
  final String destinationCountry;
  final List<String> certifications;
  final String sellerName;
  final double sellerRating;
  final int sellerTrades;
  final OfferStatus status;
  final DateTime postedAt;

  const CropOffer({
    required this.id,
    required this.cropType,
    required this.variety,
    required this.originRegion,
    required this.originCountry,
    required this.askPricePerMt,
    required this.volumeMt,
    required this.destinationCountry,
    required this.certifications,
    required this.sellerName,
    required this.sellerRating,
    required this.sellerTrades,
    required this.status,
    required this.postedAt,
  });

  double get estimatedTotalUsd => askPricePerMt * volumeMt;
}
