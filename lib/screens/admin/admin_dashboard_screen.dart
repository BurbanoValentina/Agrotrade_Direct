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
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
        children: [
          _buildHeaderBanner(context, colors, provider),
          const SizedBox(height: 28),

          _buildKpiTitle(colors),
          const SizedBox(height: 16),
          if (stats == null)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive grid horizontal balanceado
                final width = constraints.maxWidth;
                int crossAxisCount = width > 1300 ? 4 : (width > 950 ? 3 : (width > 600 ? 2 : 1));
                double childAspectRatio = width > 1300 ? 1.45 : (width > 950 ? 1.4 : 1.35);

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _StatCard(
                      title: 'Total Usuarios',
                      value: stats.totalUsers.toString(),
                      subtitle: 'Productores y Compradores',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF3B82F6),
                      lightImagePath: 'assets/imagenes/Total_Usuarios_Modo_Claro.jpg',
                      darkImagePath: 'assets/imagenes/Total_Usuarios_Modo_Oscuro.jpg',
                    ),
                    _StatCard(
                      title: 'Ofertas Activas',
                      value: stats.activeOffers.toString(),
                      subtitle: 'Lotes de Café y Cacao',
                      icon: Icons.storefront_rounded,
                      color: colors.statusActive,
                      lightImagePath: 'assets/imagenes/Ofertas_Activas_Modo_Claro.jpg',
                      darkImagePath: 'assets/imagenes/Ofertas_Activas_Modo_Oscuro.jpg',
                    ),
                    _StatCard(
                      title: 'Negociaciones',
                      value: stats.activeNegotiations.toString(),
                      subtitle: 'Tratos en Mesa Activa',
                      icon: Icons.handshake_rounded,
                      color: colors.statusNegotiating,
                      lightImagePath: 'assets/imagenes/Negociacion_Modo_Claro.jpg',
                      darkImagePath: 'assets/imagenes/Negociacion_Modo_Oscuro.jpg',
                    ),
                    _StatCard(
                      title: 'Bloqueados',
                      value: stats.blockedUsers.toString(),
                      subtitle: 'Cuentas Restringidas',
                      icon: Icons.block_flipped,
                      color: Colors.redAccent,
                      lightImagePath: 'assets/imagenes/Bloqueados_Modo_Claro.jpg',
                      darkImagePath: 'assets/imagenes/Bloqueados_Modo_Oscuro.jpg',
                    ),
                    _StatCard(
                      title: 'Alertas Pendientes',
                      value: stats.pendingAlerts.toString(),
                      subtitle: 'Riesgos por Dictamen',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFF59E0B),
                      lightImagePath: 'assets/imagenes/Alertas_Pendientes_Modo_Claro.jpg',
                      darkImagePath: 'assets/imagenes/Alertas_Pendientes_Modo_Oscuro.jpg',
                    ),
                    _StatCard(
                      title: 'Volumen (MT)',
                      value: '${stats.totalVolumeMt} MT',
                      subtitle: 'Toneladas Certificadas',
                      icon: Icons.scale_rounded,
                      color: const Color(0xFF8B5CF6),
                      lightImagePath: 'assets/imagenes/Volumen_Modo_Claro.jpg',
                      darkImagePath: 'assets/imagenes/Volumen_Modo_Oscuro.jpg',
                    ),
                    _StatCard(
                      title: 'Valor Total (USD)',
                      value: currencyFmt.format(stats.totalValueUsd),
                      subtitle: 'Volumen Monetario en Oferta',
                      icon: Icons.monetization_on_rounded,
                      color: colors.gold,
                      lightImagePath: 'assets/imagenes/Valor_Modo_Claro.png',
                      darkImagePath: 'assets/imagenes/Valor_Modo_Oscuro.png',
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 36),
          _buildAlertsHeader(colors),
          const SizedBox(height: 16),
          _RecentAlertsSection(alerts: provider.alerts),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, dynamic colors, AdminProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.surface,
            colors.surfaceAlt.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.gold.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'SISTEMA OPERATIVO ACTIVO',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '· Auditoría en Tiempo Real',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Centro de Mando y Auditoría Global',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Supervisión estratégica de commodities agrícolas, trazabilidad de café y cacao, y control antifraude',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: provider.refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.gold,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Sincronizar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTitle(dynamic colors) {
    return Row(
      children: [
        Icon(Icons.analytics_rounded, size: 20, color: colors.gold),
        const SizedBox(width: 8),
        Text(
          'Métricas Clave de Rendimiento (KPIs)',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(dynamic stats, NumberFormat currencyFmt, dynamic colors, double availableWidth) {
    int crossAxisCount = availableWidth > 900 ? 3 : (availableWidth > 550 ? 2 : 1);
    double childAspectRatio = availableWidth > 900 ? 1.05 : 1.15;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      children: [
        _StatCard(
          title: 'Total Usuarios',
          value: stats.totalUsers.toString(),
          subtitle: 'Productores y Compradores',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF3B82F6),
          lightImagePath: 'assets/imagenes/Total_Usuarios_Modo_Claro.jpg',
          darkImagePath: 'assets/imagenes/Total_Usuarios_Modo_Oscuro.jpg',
        ),
        _StatCard(
          title: 'Ofertas Activas',
          value: stats.activeOffers.toString(),
          subtitle: 'Lotes de Café y Cacao',
          icon: Icons.storefront_rounded,
          color: colors.statusActive,
          lightImagePath: 'assets/imagenes/Ofertas_Activas_Modo_Claro.jpg',
          darkImagePath: 'assets/imagenes/Ofertas_Activas_Modo_Oscuro.jpg',
        ),
        _StatCard(
          title: 'Negociaciones',
          value: stats.activeNegotiations.toString(),
          subtitle: 'Tratos en Mesa Activa',
          icon: Icons.handshake_rounded,
          color: colors.statusNegotiating,
          lightImagePath: 'assets/imagenes/Negociacion_Modo_Claro.jpg',
          darkImagePath: 'assets/imagenes/Negociacion_Modo_Oscuro.jpg',
        ),
        _StatCard(
          title: 'Bloqueados',
          value: stats.blockedUsers.toString(),
          subtitle: 'Cuentas Restringidas',
          icon: Icons.block_flipped,
          color: Colors.redAccent,
          lightImagePath: 'assets/imagenes/Bloqueados_Modo_Claro.jpg',
          darkImagePath: 'assets/imagenes/Bloqueados_Modo_Oscuro.jpg',
        ),
        _StatCard(
          title: 'Alertas Pendientes',
          value: stats.pendingAlerts.toString(),
          subtitle: 'Riesgos por Dictamen',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFF59E0B),
          lightImagePath: 'assets/imagenes/Alertas_Pendientes_Modo_Claro.jpg',
          darkImagePath: 'assets/imagenes/Alertas_Pendientes_Modo_Oscuro.jpg',
        ),
        _StatCard(
          title: 'Volumen (MT)',
          value: '${stats.totalVolumeMt} MT',
          subtitle: 'Toneladas Certificadas',
          icon: Icons.scale_rounded,
          color: const Color(0xFF8B5CF6),
          lightImagePath: 'assets/imagenes/Volumen_Modo_Claro.jpg',
          darkImagePath: 'assets/imagenes/Volumen_Modo_Oscuro.jpg',
        ),
        _StatCard(
          title: 'Valor Total (USD)',
          value: currencyFmt.format(stats.totalValueUsd),
          subtitle: 'Volumen Monetario en Oferta',
          icon: Icons.monetization_on_rounded,
          color: colors.gold,
          lightImagePath: 'assets/imagenes/Valor_Modo_Claro.png',
          darkImagePath: 'assets/imagenes/Valor_Modo_Oscuro.png',
        ),
      ],
    );
  }

  Widget _buildAlertsHeader(dynamic colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_rounded, size: 20, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Text(
              'Incidentes y Alertas en Vivo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            'Revisión Alta',
            style: TextStyle(
              color: colors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? lightImagePath;
  final String? darkImagePath;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.lightImagePath,
    this.darkImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imagePath = colors.isDark ? (darkImagePath ?? lightImagePath) : (lightImagePath ?? darkImagePath);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: color.withValues(alpha: colors.isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: colors.isDark ? 0.25 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de ilustración de fondo perfectamente centrada
          if (imagePath != null)
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),

          // Capa de degradado con iluminación perimetral para máxima legibilidad
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: imagePath != null
                    ? [
                        (colors.isDark ? Colors.black : Colors.white).withValues(alpha: 0.35),
                        (colors.isDark ? const Color(0xFF141215) : Colors.white).withValues(alpha: 0.88),
                        (colors.isDark ? const Color(0xFF0F0D10) : Colors.white).withValues(alpha: 0.98),
                      ]
                    : [
                        colors.surface,
                        colors.surface,
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Contenido principal de la tarjeta
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fila superior: Chip con icono temático y glow de pulso
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (colors.isDark ? Colors.black : Colors.white).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: color, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            title,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Parte inferior: Métrica destacada en tipografía de alto impacto
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          shadows: [
                            Shadow(
                              color: colors.isDark ? Colors.black : Colors.white,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
          borderRadius: BorderRadius.circular(18),
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
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Todas las transacciones y usuarios están operando con normalidad',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
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
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: severityColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: severityColor.withValues(alpha: 0.4)),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: severityColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    alert.severity.label,
                    style: TextStyle(
                      color: severityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: colors.gold),
                      const SizedBox(width: 4),
                      Text(
                        alert.relatedUserName,
                        style: TextStyle(
                          color: colors.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    alert.description,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
