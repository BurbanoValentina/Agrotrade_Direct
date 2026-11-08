import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agrotrade_direct/data/repositories/offer_repository.dart';
import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/data/services/local_storage_service.dart';
import 'package:agrotrade_direct/models/crop_offer.dart';
import 'package:agrotrade_direct/models/purchase_request.dart';
import 'package:agrotrade_direct/providers/market_provider.dart';

const _seller = MockOfferRepository.demoSellerId;
const _buyer = MockOfferRepository.demoBuyerId;

Matcher _rejectedWith(String part) => throwsA(
    isA<RepositoryException>().having((e) => e.message, 'message', contains(part)));

/// Oferta tal como la arma el formulario de publicación (id temporal, sin vendedor).
CropOffer _draft({double price = 8000, double volume = 20, String variety = 'Geisha'}) {
  return CropOffer(
    id: 'offer_temporal',
    cropType: CropType.cafe,
    variety: variety,
    originRegion: 'Huila',
    originCountry: 'Colombia',
    askPricePerMt: price,
    volumeMt: volume,
    destinationCountry: 'Alemania',
    certifications: const ['UTZ'],
    sellerName: 'Exportador Demo',
    sellerRating: 5,
    sellerTrades: 0,
    status: OfferStatus.confirmada, // se ignora: toda oferta nace activa
    postedAt: DateTime(2026, 11, 5),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('REQ-06 a REQ-10: publicar ofertas', () {
    test('la oferta queda a nombre del exportador, activa y con id propio', () async {
      final repo = MockOfferRepository(currentUserId: _seller);

      final saved = await repo.publishOffer(_draft());

      expect(saved.id, isNot('offer_temporal'));
      expect(saved.sellerId, _seller);
      expect(saved.status, OfferStatus.activa);
      expect((await repo.fetchMyOffers()).first.id, saved.id);
    });

    test('rechaza precio o cantidad en cero y variedad vacía', () {
      final repo = MockOfferRepository(currentUserId: _seller);
      expect(repo.publishOffer(_draft(price: 0)), _rejectedWith('precio'));
      expect(repo.publishOffer(_draft(volume: 0)), _rejectedWith('cantidad'));
      expect(repo.publishOffer(_draft(variety: ' ')), _rejectedWith('variedad'));
    });

    test('MarketProvider.addOffer guarda en el repositorio y muestra la oferta real', () async {
      final market = MarketProvider(MockOfferRepository(currentUserId: _seller));

      expect(await market.addOffer(_draft()), isTrue);
      expect(market.offers.first.sellerId, _seller);

      expect(await market.addOffer(_draft(price: -1)), isFalse);
      expect(market.lastError, contains('precio'));
    });
  });

  group('Editar y cerrar ofertas', () {
    late MockOfferRepository repo;
    late CropOffer offer;

    setUp(() async {
      repo = MockOfferRepository(currentUserId: _seller);
      offer = await repo.publishOffer(_draft(volume: 20));
    });

    test('el exportador ajusta precio, cantidad y destino', () async {
      final updated = await repo.updateOffer(offer.id,
          askPricePerMt: 8200, volumeMt: 25, destinationCountry: 'Bélgica');
      expect(updated.askPricePerMt, 8200);
      expect(updated.volumeMt, 25);
      expect(updated.destinationCountry, 'Bélgica');
    });

    test('nadie más puede editar la oferta', () {
      repo.currentUserId = _buyer;
      expect(repo.updateOffer(offer.id, askPricePerMt: 1), _rejectedWith('no es tuya'));
    });

    test('no se baja la cantidad por debajo de un acuerdo aceptado', () async {
      repo.currentUserId = _buyer;
      await repo.sendCounterOffer(offerId: offer.id, proposedPricePerMt: 8000, volumeMt: 15);
      final neg = (await repo.fetchMyNegotiations()).single;
      repo.currentUserId = _seller;
      await repo.acceptPurchaseRequest(neg.id);

      expect(repo.updateOffer(offer.id, volumeMt: 10), _rejectedWith('comprometidos'));
      expect(repo.closeOffer(offer.id), _rejectedWith('acuerdo aceptado'));
    });

    test('al cerrar, las solicitudes en curso se cancelan y ya no se puede editar', () async {
      repo.currentUserId = _buyer;
      await repo.sendCounterOffer(offerId: offer.id, proposedPricePerMt: 7900, volumeMt: 5);
      repo.currentUserId = _seller;

      final closed = await repo.closeOffer(offer.id);
      expect(closed.status, OfferStatus.cerrada);

      repo.currentUserId = _buyer;
      final neg = (await repo.fetchMyNegotiations()).single;
      expect(neg.status, NegotiationStatus.cancelled);
      expect(neg.closeReason, 'El exportador cerró la oferta.');

      repo.currentUserId = _seller;
      expect(repo.updateOffer(offer.id, askPricePerMt: 9000), _rejectedWith('ya no se puede editar'));
    });
  });

  test('la copia offline conserva vendedor, estado cerrada y certificaciones verificadas', () async {
    final repo = MockOfferRepository(currentUserId: _seller);
    final closed = await repo.closeOffer((await repo.publishOffer(_draft())).id);
    final withBadge = CropOffer.fromJson({
      'id': closed.id,
      'seller_id': _seller,
      'variety': 'Geisha',
      'status': 'cerrada',
      'certifications': ['UTZ'],
      'verified_certifications': ['UTZ'],
      'created_at': '2026-11-05T10:00:00Z',
    });

    final cache = LocalStorageService();
    await cache.cacheOffers([withBadge]);
    final restored = (await cache.getCachedOffers()).single;

    expect(restored.sellerId, _seller);
    expect(restored.status, OfferStatus.cerrada);
    expect(restored.isCertificationVerified('UTZ'), isTrue);
  });

  test('el estado cerrada llega desde Supabase', () {
    final offer = CropOffer.fromJson({
      'id': 'o1',
      'crop_type': 'cacao',
      'variety': 'Criollo',
      'status': 'cerrada',
      'created_at': '2026-11-05T10:00:00Z',
    });
    expect(offer.status, OfferStatus.cerrada);
    expect(offer.status.label, 'CLOSED');
  });
}
