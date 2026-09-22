import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/responsive_layout.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final admin = context.watch<AdminProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
    final numberFormat = NumberFormat.decimalPattern('en_US');

    final stats = admin.stats;

    // Derived top users for UI display
    final exportadores = admin.users.where((u) => u.role.name == 'exportador').take(5).toList();
    final importadores = admin.users.where((u) => u.role.name == 'importador').take(5).toList();

    return ResponsiveContainer(
      maxWidth: 1000,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Informes y Métricas Globales',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Desempeño acumulado del mercado B2B y volumen transaccional.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'Transacciones\nCompletadas',
                    '${stats?.activeNegotiations ?? 0}',
                    Icons.check_circle_outline_rounded,
                    colors.statusActive,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'Volumen Total\n(MT)',
                    '${numberFormat.format(stats?.totalVolumeMt ?? 0)} MT',
                    Icons.scale_rounded,
                    const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              context,
              'Valor Total Negociado (USD)',
              currencyFormat.format(stats?.totalValueUsd ?? 0),
              Icons.attach_money_rounded,
              colors.gold,
              isFullWidth: true,
            ),
            const SizedBox(height: 28),

            // Top Exporters Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.flight_takeoff_rounded, color: colors.gold, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Top Exportadores',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildUserTable(context, exportadores, isExporter: true),
            const SizedBox(height: 28),

            // Top Importers Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flight_land_rounded, color: Color(0xFF3B82F6), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Top Importadores',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildUserTable(context, importadores, isExporter: false),
            const SizedBox(height: 32),

            // Export Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Reporte generado exitosamente'),
                      backgroundColor: colors.surfaceAlt,
                    ),
                  );
                },
                icon: Icon(Icons.download_rounded, color: colors.isDark ? Colors.black : Colors.white, size: 20),
                label: Text(
                  'Exportar Reporte',
                  style: TextStyle(
                    color: colors.isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color accentColor, {
    bool isFullWidth = false,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              if (isFullWidth)
                Text(
                  title,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          if (!isFullWidth) const SizedBox(height: 12),
          if (!isFullWidth)
            Text(
              title,
              style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3),
            ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: isFullWidth ? 24 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTable(BuildContext context, List<dynamic> users, {required bool isExporter}) {
    final colors = context.colors;

    if (users.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Center(
          child: Text(
            'No hay datos disponibles en este periodo.',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final medals = ['🥇', '🥈', '🥉', '4°', '5°'];

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (context, index) => Divider(color: colors.border, height: 1),
        itemBuilder: (context, index) {
          final user = users[index];
          final rankLabel = medals[index];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index < 3 ? colors.gold.withValues(alpha: 0.15) : colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                rankLabel,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(
              user.name,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              user.companyName,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                user.country,
                style: TextStyle(
                  color: colors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
