import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/certification.dart';
import 'certification_repository.dart';
import 'repository_exception.dart';
import 'supabase_error_mapper.dart';

/// REQ-36 con Supabase: PDF en el bucket privado `certifications` y registro
/// en la tabla `certifications` (migración 20260927000000_certifications).
class SupabaseCertificationRepository implements CertificationRepository {
  SupabaseCertificationRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const _bucket = 'certifications';
  static final _random = Random.secure();

  StorageFileApi get _files => _supabase.storage.from(_bucket);

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const RepositoryException('Debes iniciar sesión.');
    }
    return user.id;
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<Certification> uploadCertification({
    required String name,
    required Uint8List pdfBytes,
    String? certificateNumber,
    DateTime? validUntil,
  }) async {
    validateCertificationInput(
      name: name,
      pdfBytes: pdfBytes,
      certificateNumber: certificateNumber,
      validUntil: validUntil,
    );
    final userId = _userId;
    // La carpeta debe ser el id del usuario (lo exige la política del bucket).
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}'
        '-${_random.nextInt(1 << 32).toRadixString(16)}.pdf';

    try {
      await _files.uploadBinary(
        path,
        pdfBytes,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: false),
      );
    } catch (e) {
      throw mapSupabaseError(e);
    }

    try {
      final row = await _supabase
          .from('certifications')
          .insert({
            'seller_id': userId,
            'name': name.trim(),
            if (certificateNumber != null && certificateNumber.trim().isNotEmpty)
              'certificate_number': certificateNumber.trim(),
            if (validUntil != null) 'valid_until': _dateOnly(validUntil),
            'file_path': path,
          })
          .select()
          .single();
      return Certification.fromJson(row);
    } catch (e) {
      // No dejar el PDF huérfano si el registro fue rechazado.
      await _removeFileQuietly(path);
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<List<Certification>> fetchMyCertifications() async {
    final userId = _userId;
    try {
      final rows = await _supabase
          .from('certifications')
          .select()
          .eq('seller_id', userId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((r) => Certification.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<List<Certification>> fetchPendingCertifications() async {
    try {
      final rows = await _supabase
          .from('certifications')
          .select('*, seller:seller_id (name)')
          .eq('status', 'pending')
          .order('created_at');
      return (rows as List<dynamic>)
          .map((r) => Certification.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<Certification> reviewCertification(
    String certificationId, {
    required bool approve,
    String? reason,
  }) async {
    try {
      final row = await _supabase.rpc('review_certification', params: {
        'p_certification_id': certificationId,
        'p_approve': approve,
        'p_reason': reason?.trim(),
      });
      return Certification.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  @override
  Future<void> deleteCertification(String certificationId) async {
    final List<dynamic> deleted;
    try {
      deleted = await _supabase
          .from('certifications')
          .delete()
          .eq('id', certificationId)
          .select('file_path');
    } catch (e) {
      throw mapSupabaseError(e);
    }
    if (deleted.isEmpty) {
      throw const RepositoryException(
          'No se pudo borrar: un certificado verificado solo lo puede retirar soporte.');
    }
    await _removeFileQuietly((deleted.first as Map<String, dynamic>)['file_path'] as String);
  }

  @override
  Future<String> getCertificationFileUrl(Certification certification) async {
    try {
      return await _files.createSignedUrl(certification.filePath, 3600);
    } catch (e) {
      throw mapSupabaseError(e);
    }
  }

  Future<void> _removeFileQuietly(String path) async {
    try {
      await _files.remove([path]);
    } catch (e) {
      debugPrint('No se pudo borrar el archivo $path del bucket: $e');
    }
  }
}
