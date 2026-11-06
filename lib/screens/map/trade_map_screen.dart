import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/services/consumption_point_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/repository_exception.dart';
import '../../models/coffee_consumption_point.dart';

/// Seguimiento del estado de la operación con mapa interactivo Colombia-UE.
/// Visualiza la ruta logística real entre los puertos de origen y destino.
class TradeMapScreen extends StatefulWidget {
  const TradeMapScreen({super.key});

  @override
  State<TradeMapScreen> createState() => _TradeMapScreenState();
}

class _TradeMapScreenState extends State<TradeMapScreen> {
  // Estado logístico simulado de la operación seleccionada
  final int _currentStep =
      2; // 0: Preparación, 1: Puerto Origen, 2: En Tránsito, 3: Aduana UE, 4: Entregado

  // Coordenadas geográficas reales de los puertos
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
        _consumptionPointsError = error is RepositoryException
            ? error.message
            : error.toString();
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
    // Coordenadas intermedias para trazar la curva marítima en el Atlántico
    final routePoints = [
      _buenaventura,
      const LatLng(12.0, -68.0), // Mar Caribe
      const LatLng(25.0, -45.0), // Atlántico Norte
      const LatLng(45.0, -15.0), // Aproximación a Europa
      _hamburgo,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta de Exportación Colombia — UE'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera informativa del lote en seguimiento
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.surfaceAlt,
                      child: Icon(Icons.directions_boat, color: AppColors.gold),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lote #EXP-2026-089',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Café Washed Arabica · 22 MT',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(
                        'EN TRÁNSITO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      backgroundColor: AppColors.gold,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Visualización del mapa real con OpenStreetMap
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: const MapOptions(
                          // Centrado sobre el Océano Atlántico para visibilidad de ambos continentes
                          initialCenter: LatLng(28.0, -35.0),
                          initialZoom: 2.2,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.agrotrade.direct',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                color: AppColors.gold,
                                strokeWidth: 3.5,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _buenaventura,
                                width: 80,
                                height: 60,
                                child: const _MapMarkerWidget(
                                  label: 'Buenaventura',
                                  color: AppColors.gold,
                                  icon: Icons.location_on,
                                ),
                              ),
                              Marker(
                                point: _hamburgo,
                                width: 80,
                                height: 60,
                                child: const _MapMarkerWidget(
                                  label: 'Hamburgo',
                                  color: AppColors.statusActive,
                                  icon: Icons.flag,
                                ),
                              ),
                              if (_showConsumptionPoints)
                                ..._consumptionPoints.map(
                                  (point) => Marker(
                                    point: LatLng(
                                      point.latitude,
                                      point.longitude,
                                    ),
                                    width: 110,
                                    height: 72,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showConsumptionPointDetails(point),
                                      child: _MapMarkerWidget(
                                        label: point.cityName,
                                        color: AppColors.statusTransit,
                                        icon: Icons.local_cafe,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: _showConsumptionPoints
                              ? AppColors.gold
                              : AppColors.surface,
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
                                  const Icon(
                                    Icons.layers,
                                    size: 18,
                                    color: AppColors.textPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Consumo',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_isLoadingConsumptionPoints) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
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
                          (_consumptionPointsError != null ||
                              _consumptionPoints.isEmpty))
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Material(
                            color: AppColors.surface,
                            elevation: 3,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _consumptionPointsError ??
                                    'No hay puntos de consumo disponibles.',
                                style: TextStyle(
                                  color: _consumptionPointsError == null
                                      ? AppColors.textSecondary
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
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Línea de Tiempo Operativa',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),

              // Etapas del avance logístico
              _TimelineStep(
                title: '1. Verificación e Inspección en Origen',
                subtitle:
                    'Finca Primavera (Huila) · Certificación de Calidad aprobada',
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
                subtitle:
                    'Puerto de Hamburgo (DE) · Revisión de No-Deforestación',
                date: 'Pendiente',
                isCompleted: _currentStep >= 3,
                isCurrent: _currentStep == 3,
              ),
              _TimelineStep(
                title: '5. Entrega Confirmada a Importador',
                subtitle: 'Almacén Central Hamburgo',
                date: 'Pendiente',
                isCompleted: _currentStep >= 4,
                isCurrent: _currentStep == 4,
                isLast: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsumptionPointDetailsSheet extends StatelessWidget {
  const _ConsumptionPointDetailsSheet({required this.point});

  final CoffeeConsumptionPoint point;

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${point.cityName}, ${point.country}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _ConsumptionDetail(
              label: 'Consumo anual',
              value: '${point.annualConsumptionTons} toneladas',
            ),
            const SizedBox(height: 10),
            _ConsumptionDetail(
              label: 'Grado de importación principal',
              value: point.mainImportGrade,
            ),
            if (point.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ConsumptionDetail(
                label: 'Descripción',
                value: point.description,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsumptionDetail extends StatelessWidget {
  const _ConsumptionDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? 'No especificado' : value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Widget personalizado para renderizar pines legibles sobre el mapa
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Icon(icon, color: color, size: 24),
      ],
    );
  }
}

/// Widget para renderizar cada hito de la línea de tiempo logitudinal
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
    final color = isCurrent
        ? AppColors.gold
        : isCompleted
            ? AppColors.statusActive
            : AppColors.textMuted;

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
                height: 40,
                color: isCompleted ? AppColors.statusActive : AppColors.border,
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
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isCurrent ? AppColors.gold : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
