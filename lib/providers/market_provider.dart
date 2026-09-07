import 'package:flutter/foundation.dart';

import '../data/repositories/offer_repository.dart';
import '../models/crop_offer.dart';

enum MarketFilter { all, cafe, cacao }

/// Estado de la pantalla "Live Market": lista de ofertas, filtro activo y
/// texto de búsqueda (REQ-11, REQ-12, REQ-13).
class MarketProvider extends ChangeNotifier {
  MarketProvider(this._repository);

  final OfferRepository _repository;

  List<CropOffer> _allOffers = [];
  MarketFilter _filter = MarketFilter.all;
  String _query = '';
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  MarketFilter get filter => _filter;
  String get query => _query;

  List<CropOffer> get visibleOffers {
    return _allOffers.where((offer) {
      final matchesFilter = switch (_filter) {
        MarketFilter.all => true,
        MarketFilter.cafe => offer.cropType == CropType.cafe,
        MarketFilter.cacao => offer.cropType == CropType.cacao,
      };
      final matchesQuery = _query.isEmpty ||
          offer.variety.toLowerCase().contains(_query.toLowerCase()) ||
          offer.originRegion.toLowerCase().contains(_query.toLowerCase());
      return matchesFilter && matchesQuery;
    }).toList();
  }

  Future<void> loadOffers() async {
    _isLoading = true;
    notifyListeners();
    _allOffers = await _repository.fetchOffers();
    _isLoading = false;
    notifyListeners();
  }

  void setFilter(MarketFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  Future<bool> sendCounterOffer(String offerId, double proposedPrice) {
    return _repository.sendCounterOffer(
      offerId: offerId,
      proposedPricePerMt: proposedPrice,
    );
  }
}
