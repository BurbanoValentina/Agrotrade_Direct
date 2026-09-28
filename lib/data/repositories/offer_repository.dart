import '../../models/crop_offer.dart';
import '../mock/mock_data.dart';
import '../services/local_storage_service.dart';

/// Contrato para leer/publicar ofertas y enviar contraofertas.
///
/// IMPORTANTE PARA EL BACKEND DEV: crea `SupabaseOfferRepository implements
/// OfferRepository` cuando el esquema de base de datos esté listo (REQ-23),
/// y cambia una línea en `main.dart`. Nada más se toca.
abstract class OfferRepository {
  Future<List<CropOffer>> fetchOffers();

  /// REQ-14 / REQ-16: enviar una solicitud o contraoferta de precio.
  /// Devuelve true si se "envió" correctamente (aquí, en memoria).
  Future<bool> sendCounterOffer({
    required String offerId,
    required double proposedPricePerMt,
  });
}

/// Implementación en memoria con datos de ejemplo y caché local para modo offline (REQ-27).
class MockOfferRepository implements OfferRepository {
  MockOfferRepository([LocalStorageService? storageService])
      : _storageService = storageService ?? LocalStorageService();

  final LocalStorageService _storageService;

  @override
  Future<List<CropOffer>> fetchOffers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      // 1. Obtenemos las ofertas iniciales o mock
      final offers = List<CropOffer>.from(mockOffers);

      // 2. REQ-27: Guardamos automáticamente una copia en la memoria del teléfono
      await _storageService.cacheOffers(offers);

      return offers;
    } catch (e) {
      // 3. REQ-27: Si falla la red/fuente, devolvemos lo que esté guardado en caché
      final cached = await _storageService.getCachedOffers();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<bool> sendCounterOffer({
    required String offerId,
    required double proposedPricePerMt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true;
  }
}