/// Métricas agregadas del panel admin (REQ-47 / REQ-37), de
/// `rpc('admin_dashboard_stats')`.
///
/// Solo agregados: ningún dato de una negociación individual. Los montos
/// (volumen, valor, precio promedio) y los promedios de desempeño llegan como
/// `null` cuando el grupo tiene menos de [minGroupSize] tratos confirmados,
/// para no revelar el precio de un trato concreto: la UI debe mostrar
/// "Datos insuficientes" en ese caso.
class PlatformStats {
  const PlatformStats({
    required this.minGroupSize,
    required this.totalUsers,
    required this.activeOffers,
    required this.activeNegotiations,
    required this.blockedUsers,
    required this.pendingAlerts,
    required this.pendingReports,
    required this.pendingCertifications,
    required this.usersByRole,
    required this.offersByStatus,
    required this.negotiationsByStatus,
    required this.confirmedByCrop,
    required this.confirmedByMonth,
    this.totalVolumeMt,
    this.totalValueUsd,
    this.closeRate,
    this.avgRoundsToClose,
    this.avgHoursToConfirm,
  });

  /// Tratos mínimos para mostrar montos de un grupo (3).
  final int minGroupSize;
  final int totalUsers;
  final int activeOffers;
  final int activeNegotiations;
  final int blockedUsers;
  final int pendingAlerts;
  final int pendingReports;
  final int pendingCertifications;

  /// `exportador` / `importador` → cantidad.
  final Map<String, int> usersByRole;

  /// `activa`, `negociando`, `confirmada`, `enTransito`, `cerrada` → cantidad.
  final Map<String, int> offersByStatus;

  /// `pending`, `countered`, `accepted`, `confirmed`, `rejected`, `cancelled` → cantidad.
  final Map<String, int> negotiationsByStatus;
  final List<CropStats> confirmedByCrop;

  /// Tratos confirmados de los últimos 6 meses, del más antiguo al actual.
  final List<MonthlyDeals> confirmedByMonth;

  final double? totalVolumeMt;
  final double? totalValueUsd;

  /// Confirmadas / cerradas (0 a 1); `null` si aún no hay negociaciones cerradas.
  final double? closeRate;
  final double? avgRoundsToClose;
  final double? avgHoursToConfirm;

  static double? _num(Object? v) => (v as num?)?.toDouble();
  static Map<String, int> _counts(Object? v) =>
      (v as Map<String, dynamic>? ?? const {}).map((k, n) => MapEntry(k, (n as num).toInt()));

  factory PlatformStats.fromJson(Map<String, dynamic> json) {
    return PlatformStats(
      minGroupSize: (json['minGroupSize'] as num?)?.toInt() ?? 3,
      totalUsers: (json['totalUsers'] as num).toInt(),
      activeOffers: (json['activeOffers'] as num).toInt(),
      activeNegotiations: (json['activeNegotiations'] as num).toInt(),
      blockedUsers: (json['blockedUsers'] as num).toInt(),
      pendingAlerts: (json['pendingAlerts'] as num).toInt(),
      pendingReports: (json['pendingReports'] as num?)?.toInt() ?? 0,
      pendingCertifications: (json['pendingCertifications'] as num?)?.toInt() ?? 0,
      usersByRole: _counts(json['usersByRole']),
      offersByStatus: _counts(json['offersByStatus']),
      negotiationsByStatus: _counts(json['negotiationsByStatus']),
      confirmedByCrop: (json['confirmedByCrop'] as List<dynamic>? ?? const [])
          .map((c) => CropStats.fromJson(c as Map<String, dynamic>))
          .toList(),
      confirmedByMonth: (json['confirmedByMonth'] as List<dynamic>? ?? const [])
          .map((m) => MonthlyDeals.fromJson(m as Map<String, dynamic>))
          .toList(),
      totalVolumeMt: _num(json['totalVolumeMt']),
      totalValueUsd: _num(json['totalValueUsd']),
      closeRate: _num(json['closeRate']),
      avgRoundsToClose: _num(json['avgRoundsToClose']),
      avgHoursToConfirm: _num(json['avgHoursToConfirm']),
    );
  }
}

/// Tratos confirmados de un producto; los montos son `null` si [deals] es
/// menor que el mínimo del grupo.
class CropStats {
  const CropStats({
    required this.cropType,
    required this.deals,
    this.volumeMt,
    this.valueUsd,
    this.avgPricePerMt,
  });

  final String cropType; // 'cafe' | 'cacao'
  final int deals;
  final double? volumeMt;
  final double? valueUsd;
  final double? avgPricePerMt;

  /// `false` cuando los montos están ocultos por haber pocos tratos.
  bool get hasAmounts => avgPricePerMt != null;

  factory CropStats.fromJson(Map<String, dynamic> json) {
    return CropStats(
      cropType: json['cropType'] as String,
      deals: (json['deals'] as num).toInt(),
      volumeMt: (json['volumeMt'] as num?)?.toDouble(),
      valueUsd: (json['valueUsd'] as num?)?.toDouble(),
      avgPricePerMt: (json['avgPricePerMt'] as num?)?.toDouble(),
    );
  }
}

class MonthlyDeals {
  const MonthlyDeals({required this.month, required this.deals});

  /// `AAAA-MM`.
  final String month;
  final int deals;

  factory MonthlyDeals.fromJson(Map<String, dynamic> json) =>
      MonthlyDeals(month: json['month'] as String, deals: (json['deals'] as num).toInt());
}
