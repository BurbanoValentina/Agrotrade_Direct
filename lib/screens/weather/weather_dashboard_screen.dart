import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/weather_repository.dart';
import '../../models/weather.dart';
import '../../widgets/language_toggle_button.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/theme_toggle_button.dart';

class WeatherDashboardScreen extends StatefulWidget {
  const WeatherDashboardScreen({super.key});

  @override
  State<WeatherDashboardScreen> createState() => _WeatherDashboardScreenState();
}

class _WeatherDashboardScreenState extends State<WeatherDashboardScreen> {
  late Future<List<WeatherRegion>> _regionsFuture;
  WeatherRegion? _selectedRegion;

  @override
  void initState() {
    super.initState();
    _regionsFuture = context.read<WeatherRepository>().fetchRegions();
  }

  void _reload() {
    setState(() {
      _regionsFuture = context.read<WeatherRepository>().fetchRegions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final repository = context.read<WeatherRepository>();

    return SafeArea(
      child: ResponsiveContainer(
        maxWidth: 760,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: FutureBuilder<List<WeatherRegion>>(
          future: _regionsFuture,
          builder: (context, regionsSnapshot) {
            if (regionsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (regionsSnapshot.hasError) {
              return _ErrorState(onRetry: _reload);
            }
            final regions = regionsSnapshot.data ?? const <WeatherRegion>[];
            final region = _selectedRegion ?? (regions.isEmpty ? null : regions.first);
            if (region == null) return _ErrorState(onRetry: _reload);
            return _WeatherContent(
              key: ValueKey(region.id),
              repository: repository,
              region: region,
              regions: regions,
              onRegionChanged: (value) => setState(() => _selectedRegion = value),
              colors: colors,
            );
          },
        ),
      ),
    );
  }
}

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({
    super.key,
    required this.repository,
    required this.region,
    required this.regions,
    required this.onRegionChanged,
    required this.colors,
  });

  final WeatherRepository repository;
  final WeatherRegion region;
  final List<WeatherRegion> regions;
  final ValueChanged<WeatherRegion?> onRegionChanged;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherForecast>(
      future: repository.fetchForecast(region.id),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LanguageToggleButton(compact: true),
                ThemeToggleButton(compact: true),
              ],
            ),
            const SizedBox(height: 12),
            Text('Clima productivo',
                style: TextStyle(color: colors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Condiciones para tus operaciones de café y cacao',
                style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            DropdownButtonFormField<WeatherRegion>(
              initialValue: region,
              decoration: InputDecoration(
                labelText: 'Zona productora',
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                for (final item in regions)
                  DropdownMenuItem(value: item, child: Text('${item.name} · ${item.department}')),
              ],
              onChanged: onRegionChanged,
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState == ConnectionState.waiting)
              const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              _ErrorState(onRetry: () {})
            else
              _ForecastCard(forecast: snapshot.data!, colors: colors),
          ],
        );
      },
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast, required this.colors});

  final WeatherForecast forecast;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final day = forecast.days.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.gold.withValues(alpha: .22), colors.surface]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.gold.withValues(alpha: .45)),
          ),
          child: Row(
            children: [
              Icon(_weatherIcon(day), color: colors.gold, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(forecast.region.name, style: TextStyle(color: colors.textSecondary)),
                  Text('${day.maxTempC?.toStringAsFixed(1) ?? '--'} °C',
                      style: TextStyle(color: colors.textPrimary, fontSize: 34, fontWeight: FontWeight.w800)),
                  Text(day.description, style: TextStyle(color: colors.gold, fontWeight: FontWeight.w700)),
                  if (forecast.stale)
                    Text('Mostrando datos locales de respaldo',
                        style: TextStyle(color: colors.textMuted, fontSize: 11)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _Stat(icon: Icons.water_drop_outlined, label: 'Humedad', value: _format(day.relativeHumidity, '%'), colors: colors)),
            const SizedBox(width: 10),
            Expanded(child: _Stat(icon: Icons.umbrella_outlined, label: 'Precipitación', value: _format(day.precipitationMm, ' mm'), colors: colors)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Stat(icon: Icons.air, label: 'Viento', value: _format(day.maxWindKmh, ' km/h'), colors: colors)),
            const SizedBox(width: 10),
            Expanded(child: _Stat(icon: Icons.wb_sunny_outlined, label: 'Índice UV', value: _format(day.uvIndex, ''), colors: colors)),
          ],
        ),
      ],
    );
  }

  static String _format(double? value, String suffix) =>
      value == null ? '--' : '${value.toStringAsFixed(0)}$suffix';

  static IconData _weatherIcon(DailyForecast day) {
    final code = day.weatherCode ?? 0;
    if (day.description.toLowerCase().contains('lluv')) return Icons.grain;
    if (code >= 95) return Icons.thunderstorm_outlined;
    if (code >= 3) return Icons.cloud_outlined;
    return Icons.wb_sunny_outlined;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.colors});

  final IconData icon;
  final String label;
  final String value;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: colors.gold, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_outlined, color: colors.textMuted, size: 48),
        const SizedBox(height: 12),
        Text('No se pudo cargar el clima', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      ]),
    );
  }
}
