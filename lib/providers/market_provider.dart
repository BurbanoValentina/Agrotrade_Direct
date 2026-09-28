import 'package:flutter/foundation.dart';

import '../data/repositories/offer_repository.dart';
import '../data/repositories/repository_exception.dart';
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

  String? _loadError;
  String? _lastError;

  bool get isLoading => _isLoading;
  MarketFilter get filter => _filter;
  String get query => _query;

  /// Motivo por el que falló la última carga de ofertas (null si cargó bien).
  String? get loadError => _loadError;

  /// Motivo por el que falló la última solicitud enviada (null si se envió).
  String? get lastError => _lastError;

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
    _loadError = null;
    notifyListeners();
    try {
      _allOffers = await _repository.fetchOffers();
    } on RepositoryException catch (e) {
      _loadError = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(MarketFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  /// REQ-14: envía una solicitud de compra. Devuelve `true` si se envió; si no,
  /// el motivo queda en [lastError] para mostrarlo al usuario.
  Future<bool> sendCounterOffer(
    String offerId,
    double proposedPrice, {
    double? volumeMt,
    String? notes,
  }) async {
    try {
      await _repository.sendCounterOffer(
        offerId: offerId,
        proposedPricePerMt: proposedPrice,
        volumeMt: volumeMt,
        notes: notes,
      );
      _lastError = null;
      return true;
    } on RepositoryException catch (e) {
      _lastError = e.message;
      return false;
    }
  }
}
