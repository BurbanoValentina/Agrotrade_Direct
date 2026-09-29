/// Estado de la revisión de un certificado (REQ-36).
enum CertificationStatus { pending, verified, rejected }

extension CertificationStatusLabel on CertificationStatus {
  String get label {
    switch (this) {
      case CertificationStatus.pending:
        return 'En revisión';
      case CertificationStatus.verified:
        return 'Verificada';
      case CertificationStatus.rejected:
        return 'Rechazada';
    }
  }
}

/// Certificación de un exportador (UTZ, Rainforest Alliance, Fair Trade...)
/// con su PDF en el bucket privado `certifications` de Supabase Storage.
///
/// Pertenece al exportador, no a una oferta: una vez verificada, sus ofertas
/// que mencionen esa certificación la muestran como verificada
/// (`CropOffer.verifiedCertifications`).
class Certification {
  final String id;
  final String sellerId;
  final String name;
  final String? certificateNumber;
  final DateTime? validUntil;

  /// Ruta del PDF dentro del bucket (`<seller_id>/<archivo>.pdf`).
  final String filePath;
  final CertificationStatus status;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  /// Nombre del exportador (solo viene en la lista de pendientes del admin).
  final String? sellerName;

  const Certification({
    required this.id,
    required this.sellerId,
    required this.name,
    this.certificateNumber,
    this.validUntil,
    required this.filePath,
    required this.status,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    this.sellerName,
  });

  /// Vencida según [validUntil] (el sello deja de mostrarse al vencer).
  bool isExpired([DateTime? now]) {
    if (validUntil == null) return false;
    final today = now ?? DateTime.now();
    return validUntil!.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Verificada y vigente: es la que cuenta como sello en las ofertas.
  bool isActive([DateTime? now]) =>
      status == CertificationStatus.verified && !isExpired(now);

  factory Certification.fromJson(Map<String, dynamic> json) {
    return Certification(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      name: json['name'] as String,
      certificateNumber: json['certificate_number'] as String?,
      validUntil: json['valid_until'] == null
          ? null
          : DateTime.parse(json['valid_until'] as String),
      filePath: json['file_path'] as String,
      status: CertificationStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CertificationStatus.pending,
      ),
      rejectionReason: json['rejection_reason'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      sellerName: json['seller']?['name'] as String?,
    );
  }
}
