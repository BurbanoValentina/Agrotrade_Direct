import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/role_toggle.dart';
import '../../widgets/theme_toggle_button.dart';

/// Pantalla "Rutas y Logística Marítima Colombia — UE"
/// - Rediseño con márgenes amplios, Split-Layout profesional y vista diferenciada para Exportador e Importador.
class TradeMapScreen extends StatefulWidget {
  const TradeMapScreen({super.key});

  @override
  State<TradeMapScreen> createState() => _TradeMapScreenState();
}

class _TradeMapScreenState extends State<TradeMapScreen> {
  // Estado logístico simulado
  final int _currentStep = 2; // 0: Inspección, 1: Despacho, 2: En Tránsito, 3: Aduana UE, 4: Entrega

  final LatLng _buenaventura = const LatLng(3.8801, -77.0312);
  final LatLng _hamburgo = const LatLng(53.5511, 9.9937);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = context.watch<AuthProvider>().currentUser;
    final isExporter = user?.role == UserRole.exportador;

    final routePoints = [
      _buenaventura,
      const LatLng(12.0, -68.0), // Mar Caribe
      const LatLng(25.0, -45.0), // Atlántico Norte
      const LatLng(45.0, -15.0), // Aproximación a Europa
      _hamburgo,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.directions_boat_rounded, color: colors.gold, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rutas y Trazabilidad Transatlántica',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Monitoreo geoespacial en tiempo real (Colombia 🇨🇴 ⇄ Unión Europea 🇪🇺)',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: const [
          ThemeToggleButton(compact: true),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 950;

            if (isDesktop) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── PANEL IZQUIERDO: Datos del Lote, Rol y Hitos ──
                    SizedBox(
                      width: 400,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (user != null) RoleToggle(selected: user.role),
                            const SizedBox(height: 16),

                            // Ficha técnica del cargamento marítimo
                            _buildShipmentCard(colors, isExporter),
                            const SizedBox(height: 16),

                            // Hitos y Tiempos de Entrega
                            _buildTimelineCard(colors, isExporter),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // ── PANEL DERECHO: Mapa Satelital Interactivo ──
                    Expanded(
                      child: _buildMapContainer(colors, routePoints),
                    ),
                  ],
                ),
              );
            }

            // ── VISTA MÓVIL ──
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user != null) RoleToggle(selected: user.role),
                  const SizedBox(height: 14),
                  _buildShipmentCard(colors, isExporter),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: _buildMapContainer(colors, routePoints),
                  ),
                  const SizedBox(height: 20),
                  _buildTimelineCard(colors, isExporter),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShipmentCard(AppThemeColors colors, bool isExporter) {
    final themeColor = isExporter ? colors.gold : const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.statusActive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.statusActive.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'EN TRÁNSITO MARÍTIMO',
                  style: TextStyle(
                    color: colors.statusActive,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'ETA: 28 Sep 2026',
                style: TextStyle(color: colors.gold, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Lote #EXP-2026-089 · Café Washed Arabica',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isExporter
                ? 'Exportación despachada desde Buenaventura · Origen Huila · 22 Toneladas Métricas'
                : 'Importación destinada a Hamburgo · Certificación Fair Trade y Rainforest Alliance',
            style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoItem('Puerto Origen', 'Buenaventura (CO)', Icons.anchor_rounded, colors),
              _infoItem('Puerto Destino', 'Hamburgo (DE)', Icons.flag_rounded, colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon, AppThemeColors colors) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.gold),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: colors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
            Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildMapContainer(AppThemeColors colors, List<LatLng> routePoints) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(28.0, -35.0),
              initialZoom: 2.8,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.agrotrade.direct',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: colors.gold,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _buenaventura,
                    width: 100,
                    height: 60,
                    child: const _MapMarkerWidget(
                      label: 'Buenaventura (CO)',
                      color: Color(0xFFF59E0B),
                      icon: Icons.anchor_rounded,
                    ),
                  ),
                  Marker(
                    point: _hamburgo,
                    width: 100,
                    height: 60,
                    child: const _MapMarkerWidget(
                      label: 'Hamburgo (DE)',
                      color: Color(0xFF10B981),
                      icon: Icons.location_city_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.satellite_alt_rounded, size: 14, color: colors.gold),
                  const SizedBox(width: 6),
                  Text(
                    'Corredor Marítimo Atlántico',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(AppThemeColors colors, bool isExporter) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.linear_scale_rounded, size: 18, color: colors.gold),
              const SizedBox(width: 8),
              Text(
                'Línea de Tiempo Operativa y Aduanera',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TimelineStep(
            title: '1. Verificación e Inspección en Origen',
            subtitle: 'Finca Primavera (Huila) · Certificación de Calidad y No-Deforestación aprobada',
            date: '10 Sep 2026',
            isCompleted: _currentStep >= 0,
            isCurrent: _currentStep == 0,
          ),
          _TimelineStep(
            title: '2. Despacho y Carga Marítima',
            subtitle: 'Puerto de Buenaventura (CO) · Contenedor #CB-9941',
            date: '14 Sep 2026',
            isCompleted: _currentStep >= 1,
            isCurrent: _currentStep == 1,
          ),
          _TimelineStep(
            title: '3. En Tránsito Marítimo',
            subtitle: 'Trayecto Atlántico · ETA estimado: 28 Sep 2026',
            date: 'En progreso',
            isCompleted: _currentStep >= 2,
            isCurrent: _currentStep == 2,
          ),
          _TimelineStep(
            title: '4. Inspección de Aduana UE (EUTR)',
            subtitle: 'Puerto de Hamburgo (DE) · Revisión de Fitosanitario y Trazabilidad',
            date: 'Pendiente',
            isCompleted: _currentStep >= 3,
            isCurrent: _currentStep == 3,
          ),
          _TimelineStep(
            title: '5. Entrega Confirmada a Importador',
            subtitle: 'Almacén Central Hamburgo · Traspaso de título de propiedad',
            date: 'Pendiente',
            isCompleted: _currentStep >= 4,
            isCurrent: _currentStep == 4,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _MapMarkerWidget extends StatelessWidget {
  const _MapMarkerWidget({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Icon(icon, color: color, size: 22),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.isCompleted,
    required this.isCurrent,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final String date;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = isCurrent
        ? colors.gold
        : isCompleted
            ? colors.statusActive
            : colors.textMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: isCompleted ? colors.statusActive : colors.border,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isCurrent ? colors.gold : colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }
}
