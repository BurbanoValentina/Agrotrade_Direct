import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/crop_offer.dart';
import '../../models/purchase_request.dart';
import 'offer_repository.dart';
import 'repository_exception.dart';
import 'supabase_error_mapper.dart';

/// Implementación real de persistencia en Supabase (PostgreSQL).
/// Cumple con REQ-11, REQ-13 (Lectura de ofertas) y REQ-14 (Envío de solicitud/contraoferta de compra).
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

  /// REQ-15: Permitir al exportador aceptar una solicitud de compra recibida.
  @override
  Future<bool> acceptPurchaseRequest(String negotiationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw StateError('Debe iniciar sesión como exportador para aceptar solicitudes.');
      }

      // 1. Actualizar el estado de la negociación a 'accepted'
      final response = await _supabase
          .from('negotiations')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', negotiationId)
          .eq('seller_id', user.id)
          .select('offer_id')
          .single();

      final offerId = response['offer_id'] as String?;

      // 2. Actualizar el estado de la oferta a 'confirmada'
      if (offerId != null) {
        await _supabase
            .from('offers')
            .update({
              'status': 'confirmada',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', offerId)
            .eq('seller_id', user.id);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// REQ-15: Permitir al exportador rechazar una solicitud de compra recibida.
  @override
  Future<bool> rejectPurchaseRequest(String negotiationId, {String? reason}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw StateError('Debe iniciar sesión como exportador para rechazar solicitudes.');
      }

      await _supabase
          .from('negotiations')
          .update({
            'status': 'rejected',
            if (reason != null && reason.trim().isNotEmpty) 'notes': reason.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', negotiationId)
          .eq('seller_id', user.id);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// REQ-14 / REQ-15 / REQ-19: Obtener las solicitudes de negociación del usuario actual (My Deals).
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
      return [];
    }
  }
}
