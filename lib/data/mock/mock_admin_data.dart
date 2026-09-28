import '../../models/admin_employee.dart';
import '../../models/admin_permission.dart';
import '../../models/app_user.dart';
import '../../models/blocked_user.dart';
import '../../models/negotiation.dart';
import '../../models/suspicious_activity.dart';
import '../../models/user_role.dart';

/// Datos mock predefinidos para el panel de administración.

// ─── Credencial maestra para acceder al login de empleados ────────────
const String adminGateEmail = 'valentinaburbano1406@gmail.com';
const String adminGatePassword = 'admin12345';

// ─── Empleados internos predefinidos ──────────────────────────────────
final List<AdminEmployee> mockEmployees = [
  AdminEmployee(
    id: 'emp-001',
    name: 'Valentina Burbano',
    email: 'valentinaburbano1406@gmail.com',
    password: 'admin12345',
    permissions: AdminPermission.values.toList(),
    isSuperAdmin: true,
    isActive: true,
    createdAt: DateTime(2025, 1, 15),
    createdBy: 'Sistema',
  ),
  AdminEmployee(
    id: 'emp-002',
    name: 'Carlos Mendoza',
    email: 'carlos.mendoza@agrotrade.co',
    password: 'Agr0#xK9m2',
    permissions: const [
      AdminPermission.dashboard,
      AdminPermission.userManagement,
      AdminPermission.security,
    ],
    isSuperAdmin: false,
    isActive: true,
    createdAt: DateTime(2025, 3, 10),
    createdBy: 'Valentina Burbano',
  ),
  AdminEmployee(
    id: 'emp-003',
    name: 'Laura Gómez',
    email: 'laura.gomez@agrotrade.co',
    password: 'Plt\$7nR4wQ',
    permissions: const [
      AdminPermission.dashboard,
      AdminPermission.offerManagement,
      AdminPermission.negotiationManagement,
    ],
    isSuperAdmin: false,
    isActive: true,
    createdAt: DateTime(2025, 5, 22),
    createdBy: 'Valentina Burbano',
  ),
];

// ─── Usuarios registrados en la plataforma ────────────────────────────
final List<AppUser> mockRegisteredUsers = [
  const AppUser(
    id: 'usr-001',
    name: 'Juan Pérez',
    email: 'juan.perez@cafeprimavera.co',
    role: UserRole.exportador,
    companyName: 'Café Primavera Export',
    country: 'Colombia',
  ),
  const AppUser(
    id: 'usr-002',
    name: 'María González',
    email: 'maria.gonzalez@cacaosierra.co',
    role: UserRole.exportador,
    companyName: 'Cacao Sierra Coop',
    country: 'Colombia',
  ),
  const AppUser(
    id: 'usr-003',
    name: 'Hans Mueller',
    email: 'hans.mueller@kaffeehaus.de',
    role: UserRole.importador,
    companyName: 'Kaffeehaus Berlin GmbH',
    country: 'Alemania',
  ),
  const AppUser(
    id: 'usr-004',
    name: 'Sophie Dupont',
    email: 'sophie.dupont@chocolatier.fr',
    role: UserRole.importador,
    companyName: 'Chocolatier de Paris',
    country: 'Francia',
  ),
  const AppUser(
    id: 'usr-005',
    name: 'Pedro Rodríguez',
    email: 'pedro.rodriguez@agrosur.co',
    role: UserRole.exportador,
    companyName: 'AgroSur Nariño',
    country: 'Colombia',
  ),
  const AppUser(
    id: 'usr-006',
    name: 'Emma Van der Berg',
    email: 'emma.vanderberg@dutchcocoa.nl',
    role: UserRole.importador,
    companyName: 'Dutch Cocoa Trading',
    country: 'Países Bajos',
  ),
  const AppUser(
    id: 'usr-007',
    name: 'Roberto Sánchez',
    email: 'roberto.sanchez@fincaesperanza.co',
    role: UserRole.exportador,
    companyName: 'Finca La Esperanza',
    country: 'Colombia',
  ),
];

// ─── Usuarios bloqueados ──────────────────────────────────────────────
final List<BlockedUser> mockBlockedUsers = [
  BlockedUser(
    userId: 'usr-blocked-001',
    userName: 'Carlos Estafa',
    userEmail: 'carlos.estafa@fake.com',
    reason:
        'Múltiples intentos de fraude detectados. Publicó ofertas falsas de café '
        'a precios muy por debajo del mercado para atraer pagos anticipados. '
        'Se confirmaron 3 reportes de otros usuarios.',
    blockedAt: DateTime.now().subtract(const Duration(days: 15)),
    blockedBy: 'Valentina Burbano',
  ),
];

