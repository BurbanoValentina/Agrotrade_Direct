import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:agrotrade_direct/data/repositories/certification_repository.dart';
import 'package:agrotrade_direct/data/repositories/repository_exception.dart';
import 'package:agrotrade_direct/data/repositories/supabase_error_mapper.dart';
import 'package:agrotrade_direct/models/certification.dart';
import 'package:agrotrade_direct/models/crop_offer.dart';

final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.7\n% certificado de prueba'));

Matcher _rejectedWith(String part) => throwsA(
    isA<RepositoryException>().having((e) => e.message, 'message', contains(part)));

void main() {
  group('Validación local del PDF', () {
    test('acepta un PDF válido', () {
      expect(() => validateCertificationInput(name: 'UTZ', pdfBytes: _pdf), returnsNormally);
    });

    test('rechaza archivos que no son PDF', () {
      expect(
          () => validateCertificationInput(
              name: 'UTZ', pdfBytes: Uint8List.fromList(utf8.encode('GIF89a...'))),
          throwsA(isA<RepositoryException>()));
    });

    test('rechaza archivos de más de 5 MB', () {
      final big = Uint8List(maxCertificationPdfBytes + 1)..setAll(0, _pdf);
      expect(() => validateCertificationInput(name: 'UTZ', pdfBytes: big),
          throwsA(isA<RepositoryException>()
              .having((e) => e.message, 'message', contains('5 MB'))));
    });

    test('rechaza certificados vencidos y nombres vacíos', () {
      expect(
          () => validateCertificationInput(
              name: 'UTZ', pdfBytes: _pdf, validUntil: DateTime(2026, 1, 1), now: DateTime(2026, 9, 27)),
          throwsA(isA<RepositoryException>()));
      expect(() => validateCertificationInput(name: ' ', pdfBytes: _pdf),
          throwsA(isA<RepositoryException>()));
    });
  });

  group('Flujo de verificación (mock)', () {
    late MockCertificationRepository repo;

    setUp(() => repo = MockCertificationRepository());

    test('el exportador sube el certificado y queda en revisión', () async {
      final cert = await repo.uploadCertification(name: ' UTZ ', pdfBytes: _pdf);
      expect(cert.status, CertificationStatus.pending);
      expect(cert.name, 'UTZ');
      expect(cert.filePath, startsWith('demo-seller/'));
      expect((await repo.fetchMyCertifications()).single.id, cert.id);
    });

    test('solo un admin con offerManagement revisa', () async {
      final cert = await repo.uploadCertification(name: 'UTZ', pdfBytes: _pdf);
      expect(repo.reviewCertification(cert.id, approve: true), _rejectedWith('offerManagement'));

      repo.isOfferManager = true;
      final verified = await repo.reviewCertification(cert.id, approve: true);
      expect(verified.status, CertificationStatus.verified);
      expect(verified.isActive(), isTrue);
    });

    test('rechazar exige motivo; rechazar un verificado lo revoca', () async {
      final cert = await repo.uploadCertification(name: 'Fair Trade', pdfBytes: _pdf);
      repo.isOfferManager = true;
      expect(repo.reviewCertification(cert.id, approve: false), _rejectedWith('motivo'));

      await repo.reviewCertification(cert.id, approve: true);
      final revoked = await repo.reviewCertification(cert.id,
          approve: false, reason: 'Revocado por el emisor');
      expect(revoked.status, CertificationStatus.rejected);
      expect(revoked.rejectionReason, 'Revocado por el emisor');
    });

    test('el exportador no puede borrar un certificado verificado', () async {
      final cert = await repo.uploadCertification(name: 'UTZ', pdfBytes: _pdf);
      repo.isOfferManager = true;
      await repo.reviewCertification(cert.id, approve: true);
      repo.isOfferManager = false;

      expect(repo.deleteCertification(cert.id), _rejectedWith('verificado'));
    });

    test('pendientes solo para admins', () async {
      await repo.uploadCertification(name: 'UTZ', pdfBytes: _pdf);
      expect(repo.fetchPendingCertifications(), throwsA(isA<RepositoryException>()));
      repo.isOfferManager = true;
      expect(await repo.fetchPendingCertifications(), hasLength(1));
    });
  });

  test('un certificado verificado pero vencido no cuenta como activo', () {
    final cert = Certification(
      id: 'c1',
      sellerId: 's1',
      name: 'UTZ',
      validUntil: DateTime(2026, 9, 1),
      filePath: 's1/c1.pdf',
      status: CertificationStatus.verified,
      createdAt: DateTime(2026, 1, 1),
    );
    expect(cert.isActive(DateTime(2026, 9, 27)), isFalse);
    expect(cert.isActive(DateTime(2026, 8, 1)), isTrue);
  });

  test('la oferta trae el sello verified_certifications desde Supabase', () {
    final offer = CropOffer.fromJson({
      'id': 'o1',
      'seller_id': 's1',
      'crop_type': 'cafe',
      'variety': 'Geisha',
      'certifications': ['UTZ', 'Fair Trade'],
      'verified_certifications': ['UTZ'],
      'created_at': '2026-09-27T10:00:00Z',
    });
    expect(offer.isCertificationVerified('utz'), isTrue);
    expect(offer.isCertificationVerified('Fair Trade'), isFalse);
  });

  group('Errores de Storage en español', () {
    test('archivo muy grande', () {
      expect(
          mapSupabaseError(const StorageException('The object exceeded the maximum allowed size',
                  statusCode: '413'))
              .message,
          contains('5 MB'));
    });

    test('tipo de archivo no permitido', () {
      expect(
          mapSupabaseError(const StorageException('mime type image/png is not supported',
                  statusCode: '415', error: 'invalid_mime_type'))
              .message,
          contains('PDF'));
    });

    test('sin permiso por la política del bucket', () {
      expect(
          mapSupabaseError(const StorageException(
                  'new row violates row-level security policy', statusCode: '403'))
              .message,
          contains('permiso'));
    });
  });
}
