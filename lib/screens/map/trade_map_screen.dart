import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/consumption_point_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/repository_exception.dart';
import '../../models/coffee_consumption_point.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/role_toggle.dart';
import '../../widgets/language_toggle_button.dart';
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
  final int _currentStep =
      2; // 0: Inspección, 1: Despacho, 2: En Tránsito, 3: Aduana UE, 4: Entrega

  final LatLng _buenaventura = const LatLng(3.8801, -77.0312);
  final LatLng _hamburgo = const LatLng(53.5511, 9.9937);
  bool _showConsumptionPoints = false;
  bool _isLoadingConsumptionPoints = false;
  String? _consumptionPointsError;
  List<CoffeeConsumptionPoint> _consumptionPoints = const [];

  Future<void> _toggleConsumptionLayer() async {
    if (_showConsumptionPoints) {
      setState(() => _showConsumptionPoints = false);
      return;
    }

    setState(() {
      _showConsumptionPoints = true;
      _consumptionPointsError = null;
    });

    if (_consumptionPoints.isNotEmpty || _isLoadingConsumptionPoints) return;

    setState(() => _isLoadingConsumptionPoints = true);
    try {
      final points = await context
          .read<ConsumptionPointRepository>()
          .fetchConsumptionPoints();
      if (!mounted) return;
      setState(() => _consumptionPoints = points);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _consumptionPointsError =
            error is RepositoryException ? error.message : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingConsumptionPoints = false);
      }
    }
  }

  void _showConsumptionPointDetails(CoffeeConsumptionPoint point) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConsumptionPointDetailsSheet(point: point),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final loc = context.l10n;
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
              child: Icon(Icons.directions_boat_rounded,
                  color: colors.gold, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.translate('map_title'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  loc.translate('map_subtitle'),
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: const [
          LanguageToggleButton(compact: true),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.statusActive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: colors.statusActive.withValues(alpha: 0.4)),
                ),
                child: Text(
                  context.l10n.translate('shipment_in_transit'),
                  style: TextStyle(
                    color: colors.statusActive,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                context.l10n.translate('shipment_eta'),
                style: TextStyle(
                    color: colors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.translate('shipment_title'),
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
                ? context.l10n.translate('shipment_exporter')
                : context.l10n.translate('shipment_importer'),
            style: TextStyle(
                color: colors.textSecondary, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoItem(
                context.l10n.translate('origin_port'),
                'Buenaventura (CO)',
                Icons.anchor_rounded,
                colors,
              ),
              _infoItem(
                context.l10n.translate('destination_port'),
                'Hamburgo (DE)',
                Icons.flag_rounded,
                colors,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(
      String label, String value, IconData icon, AppThemeColors colors) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.gold),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
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
                  if (_showConsumptionPoints)
                    ..._consumptionPoints.map(
                      (point) => Marker(
                        point: LatLng(point.latitude, point.longitude),
                        width: 110,
                        height: 72,
                        child: GestureDetector(
                          onTap: () => _showConsumptionPointDetails(point),
                          child: _MapMarkerWidget(
                            label: point.cityName,
                            color: colors.statusTransit,
                            icon: Icons.local_cafe_rounded,
                          ),
                        ),
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
                  Icon(Icons.satellite_alt_rounded,
                      size: 14, color: colors.gold),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.translate('atlantic_corridor'),
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
          Positioned(
            top: 14,
            right: 14,
            child: Material(
              color: _showConsumptionPoints ? colors.gold : colors.surface,
              elevation: 3,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _isLoadingConsumptionPoints
                    ? null
                    : _toggleConsumptionLayer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers_rounded,
                        size: 18,
                        color: colors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.translate('consumption_layer'),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_isLoadingConsumptionPoints) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.gold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showConsumptionPoints &&
              !_isLoadingConsumptionPoints &&
              (_consumptionPointsError != null || _consumptionPoints.isEmpty))
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Material(
                color: colors.surface,
                elevation: 3,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _consumptionPointsError ??
                        context.l10n.translate('consumption_empty'),
                    style: TextStyle(
                      color: _consumptionPointsError == null
                          ? colors.textSecondary
                          : Colors.red,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
                context.l10n.translate('timeline_title'),
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
            title: context.l10n.translate('timeline_step_1'),
            subtitle: context.l10n.translate('timeline_step_1_subtitle'),
            date: '10 Sep 2026',
            isCompleted: _currentStep >= 0,
            isCurrent: _currentStep == 0,
          ),
          _TimelineStep(
            title: context.l10n.translate('timeline_step_2'),
            subtitle: context.l10n.translate('timeline_step_2_subtitle'),
            date: '14 Sep 2026',
            isCompleted: _currentStep >= 1,
            isCurrent: _currentStep == 1,
          ),
          _TimelineStep(
            title: context.l10n.translate('timeline_step_3'),
            subtitle: context.l10n.translate('timeline_step_3_subtitle'),
            date: context.l10n.translate('in_progress'),
            isCompleted: _currentStep >= 2,
            isCurrent: _currentStep == 2,
          ),
          _TimelineStep(
            title: context.l10n.translate('timeline_step_4'),
            subtitle: context.l10n.translate('timeline_step_4_subtitle'),
            date: context.l10n.translate('pending'),
            isCompleted: _currentStep >= 3,
            isCurrent: _currentStep == 3,
          ),
          _TimelineStep(
            title: context.l10n.translate('timeline_step_5'),
            subtitle: context.l10n.translate('timeline_step_5_subtitle'),
            date: context.l10n.translate('pending'),
            isCompleted: _currentStep >= 4,
            isCurrent: _currentStep == 4,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ConsumptionPointDetailsSheet extends StatelessWidget {
  const _ConsumptionPointDetailsSheet({required this.point});

  final CoffeeConsumptionPoint point;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${point.cityName}, ${point.country}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _ConsumptionDetail(
              label: context.l10n.translate('annual_consumption'),
              value:
                  '${point.annualConsumptionTons} ${context.l10n.translate('tons')}',
              colors: colors,
            ),
            const SizedBox(height: 10),
            _ConsumptionDetail(
              label: context.l10n.translate('main_import_grade'),
              value: point.mainImportGrade,
              colors: colors,
            ),
            if (point.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ConsumptionDetail(
                label: context.l10n.translate('description'),
                value: point.description,
                colors: colors,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsumptionDetail extends StatelessWidget {
  const _ConsumptionDetail({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? context.l10n.translate('not_specified') : value,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
        ),
      ],
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