// ─── Alertas de actividad sospechosa ──────────────────────────────────
final List<SuspiciousActivity> mockAlerts = [
  SuspiciousActivity(
    id: 'alert-001',
    type: SuspiciousType.precioAnomalo,
    description:
        'El usuario publicó una oferta de Cacao Criollo a \$1,200/MT, '
        'muy por debajo del promedio del mercado (\$6,200/MT). '
        'Posible intento de estafa con precios irrealmente bajos.',
    relatedUserId: 'usr-005',
    relatedUserName: 'Pedro Rodríguez',
    severity: AlertSeverity.alta,
    status: AlertStatus.pendiente,
    detectedAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  SuspiciousActivity(
    id: 'alert-002',
    type: SuspiciousType.multiplesCuentas,
    description:
        'Se detectaron 3 cuentas registradas desde la misma dirección IP '
        'en las últimas 2 horas, con correos similares. Posible creación '
        'masiva de cuentas para manipular el mercado.',
    relatedUserId: 'usr-007',
    relatedUserName: 'Roberto Sánchez',
    severity: AlertSeverity.media,
    status: AlertStatus.pendiente,
    detectedAt: DateTime.now().subtract(const Duration(hours: 8)),
  ),
  SuspiciousActivity(
    id: 'alert-003',
    type: SuspiciousType.intentoFraude,
    description:
        'El usuario solicitó pagos fuera de la plataforma en 4 negociaciones '
        'diferentes. Esto viola los términos de servicio y puede ser un '
        'intento de evadir las garantías de la plataforma.',
    relatedUserId: 'usr-004',
    relatedUserName: 'Sophie Dupont',
    severity: AlertSeverity.critica,
    status: AlertStatus.pendiente,
    detectedAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  SuspiciousActivity(
    id: 'alert-004',
    type: SuspiciousType.patronInusual,
    description:
        'Actividad inusual: 15 contraofertas enviadas en menos de 10 minutos '
        'a diferentes vendedores, todas con el mismo precio propuesto. '
        'Posible uso de bot o script automatizado.',
    relatedUserId: 'usr-003',
    relatedUserName: 'Hans Mueller',
    severity: AlertSeverity.baja,
    status: AlertStatus.revisada,
    detectedAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];

// ─── Negociaciones de ejemplo ─────────────────────────────────────────
final List<Negotiation> mockNegotiations = [
  Negotiation(
    id: 'neg-001',
    offerId: 'off-001',
    offerVariety: 'Washed Arabica — Geisha',
    buyerName: 'Hans Mueller',
    sellerName: 'Café Primavera Export',
    originalPrice: 8400,
    proposedPrice: 7800,
    status: NegotiationStatus.pendiente,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  Negotiation(
    id: 'neg-002',
    offerId: 'off-002',
    offerVariety: 'Fine Flavor — Criollo',
    buyerName: 'Emma Van der Berg',
    sellerName: 'Cacao Sierra Coop',
    originalPrice: 6200,
    proposedPrice: 5900,
    status: NegotiationStatus.aceptada,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Negotiation(
    id: 'neg-003',
    offerId: 'off-003',
    offerVariety: 'Honey Process — Castillo',
    buyerName: 'Sophie Dupont',
    sellerName: 'Finca La Esperanza',
    originalPrice: 7100,
    proposedPrice: 6500,
    status: NegotiationStatus.rechazada,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  Negotiation(
    id: 'neg-004',
    offerId: 'off-004',
    offerVariety: 'Bulk Grade — Trinitario',
    buyerName: 'Hans Mueller',
    sellerName: 'AgroSur Nariño',
    originalPrice: 5800,
    proposedPrice: 5500,
    status: NegotiationStatus.completada,
    createdAt: DateTime.now().subtract(const Duration(days: 7)),
  ),
  Negotiation(
    id: 'neg-005',
    offerId: 'off-005',
    offerVariety: 'Natural Process — Bourbon',
    buyerName: 'Emma Van der Berg',
    sellerName: 'Café Primavera Export',
    originalPrice: 7900,
    proposedPrice: 7400,
    status: NegotiationStatus.pendiente,
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
];

// ─── Estadísticas del dashboard ───────────────────────────────────────
class DashboardStats {
  final int totalUsers;
  final int activeOffers;
  final int activeNegotiations;
  final int blockedUsers;
  final int pendingAlerts;
  final double totalVolumeMt;
  final double totalValueUsd;

  const DashboardStats({
    required this.totalUsers,
    required this.activeOffers,
    required this.activeNegotiations,
    required this.blockedUsers,
    required this.pendingAlerts,
    required this.totalVolumeMt,
    required this.totalValueUsd,
  });
}

// ─── Configuración de plataforma ──────────────────────────────────────
class PlatformConfig {
  final double commissionPercent;
  final double arabicaRefPrice;
  final double cacaoRefPrice;
  final double usdEurRate;

  const PlatformConfig({
    required this.commissionPercent,
    required this.arabicaRefPrice,
    required this.cacaoRefPrice,
    required this.usdEurRate,
  });

  PlatformConfig copyWith({
    double? commissionPercent,
    double? arabicaRefPrice,
    double? cacaoRefPrice,
    double? usdEurRate,
  }) {
    return PlatformConfig(
      commissionPercent: commissionPercent ?? this.commissionPercent,
      arabicaRefPrice: arabicaRefPrice ?? this.arabicaRefPrice,
      cacaoRefPrice: cacaoRefPrice ?? this.cacaoRefPrice,
      usdEurRate: usdEurRate ?? this.usdEurRate,
    );
  }
}

const defaultPlatformConfig = PlatformConfig(
  commissionPercent: 2.5,
  arabicaRefPrice: 4210,
  cacaoRefPrice: 6870,
  usdEurRate: 0.921,
);
