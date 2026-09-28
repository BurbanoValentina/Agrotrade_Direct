import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/crop_offer.dart';

/// REQ-27: Servicio de almacenamiento local para el modo offline básico.
class LocalStorageService {
  static const String _offersCacheKey = 'cached_crop_offers_v1';

  /// Guarda las ofertas en el disco del dispositivo
  Future<void> cacheOffers(List<CropOffer> offers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> rawList = offers.map((offer) {
        return {
          'id': offer.id,
          'cropType': offer.cropType.name,
          'variety': offer.variety,
          'originRegion': offer.originRegion,
          'originCountry': offer.originCountry,
          'askPricePerMt': offer.askPricePerMt,
          'volumeMt': offer.volumeMt,
          'destinationCountry': offer.destinationCountry,
          'certifications': offer.certifications,
          'sellerName': offer.sellerName,
          'sellerRating': offer.sellerRating,
          'sellerTrades': offer.sellerTrades,
          'status': offer.status.name,
          'postedAt': offer.postedAt.toIso8601String(),
        };
      }).toList();

      await prefs.setString(_offersCacheKey, jsonEncode(rawList));
      debugPrint(
          '📦 [REQ-27 CACHÉ]: ${offers.length} ofertas guardadas en almacenamiento local.');
    } catch (e) {
      debugPrint(
          '⚠️ [REQ-27 CACHÉ ERROR]: No se pudo guardar en caché local: $e');
    }
  }

  /// REQ-27: Recupera las ofertas cacheadas si falla la red
  Future<List<CropOffer>> getCachedOffers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_offersCacheKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> rawList = jsonDecode(jsonString);
      final offers = rawList.map((item) {
        final map = item as Map<String, dynamic>;
        return CropOffer(
          id: map['id'] ?? '',
          cropType:
              (map['cropType'] == 'cacao') ? CropType.cacao : CropType.cafe,
          variety: map['variety'] ?? '',
          originRegion: map['originRegion'] ?? '',
          originCountry: map['originCountry'] ?? '',
          askPricePerMt: (map['askPricePerMt'] as num).toDouble(),
          volumeMt: (map['volumeMt'] as num).toDouble(),
          destinationCountry: map['destinationCountry'] ?? '',
          certifications: List<String>.from(map['certifications'] ?? []),
          sellerName: map['sellerName'] ?? '',
          sellerRating: (map['sellerRating'] as num).toDouble(),
          sellerTrades: (map['sellerTrades'] as num).toInt(),
          status: OfferStatus.values.firstWhere(
            (e) => e.name == map['status'],
            orElse: () => OfferStatus.activa,
          ),
          postedAt: DateTime.parse(map['postedAt']),
        );
      }).toList();

      debugPrint(
          '✅ [REQ-27 OFFLINE]: ${offers.length} ofertas recuperadas del almacenamiento local.');
      return offers;
    } catch (e) {
      debugPrint('⚠️ [REQ-27 OFFLINE ERROR]: Error leyendo el caché: $e');
      return [];
    }
  }
}
