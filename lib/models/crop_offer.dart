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
  final String sellerId;
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
    this.sellerId = '',
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

  factory CropOffer.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final typeStr = json['crop_type'] as String? ?? 'cafe';
    final statusStr = json['status'] as String? ?? 'activa';

    return CropOffer(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String? ?? '',
      cropType: typeStr == 'cacao' ? CropType.cacao : CropType.cafe,
      variety: json['variety'] as String? ?? '',
      originRegion: json['origin_region'] as String? ?? '',
      originCountry: json['origin_country'] as String? ?? 'Colombia',
      askPricePerMt: (json['ask_price_per_mt'] as num?)?.toDouble() ?? 0.0,
      volumeMt: (json['volume_mt'] as num?)?.toDouble() ?? 0.0,
      destinationCountry: json['destination_country'] as String? ?? '',
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sellerName: profile?['name'] as String? ?? 'Exportador Colombiano',
      sellerRating: (profile?['rating'] as num?)?.toDouble() ?? 5.0,
      sellerTrades: (profile?['completed_trades'] as num?)?.toInt() ?? 0,
      status: _parseStatus(statusStr),
      postedAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  static OfferStatus _parseStatus(String status) {
    switch (status) {
      case 'negociando':
        return OfferStatus.negociando;
      case 'confirmada':
        return OfferStatus.confirmada;
      case 'enTransito':
        return OfferStatus.enTransito;
      case 'activa':
      default:
        return OfferStatus.activa;
    }
  }
}
