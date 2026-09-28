import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/admin_permission.dart';
import '../../providers/admin_provider.dart';
import 'admin_negotiations_screen.dart';
import 'admin_offers_screen.dart';
import 'admin_reports_screen.dart';

/// Pantalla contenedora de Operaciones de Mercado:
/// Ofertas, Negociaciones y Reportes organizados en pestañas superiores.
class AdminOperationsScreen extends StatelessWidget {
  const AdminOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.watch<AdminProvider>();

    final tabs = <Widget>[];
    final views = <Widget>[];

    if (provider.isSuperAdmin || provider.hasPermission(AdminPermission.offerManagement)) {
      tabs.add(
        const Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_rounded, size: 16),
              SizedBox(width: 8),
              Text('Ofertas'),
            ],
          ),
        ),
      );
      views.add(const AdminOffersScreen());
    }

    if (provider.isSuperAdmin || provider.hasPermission(AdminPermission.negotiationManagement)) {
      tabs.add(
        const Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.handshake_rounded, size: 16),
              SizedBox(width: 8),
              Text('Negociaciones'),
            ],
          ),
        ),
      );
      views.add(const AdminNegotiationsScreen());
    }

    if (provider.isSuperAdmin || provider.hasPermission(AdminPermission.reports)) {
      tabs.add(
        const Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, size: 16),
              SizedBox(width: 8),
              Text('Reportes'),
            ],
          ),
        ),
      );
      views.add(const AdminReportsScreen());
    }

    if (tabs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Acceso Restringido',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'No tienes permisos asignados para ver operaciones de mercado.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.gold.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: colors.gold,
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: tabs,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(children: views),
          ),
        ],
      ),
    );
  }
}
