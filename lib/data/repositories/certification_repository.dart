import 'dart:typed_data';

import '../../models/certification.dart';
import 'repository_exception.dart';

/// Tamaño máximo del PDF de un certificado (igual que el bucket: 5 MB).
const int maxCertificationPdfBytes = 5 * 1024 * 1024;

/// REQ-36: certificados de los exportadores y su verificación.
///
/// Flujo: el exportador sube el PDF → `pending` → un admin con permiso
/// `offerManagement` lo aprueba (`verified`) o rechaza (`rejected`, con motivo).
/// El PDF solo lo pueden abrir su dueño y esos admins. Todos los métodos lanzan
/// [RepositoryException] con el motivo.
abstract class CertificationRepository {
  /// El exportador sube el PDF y registra el certificado (queda `pending`).
  Future<Certification> uploadCertification({
    required String name,
    required Uint8List pdfBytes,
    String? certificateNumber,
    DateTime? validUntil,
  });

  /// Certificados del exportador actual, del más reciente al más antiguo.
  Future<List<Certification>> fetchMyCertifications();

  /// Admin: certificados pendientes de revisión, del más antiguo al más nuevo.
  Future<List<Certification>> fetchPendingCertifications();

  /// Admin: aprueba o rechaza ([reason] es obligatorio al rechazar). Rechazar
  /// uno verificado lo revoca.
  Future<Certification> reviewCertification(
    String certificationId, {
    required bool approve,
    String? reason,
  });

  /// Borra un certificado pendiente o rechazado (y su PDF).
  Future<void> deleteCertification(String certificationId);

  /// Enlace temporal (1 hora) para abrir el PDF. Solo dueño y admins.
  Future<String> getCertificationFileUrl(Certification certification);
}

/// Validación local antes de subir: nombre, tamaño, formato PDF y vigencia.
void validateCertificationInput({
  required String name,
  required Uint8List pdfBytes,
  String? certificateNumber,
  DateTime? validUntil,
  DateTime? now,
}) {
  final trimmed = name.trim();
  if (trimmed.length < 2 || trimmed.length > 80) {
    throw const RepositoryException(
        'Escribe el nombre de la certificación (entre 2 y 80 caracteres).');
  }
  if (certificateNumber != null && certificateNumber.length > 80) {
    throw const RepositoryException('El número de certificado es demasiado largo.');
  }
  if (pdfBytes.isEmpty) {
    throw const RepositoryException('El archivo está vacío.');
  }
  if (pdfBytes.length > maxCertificationPdfBytes) {
    throw const RepositoryException('El PDF no puede superar los 5 MB.');
  }
  // Todo PDF empieza con "%PDF-".
  const magic = [0x25, 0x50, 0x44, 0x46, 0x2D];
  if (pdfBytes.length < magic.length ||
      !List.generate(magic.length, (i) => pdfBytes[i] == magic[i]).every((ok) => ok)) {
    throw const RepositoryException('El archivo debe ser un PDF.');
  }
  if (validUntil != null) {
    final today = now ?? DateTime.now();
    if (validUntil.isBefore(DateTime(today.year, today.month, today.day))) {
      throw const RepositoryException('La certificación ya está vencida.');
    }
  }
}

/// Implementación en memoria para desarrollar la UI sin Supabase. Replica las
/// reglas de la migración 20260927000000_certifications. Las acciones se hacen
/// en nombre de [currentUserId]; [isOfferManager] simula el permiso de admin.
class MockCertificationRepository implements CertificationRepository {
  MockCertificationRepository({
    this.currentUserId = 'demo-seller',
    this.isOfferManager = false,
  });

  String currentUserId;
  bool isOfferManager;

  final List<Certification> _certifications = [];
  int _nextId = 1;

  Certification _find(String id) {
    final cert = _certifications.where((c) => c.id == id).firstOrNull;
    if (cert == null || (cert.sellerId != currentUserId && !isOfferManager)) {
      throw const RepositoryException('El certificado no existe.');
    }
    return cert;
  }

  @override
  Future<Certification> uploadCertification({
    required String name,
    required Uint8List pdfBytes,
    String? certificateNumber,
    DateTime? validUntil,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    validateCertificationInput(
      name: name,
      pdfBytes: pdfBytes,
      certificateNumber: certificateNumber,
      validUntil: validUntil,
    );
    final id = 'cert-${_nextId++}';
    final cert = Certification(
      id: id,
      sellerId: currentUserId,
      name: name.trim(),
      certificateNumber: certificateNumber,
      validUntil: validUntil,
      filePath: '$currentUserId/$id.pdf',
      status: CertificationStatus.pending,
      createdAt: DateTime.now(),
    );
    _certifications.add(cert);
    return cert;
  }

  @override
  Future<List<Certification>> fetchMyCertifications() async {
    return _certifications.where((c) => c.sellerId == currentUserId).toList().reversed.toList();
  }

  @override
  Future<List<Certification>> fetchPendingCertifications() async {
    if (!isOfferManager) {
      throw const RepositoryException('Requiere el permiso offerManagement.');
    }
    return _certifications.where((c) => c.status == CertificationStatus.pending).toList();
  }

  @override
  Future<Certification> reviewCertification(
    String certificationId, {
    required bool approve,
    String? reason,
  }) async {
    if (!isOfferManager) {
      throw const RepositoryException('Requiere el permiso offerManagement.');
    }
    final cert = _find(certificationId);
    if (approve && cert.status != CertificationStatus.pending) {
      throw RepositoryException(
          'Solo se puede aprobar un certificado pendiente (estado: ${cert.status.name}).');
    }
    if (approve && cert.isExpired()) {
      throw const RepositoryException('No se puede aprobar: la certificación está vencida.');
    }
    if (!approve && cert.status == CertificationStatus.rejected) {
      throw const RepositoryException('El certificado ya está rechazado.');
    }
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      throw const RepositoryException('Indica el motivo del rechazo.');
    }
    final reviewed = Certification(
      id: cert.id,
      sellerId: cert.sellerId,
      name: cert.name,
      certificateNumber: cert.certificateNumber,
      validUntil: cert.validUntil,
      filePath: cert.filePath,
      status: approve ? CertificationStatus.verified : CertificationStatus.rejected,
      rejectionReason: approve ? null : reason!.trim(),
      reviewedBy: currentUserId,
      reviewedAt: DateTime.now(),
      createdAt: cert.createdAt,
    );
    _certifications[_certifications.indexOf(cert)] = reviewed;
    return reviewed;
  }

  @override
  Future<void> deleteCertification(String certificationId) async {
    final cert = _find(certificationId);
    if (cert.status == CertificationStatus.verified && !isOfferManager) {
      throw const RepositoryException(
          'Un certificado verificado no se puede borrar; pide a soporte que lo retire.');
    }
    _certifications.remove(cert);
  }

  @override
  Future<String> getCertificationFileUrl(Certification certification) async {
    _find(certification.id);
    return 'https://example.invalid/mock/${certification.filePath}';
  }
}
