import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/crop_offer.dart';
import '../../models/negotiation_round.dart';
import '../../models/operation_record.dart';
import '../../models/purchase_request.dart';
import '../services/local_storage_service.dart';
import 'offer_repository.dart';
import 'repository_exception.dart';
import 'supabase_error_mapper.dart';

/// Implementación real de persistencia en Supabase (PostgreSQL).
/// Cumple con REQ-06 a REQ-10 (publicar y administrar ofertas), REQ-11 y
/// REQ-13 (lectura), REQ-14 (solicitud de compra), REQ-15 a REQ-17
/// (negociación vía RPC) y REQ-27 (caché local para modo offline).
class SupabaseOfferRepository implements OfferRepository {
  final SupabaseClient _supabase;
  final LocalStorageService _cache;

  SupabaseOfferRepository({SupabaseClient? client, LocalStorageService? cache})
      : _supabase = client ?? Supabase.instance.client,
        _cache = cache ?? LocalStorageService();

  static const _offerColumns =
      '*, verified_certifications, profiles:seller_id(name, rating, completed_trades)';

  /// Ofertas del Market. Si no hay conexión devuelve la última copia guardada
  /// en el teléfono (REQ-27); si tampoco hay copia, lanza el error real. Nunca
  /// devuelve datos de ejemplo: sus ids no existen en la base.
  @override
  Future<List<CropOffer>> fetchOffers() async {
    try {
      final response =
          await _supabase.from('offers').select(_offerColumns).order('created_at', ascending: false);
      final list = (response as List<dynamic>)
          .map((json) => CropOffer.fromJson(json as Map<String, dynamic>))
          .toList();
      await _cacheQuietly(list);
      return list;
    } catch (e) {
      final cached = await _cachedQuietly();
      if (cached.isNotEmpty) return cached;
      throw mapSupabaseError(e);
    }
  }

  Future<void> _cacheQuietly(List<CropOffer> offers) async {
    try {
      await _cache.cacheOffers(offers);
    } catch (_) {
      // Sin almacenamiento local disponible (ej. pruebas): no es un error.
    }
  }

