import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/crop_offer.dart';
import '../../models/negotiation_round.dart';
import '../../models/purchase_request.dart';
import 'offer_repository.dart';
import 'repository_exception.dart';
import 'supabase_error_mapper.dart';

/// Implementación real de persistencia en Supabase (PostgreSQL).
/// Cumple con REQ-11, REQ-13 (lectura de ofertas), REQ-14 (solicitud de compra)
/// y REQ-15 a REQ-17 (contraofertas, aceptar/rechazar y confirmar vía RPC).
class SupabaseOfferRepository implements OfferRepository {
  final SupabaseClient _supabase;

  SupabaseOfferRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  @override
  Future<List<CropOffer>> fetchOffers() async {
    try {
      final response = await _supabase
          .from('offers')
          .select('*, profiles:seller_id(name, rating, completed_trades)')
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((json) => CropOffer.fromJson(json as Map<String, dynamic>))
          .toList();

      return list;
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
