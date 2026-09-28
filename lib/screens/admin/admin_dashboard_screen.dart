import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/suspicious_activity.dart';
import '../../providers/admin_provider.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.watch<AdminProvider>();
    final stats = provider.stats;
    final currencyFmt = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: provider.refreshData,
      color: colors.gold,
      backgroundColor: colors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vista General',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Métricas de mercado y seguridad en vivo',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Actualizar datos',
                onPressed: provider.refreshData,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.refresh_rounded, size: 18, color: colors.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (stats == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 550 ? 3 : 2);
                double childAspectRatio = constraints.maxWidth > 900 ? 1.35 : (constraints.maxWidth > 550 ? 1.25 : 1.15);

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _StatCard(
                      title: 'Total Usuarios',
                      value: stats.totalUsers.toString(),
                      subtitle: 'Registrados activos',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF3B82F6),
                    ),
                    _StatCard(
                      title: 'Ofertas Activas',
                      value: stats.activeOffers.toString(),
                      subtitle: 'Café y cacao en bolsa',
                      icon: Icons.storefront_rounded,
                      color: colors.statusActive,
                    ),
                    _StatCard(
                      title: 'Negociaciones',
                      value: stats.activeNegotiations.toString(),
                      subtitle: 'En mesa de trato',
                      icon: Icons.handshake_rounded,
                      color: colors.statusNegotiating,
                    ),
                    _StatCard(
                      title: 'Bloqueados',
                      value: stats.blockedUsers.toString(),
                      subtitle: 'Cuentas restringidas',
                      icon: Icons.block_flipped,
                      color: Colors.redAccent,
                    ),
                    _StatCard(
                      title: 'Alertas Pendientes',
                      value: stats.pendingAlerts.toString(),
                      subtitle: 'Casos por revisar',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    _StatCard(
                      title: 'Volumen (MT)',
                      value: '${stats.totalVolumeMt} MT',
                      subtitle: 'Toneladas métricas',
                      icon: Icons.scale_rounded,
                      color: const Color(0xFF8B5CF6),
                    ),
                    _StatCard(
                      title: 'Valor (USD)',
                      value: currencyFmt.format(stats.totalValueUsd),
                      subtitle: 'Valor estimado total',
                      icon: Icons.monetization_on_rounded,
                      color: colors.gold,
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alertas Recientes',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'Prioridad de revisión',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RecentAlertsSection(alerts: provider.alerts),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.15 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentAlertsSection extends StatelessWidget {
  final List<SuspiciousActivity> alerts;

  const _RecentAlertsSection({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pendingAlerts = alerts.where((a) => a.status == AlertStatus.pendiente).take(3).toList();

    if (pendingAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 40, color: colors.statusActive),
            const SizedBox(height: 10),
            Text(
              'No hay alertas pendientes',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Todas las operaciones se encuentran verificadas',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: pendingAlerts.map((alert) {
        final (severityColor, severityIcon) = switch (alert.severity) {
          AlertSeverity.critica => (Colors.redAccent, Icons.error_rounded),
          AlertSeverity.alta => (Colors.orangeAccent, Icons.warning_rounded),
          AlertSeverity.media => (colors.gold, Icons.info_rounded),
          AlertSeverity.baja => (Colors.blueAccent, Icons.info_outline_rounded),
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(severityIcon, color: severityColor, size: 22),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    alert.type.label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: severityColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    alert.severity.label,
                    style: TextStyle(
                      color: severityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${alert.relatedUserName} · ${alert.description}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
