import 'package:flutter_test/flutter_test.dart';

import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/models/crop_offer.dart';
import 'package:agrotrade_direct/providers/market_provider.dart';

/// Repositorio que siempre falla, para probar el manejo de errores.
class _FailingOfferRepository extends MockOfferRepository {
  @override
  Future<List<CropOffer>> fetchOffers() async {
    throw const RepositoryException('No se pudo conectar con el servidor.');
  }
}

void main() {
  test('sendCounterOffer devuelve true y limpia lastError si se envía', () async {
    final market = MarketProvider(MockOfferRepository());

    final ok = await market.sendCounterOffer('off-001', 8000, volumeMt: 5, notes: 'FOB');

    expect(ok, isTrue);
    expect(market.lastError, isNull);
  });

  test('sendCounterOffer devuelve false con el motivo en lastError', () async {
    final market = MarketProvider(MockOfferRepository());

    final ok = await market.sendCounterOffer('off-001', 8000, volumeMt: 99);

    expect(ok, isFalse);
    expect(market.lastError, contains('supera el disponible'));
  });

  test('loadOffers no se queda cargando si el repositorio falla', () async {
    final market = MarketProvider(_FailingOfferRepository());

    await market.loadOffers();

    expect(market.isLoading, isFalse);
    expect(market.loadError, contains('No se pudo conectar'));
  });
}
