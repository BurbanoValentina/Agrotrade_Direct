import '../../models/crop_offer.dart';
import '../mock/mock_data.dart';

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

/// Implementación en memoria con datos de ejemplo (ver data/mock/mock_data.dart).
class MockOfferRepository implements OfferRepository {
  @override
  Future<List<CropOffer>> fetchOffers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List<CropOffer>.from(mockOffers);
  }

  @override
  Future<bool> sendCounterOffer({
    required String offerId,
    required double proposedPricePerMt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // TODO(negociación real): aquí se creará una fila en la tabla
    // "negotiations" de Supabase y se notificará al exportador (REQ-14,
    // REQ-15, REQ-20). Por ahora solo simula éxito.
    return true;
  }
}
