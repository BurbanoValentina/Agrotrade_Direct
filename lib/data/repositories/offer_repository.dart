import '../../models/crop_offer.dart';
import '../../models/purchase_request.dart';
import '../mock/mock_data.dart';
import 'repository_exception.dart';

/// Máximo de caracteres de las notas de una solicitud (igual que en la BD).
const int maxPurchaseRequestNotesLength = 500;

/// Contrato para leer/publicar ofertas y gestionar negociaciones.
abstract class OfferRepository {
  Future<List<CropOffer>> fetchOffers();

  /// REQ-14: el importador envía una solicitud de compra sobre una oferta.
  ///
  /// [volumeMt] es opcional: si no se envía, se pide el volumen completo de la
  /// oferta. Lanza [RepositoryException] con el motivo si la solicitud no es
  /// válida (volumen mayor al disponible, solicitud duplicada, oferta cerrada,
  /// usuario bloqueado o sin rol de importador, etc.).
  Future<void> sendCounterOffer({
    required String offerId,
    required double proposedPricePerMt,
    double? volumeMt,
    String? notes,
  });

  /// REQ-15: Permitir al exportador aceptar una solicitud de compra.
  Future<bool> acceptPurchaseRequest(String negotiationId);

  /// REQ-15: Permitir al exportador rechazar una solicitud de compra.
  Future<bool> rejectPurchaseRequest(String negotiationId, {String? reason});

  /// REQ-14 / REQ-15 / REQ-19: Consultar el listado de negociaciones del usuario.
  Future<List<PurchaseRequest>> fetchMyNegotiations();
}

/// Validación local de una solicitud antes de enviarla (evita una llamada a
/// la BD por errores evidentes). La BD repite estas reglas de todos modos.
void validatePurchaseRequestInput({
  required double proposedPricePerMt,
  double? volumeMt,
  String? notes,
}) {
  if (proposedPricePerMt <= 0) {
    throw const RepositoryException('El precio propuesto debe ser mayor que cero.');
  }
  if (volumeMt != null && volumeMt <= 0) {
    throw const RepositoryException('El volumen solicitado debe ser mayor que cero.');
  }
  if (notes != null && notes.length > maxPurchaseRequestNotesLength) {
    throw const RepositoryException(
        'Las notas no pueden superar los $maxPurchaseRequestNotesLength caracteres.');
  }
}

/// Implementación en memoria con datos de ejemplo para pruebas offline.
/// Replica las reglas de la BD (migración 20260925040000_purchase_request_rules).
class MockOfferRepository implements OfferRepository {
  static const _buyerId = 'demo-buyer';

  final List<PurchaseRequest> _mockNegotiations = [];
  int _nextId = 1;

  @override
  Future<List<CropOffer>> fetchOffers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List<CropOffer>.from(mockOffers);
  }

  @override
  Future<void> sendCounterOffer({
    required String offerId,
    required double proposedPricePerMt,
    double? volumeMt,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    validatePurchaseRequestInput(
      proposedPricePerMt: proposedPricePerMt,
      volumeMt: volumeMt,
      notes: notes,
    );

    final offer = mockOffers.where((o) => o.id == offerId).firstOrNull;
    if (offer == null) {
      throw const RepositoryException('La oferta no existe o fue eliminada.');
    }
    if (offer.status != OfferStatus.activa && offer.status != OfferStatus.negociando) {
      throw RepositoryException(
          'Esta oferta ya no recibe solicitudes (estado: ${offer.status.name}).');
    }
    final requested = volumeMt ?? offer.volumeMt;
    if (requested > offer.volumeMt) {
      throw RepositoryException(
          'El volumen solicitado ($requested MT) supera el disponible (${offer.volumeMt} MT).');
    }
    final hasActive = _mockNegotiations.any((n) =>
        n.offerId == offerId &&
        n.buyerId == _buyerId &&
        (n.status == NegotiationStatus.pending ||
            n.status == NegotiationStatus.countered));
    if (hasActive) {
      throw const RepositoryException('Ya tienes una solicitud activa para esta oferta.');
    }

    final now = DateTime.now();
    _mockNegotiations.add(
      PurchaseRequest(
        id: 'neg-${_nextId++}',
        offerId: offerId,
        buyerId: _buyerId,
        sellerId: offer.sellerId.isEmpty ? 'demo-seller' : offer.sellerId,
        proposedPricePerMt: proposedPricePerMt,
        requestedVolumeMt: requested,
        notes: notes,
        status: NegotiationStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
    );
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
