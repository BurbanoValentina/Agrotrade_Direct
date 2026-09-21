import 'package:flutter/foundation.dart';

import '../data/repositories/offer_repository.dart';
import '../models/crop_offer.dart';

/// Filtros de búsqueda para el mercado
enum MarketFilter { all, cafe, cacao }

/// Maneja el estado del mercado (Live Market): ofertas, filtros y contraofertas.
class MarketProvider extends ChangeNotifier {
  MarketProvider(this._repository);

  final OfferRepository _repository;

  List<CropOffer> _offers = [];
  bool _isLoading = false;
  String? _errorMessage;
  MarketFilter _filter = MarketFilter.all;
  String _searchQuery = '';

  // Getters públicos para el acceso de solo lectura desde la UI
  List<CropOffer> get offers => _offers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MarketFilter get filter => _filter;
  String get searchQuery => _searchQuery;

  /// Retorna la lista de ofertas filtrada por tipo de grano y por texto de búsqueda
  List<CropOffer> get visibleOffers {
    return _offers.where((offer) {
      // Filtro por categoría (Café / Cacao)
      final matchesFilter = switch (_filter) {
        MarketFilter.all => true,
        MarketFilter.cafe => offer.cropType == CropType.cafe,
        MarketFilter.cacao => offer.cropType == CropType.cacao,
      };

      // Filtro por texto de búsqueda (variedad o región)
      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          offer.variety.toLowerCase().contains(query) ||
          offer.originRegion.toLowerCase().contains(query);

      return matchesFilter && matchesQuery;
    }).toList();
  }

  /// Carga la lista inicial de ofertas desde el repositorio
  Future<void> loadOffers() async {
    _setLoading(true);
    try {
      // CORREGIDO: Se llama a fetchOffers() en lugar de getOffers()
      _offers = await _repository.fetchOffers();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'No pudimos cargar las ofertas del mercado.';
    } finally {
      _setLoading(false);
    }
  }

  /// REQ-06 a REQ-10: Publica una nueva oferta en la lista activa del mercado
  Future<bool> addOffer(CropOffer offer) async {
    try {
      // Inserta la oferta al inicio de la lista local
      _offers.insert(0, offer);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// REQ-16: Envía una contraoferta de precio
  Future<bool> sendCounterOffer(String offerId, double newPrice) async {
    try {
      // CORREGIDO: Se envían los nombres exactos de parámetros que exige la interfaz
      final success = await _repository.sendCounterOffer(
        offerId: offerId,
        proposedPricePerMt: newPrice,
      );
      if (success) {
        // Actualiza el estado local de la oferta
        final index = _offers.indexWhere((o) => o.id == offerId);
        if (index != -1) {
          final old = _offers[index];
          _offers[index] = CropOffer(
            id: old.id,
            cropType: old.cropType,
            variety: old.variety,
            originRegion: old.originRegion,
            originCountry: old.originCountry,
            askPricePerMt: newPrice,
            volumeMt: old.volumeMt,
            destinationCountry: old.destinationCountry,
            certifications: old.certifications,
            sellerName: old.sellerName,
            sellerRating: old.sellerRating,
            sellerTrades: old.sellerTrades,
            status: OfferStatus.negociando,
            postedAt: old.postedAt,
          );
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Establece el filtro de categoría seleccionada
  void setFilter(MarketFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  /// Establece la cadena de texto para la búsqueda
  void setQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
