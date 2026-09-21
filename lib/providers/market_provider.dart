import 'package:flutter/foundation.dart';

import '../data/repositories/offer_repository.dart';
import '../models/crop_offer.dart';

/// REQ-12: Modelo de datos para encapsular los criterios de filtro del mercado
class MarketFilterOptions {
  final MarketFilter category;
  final double? minPrice;
  final double? maxPrice;
  final double? minVolume;
  final String? destinationCountry;

  const MarketFilterOptions({
    this.category = MarketFilter.all,
    this.minPrice,
    this.maxPrice,
    this.minVolume,
    this.destinationCountry,
  });

  MarketFilterOptions copyWith({
    MarketFilter? category,
    double? minPrice,
    double? maxPrice,
    double? minVolume,
    String? destinationCountry,
  }) {
    return MarketFilterOptions(
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minVolume: minVolume ?? this.minVolume,
      destinationCountry: destinationCountry ?? this.destinationCountry,
    );
  }
}

/// Filtros de categoría básica
enum MarketFilter { all, cafe, cacao }

/// Maneja el estado del mercado (Live Market): ofertas, filtros avanzados y contraofertas.
class MarketProvider extends ChangeNotifier {
  MarketProvider(this._repository);

  final OfferRepository _repository;

  List<CropOffer> _offers = [];
  bool _isLoading = false;
  String? _errorMessage;
  MarketFilterOptions _filterOptions = const MarketFilterOptions();
  String _searchQuery = '';

  // Getters públicos
  List<CropOffer> get offers => _offers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MarketFilter get filter => _filterOptions.category;
  MarketFilterOptions get filterOptions => _filterOptions;
  String get searchQuery => _searchQuery;

  /// REQ-11 & REQ-12: Retorna las ofertas filtradas por texto, tipo, precio, volumen y destino
  List<CropOffer> get visibleOffers {
    return _offers.where((offer) {
      // 1. Filtro por categoría (Café / Cacao)
      final matchesCategory = switch (_filterOptions.category) {
        MarketFilter.all => true,
        MarketFilter.cafe => offer.cropType == CropType.cafe,
        MarketFilter.cacao => offer.cropType == CropType.cacao,
      };

      // 2. REQ-11: Filtro por texto de búsqueda (variedad o región)
      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          offer.variety.toLowerCase().contains(query) ||
          offer.originRegion.toLowerCase().contains(query);

      // 3. REQ-12: Filtro por rango de precio
      final matchesMinPrice = _filterOptions.minPrice == null ||
          offer.askPricePerMt >= _filterOptions.minPrice!;
      final matchesMaxPrice = _filterOptions.maxPrice == null ||
          offer.askPricePerMt <= _filterOptions.maxPrice!;

      // 4. REQ-12: Filtro por volumen mínimo
      final matchesVolume = _filterOptions.minVolume == null ||
          offer.volumeMt >= _filterOptions.minVolume!;

      // 5. REQ-12: Filtro por país de destino
      final destQuery =
          _filterOptions.destinationCountry?.toLowerCase().trim() ?? '';
      final matchesDestination = destQuery.isEmpty ||
          offer.destinationCountry.toLowerCase().contains(destQuery);

      return matchesCategory &&
          matchesQuery &&
          matchesMinPrice &&
          matchesMaxPrice &&
          matchesVolume &&
          matchesDestination;
    }).toList();
  }

  /// Carga la lista inicial de ofertas desde el repositorio
  Future<void> loadOffers() async {
    _setLoading(true);
    try {
      _offers = await _repository.fetchOffers();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'No pudimos cargar las ofertas del mercado.';
    } finally {
      _setLoading(false);
    }
  }

  /// REQ-06 a REQ-10: Publica una nueva oferta en el mercado
  Future<bool> addOffer(CropOffer offer) async {
    try {
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
      final success = await _repository.sendCounterOffer(
        offerId: offerId,
        proposedPricePerMt: newPrice,
      );
      if (success) {
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

  /// REQ-12: Actualiza la categoría del filtro rápido
  void setFilter(MarketFilter filter) {
    _filterOptions = _filterOptions.copyWith(category: filter);
    notifyListeners();
  }

  /// REQ-12: Aplica opciones de filtro avanzadas (precio, volumen, destino)
  void setAdvancedFilterOptions(MarketFilterOptions options) {
    _filterOptions = options;
    notifyListeners();
  }

  /// REQ-12: Restablece todos los filtros a sus valores predeterminados
  void resetFilters() {
    _filterOptions = const MarketFilterOptions();
    _searchQuery = '';
    notifyListeners();
  }

  /// REQ-11: Actualiza la consulta de búsqueda
  void setQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