  Future<List<CropOffer>> _cachedQuietly() async {
    try {
      return await _cache.getCachedOffers();
    } catch (_) {
      return const [];
    }
  }

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const RepositoryException('Debes iniciar sesión.');
    }
    return user.id;
  }

  /// REQ-06 a REQ-10: publica la oferta. La BD fija el vendedor (usuario
  /// actual) y el estado inicial `activa`; devuelve la oferta guardada con su id real.
  @override
  Future<CropOffer> publishOffer(CropOffer offer) async {
    validateOfferInput(
      variety: offer.variety,
      originRegion: offer.originRegion,
      destinationCountry: offer.destinationCountry,
      askPricePerMt: offer.askPricePerMt,
      volumeMt: offer.volumeMt,
    );
    final userId = _userId;
    try {
      final row = await _supabase
          .from('offers')
          .insert({
            'seller_id': userId,
            'crop_type': offer.cropType.name,
            'variety': offer.variety.trim(),
            'origin_region': offer.originRegion.trim(),
            'origin_country': offer.originCountry.trim().isEmpty ? 'Colombia' : offer.originCountry.trim(),
            'ask_price_per_mt': offer.askPricePerMt,
            'volume_mt': offer.volumeMt,
            'destination_country': offer.destinationCountry.trim(),
            'certifications': offer.certifications,
          })
          .select(_offerColumns)
          .single();
      return CropOffer.fromJson(row);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<CropOffer> updateOffer(
    String offerId, {
    double? askPricePerMt,
    double? volumeMt,
    String? destinationCountry,
    List<String>? certifications,
  }) async {
    if (askPricePerMt != null && askPricePerMt <= 0) {
      throw const RepositoryException('El precio por tonelada debe ser mayor que cero.');
    }
    if (volumeMt != null && volumeMt <= 0) {
      throw const RepositoryException(
          'La cantidad disponible debe ser mayor que cero; para retirar la oferta, ciérrala.');
    }
    final changes = {
      if (askPricePerMt != null) 'ask_price_per_mt': askPricePerMt,
      if (volumeMt != null) 'volume_mt': volumeMt,
      if (destinationCountry != null) 'destination_country': destinationCountry.trim(),
      if (certifications != null) 'certifications': certifications,
    };
    if (changes.isEmpty) {
      throw const RepositoryException('No hay cambios para guardar.');
    }
    return _updateOwnOffer(offerId, changes);
  }

  @override
  Future<CropOffer> closeOffer(String offerId) => _updateOwnOffer(offerId, {'status': 'cerrada'});

  Future<CropOffer> _updateOwnOffer(String offerId, Map<String, dynamic> changes) async {
    final userId = _userId;
    final List<dynamic> rows;
    try {
      rows = await _supabase
          .from('offers')
          .update(changes)
          .eq('id', offerId)
          .eq('seller_id', userId)
          .select(_offerColumns);
    } catch (e) {
      throw mapSupabaseError(e);
    }
    if (rows.isEmpty) {
      throw const RepositoryException('La oferta no existe o no es tuya.');
    }
    return CropOffer.fromJson(rows.first as Map<String, dynamic>);
  }

  /// Ofertas del exportador actual, de la más reciente a la más antigua.
  @override
  Future<List<CropOffer>> fetchMyOffers() async {
    final userId = _userId;
    try {
      final rows = await _supabase
          .from('offers')
          .select(_offerColumns)
          .eq('seller_id', userId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((json) => CropOffer.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// REQ-14: Enviar solicitud de compra sobre una oferta.
  ///
  /// Inserta en `negotiations`; la BD completa `seller_id` (y el volumen si no
  /// se envía) a partir de la oferta y valida todas las reglas, devolviendo el
  /// motivo exacto si la rechaza (trigger validate_purchase_request).
  @override
  Future<void> sendCounterOffer({
    required String offerId,
    required double proposedPricePerMt,
    double? volumeMt,
    String? notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const RepositoryException('Debes iniciar sesión para enviar una solicitud de compra.');
    }

    final trimmedNotes = notes?.trim();
    validatePurchaseRequestInput(
      proposedPricePerMt: proposedPricePerMt,
      volumeMt: volumeMt,
      notes: trimmedNotes,
    );

    try {
      await _supabase.from('negotiations').insert({
        'offer_id': offerId,
        'buyer_id': user.id,
        'proposed_price_per_mt': proposedPricePerMt,
        if (volumeMt != null) 'requested_volume_mt': volumeMt,
        if (trimmedNotes != null && trimmedNotes.isNotEmpty) 'notes': trimmedNotes,
      });
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// Ejecuta una función de negociación (RPC) y devuelve la negociación
  /// actualizada. Las reglas (turno, rondas, estado) viven en la BD:
  /// supabase/migrations/20260926000000_negotiation_flow.sql.
  Future<PurchaseRequest> _negotiationRpc(String function, Map<String, dynamic> params) async {
    try {
      final row = await _supabase.rpc(function, params: params);
      return PurchaseRequest.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  static String? _clean(String? text) {
    final trimmed = text?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// REQ-16: contraoferta de quien tiene el turno.
  @override
  Future<PurchaseRequest> counterOffer({
    required String negotiationId,
    required double pricePerMt,
    double? volumeMt,
    String? message,
  }) {
    validatePurchaseRequestInput(
      proposedPricePerMt: pricePerMt,
      volumeMt: volumeMt,
      notes: _clean(message),
    );
    return _negotiationRpc('counter_offer', {
      'p_negotiation_id': negotiationId,
      'p_price_per_mt': pricePerMt,
      'p_volume_mt': volumeMt,
      'p_message': _clean(message),
    });
  }

  /// REQ-15: aceptar la propuesta vigente (debe ser tu turno).
  @override
  Future<PurchaseRequest> acceptPurchaseRequest(String negotiationId) {
    return _negotiationRpc('accept_negotiation', {'p_negotiation_id': negotiationId});
  }

  /// REQ-15: rechazar la propuesta vigente (debe ser tu turno).
  @override
  Future<PurchaseRequest> rejectPurchaseRequest(String negotiationId, {String? reason}) {
    return _negotiationRpc('reject_negotiation', {
      'p_negotiation_id': negotiationId,
      'p_reason': _clean(reason),
    });
  }

  @override
  Future<PurchaseRequest> cancelNegotiation(String negotiationId, {String? reason}) {
    return _negotiationRpc('cancel_negotiation', {
      'p_negotiation_id': negotiationId,
      'p_reason': _clean(reason),
    });
  }

  /// REQ-17: confirmar el acuerdo; se cierra cuando confirman ambas partes.
  @override
  Future<PurchaseRequest> confirmNegotiation(String negotiationId) {
    return _negotiationRpc('confirm_negotiation', {'p_negotiation_id': negotiationId});
  }

  /// REQ-16 / REQ-19: historial de propuestas de la negociación.
  @override
  Future<List<NegotiationRound>> fetchNegotiationRounds(String negotiationId) async {
    try {
      final response = await _supabase
          .from('negotiation_rounds')
          .select()
          .eq('negotiation_id', negotiationId)
          .order('round_number');
      return (response as List<dynamic>)
          .map((json) => NegotiationRound.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// REQ-19: operaciones cerradas del usuario (rpc my_operation_history).
  @override
  Future<List<OperationRecord>> fetchOperationHistory({
    DateTime? from,
    DateTime? to,
    NegotiationStatus? status,
  }) async {
    validateHistoryStatus(status);
    try {
      final rows = await _supabase.rpc('my_operation_history', params: {
        'p_from': from?.toUtc().toIso8601String(),
        'p_to': to?.toUtc().toIso8601String(),
        'p_status': status?.name,
      });
      return (rows as List<dynamic>)
          .map((json) => OperationRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// REQ-19: línea de tiempo de una operación (rpc negotiation_timeline).
  @override
  Future<List<TimelineEvent>> fetchNegotiationTimeline(String negotiationId) async {
    try {
      final rows = await _supabase
          .rpc('negotiation_timeline', params: {'p_negotiation_id': negotiationId});
      return (rows as List<dynamic>)
          .map((json) => TimelineEvent.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  /// REQ-14 / REQ-15 / REQ-19: negociaciones del usuario actual (My Deals).
  @override
  Future<List<PurchaseRequest>> fetchMyNegotiations() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('negotiations')
          .select('''
            *,
            offers (variety),
            seller:seller_id (name),
            buyer:buyer_id (name)
          ''')
          .or('buyer_id.eq.${user.id},seller_id.eq.${user.id}')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => PurchaseRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }
}
