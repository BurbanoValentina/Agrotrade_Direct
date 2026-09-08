import '../../models/crop_offer.dart';
import '../../models/purchase_request.dart';
import '../mock/mock_data.dart';

/// Contrato para leer/publicar ofertas y gestionar negociaciones.
abstract class OfferRepository {
  Future<List<CropOffer>> fetchOffers();

  /// REQ-14: enviar una solicitud o contraoferta de precio.
  Future<bool> sendCounterOffer({
    required String offerId,
    required double proposedPricePerMt,
  });

  /// REQ-15: Permitir al exportador aceptar una solicitud de compra.
  Future<bool> acceptPurchaseRequest(String negotiationId);

  /// REQ-15: Permitir al exportador rechazar una solicitud de compra.
  Future<bool> rejectPurchaseRequest(String negotiationId, {String? reason});

  /// REQ-14 / REQ-15 / REQ-19: Consultar el listado de negociaciones del usuario.
  Future<List<PurchaseRequest>> fetchMyNegotiations();
}

/// Implementación en memoria con datos de ejemplo para pruebas offline.
class MockOfferRepository implements OfferRepository {
  final List<PurchaseRequest> _mockNegotiations = [];

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
    _mockNegotiations.add(
      PurchaseRequest(
        id: 'neg-${DateTime.now().millisecondsSinceEpoch}',
        offerId: offerId,
        buyerId: 'demo-buyer',
        sellerId: 'demo-seller',
        proposedPricePerMt: proposedPricePerMt,
        requestedVolumeMt: 10,
        status: NegotiationStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return true;
  }

  @override
  Future<bool> acceptPurchaseRequest(String negotiationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockNegotiations.indexWhere((n) => n.id == negotiationId);
    if (index != -1) {
      final old = _mockNegotiations[index];
      _mockNegotiations[index] = PurchaseRequest(
        id: old.id,
        offerId: old.offerId,
        buyerId: old.buyerId,
        sellerId: old.sellerId,
        proposedPricePerMt: old.proposedPricePerMt,
        requestedVolumeMt: old.requestedVolumeMt,
        status: NegotiationStatus.accepted,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    return true;
  }

  @override
  Future<bool> rejectPurchaseRequest(String negotiationId, {String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockNegotiations.indexWhere((n) => n.id == negotiationId);
    if (index != -1) {
      final old = _mockNegotiations[index];
      _mockNegotiations[index] = PurchaseRequest(
        id: old.id,
        offerId: old.offerId,
        buyerId: old.buyerId,
        sellerId: old.sellerId,
        proposedPricePerMt: old.proposedPricePerMt,
        requestedVolumeMt: old.requestedVolumeMt,
        notes: reason,
        status: NegotiationStatus.rejected,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    return true;
  }

  @override
  Future<List<PurchaseRequest>> fetchMyNegotiations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_mockNegotiations);
  }
}
