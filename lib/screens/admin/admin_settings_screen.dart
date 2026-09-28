import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/responsive_layout.dart';
import 'admin_employees_screen.dart';

/// REQ Admin: Pantalla de Ajustes.
/// Incluye pestañas para Gestión de Empleados (creación con clave aleatoria y permisos)
/// y Configuración de parámetros de la plataforma (precios de referencia y comisiones).
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late TextEditingController _arabicaController;
  late TextEditingController _cacaoController;
  late TextEditingController _usdEurController;
  late TextEditingController _commissionController;

  @override
  void initState() {
    super.initState();
    final config = context.read<AdminProvider>().config;
    _arabicaController = TextEditingController(text: config.arabicaRefPrice.toString());
    _cacaoController = TextEditingController(text: config.cacaoRefPrice.toString());
    _usdEurController = TextEditingController(text: config.usdEurRate.toString());
    _commissionController = TextEditingController(text: config.commissionPercent.toString());
  }

  @override
  void dispose() {
    _arabicaController.dispose();
    _cacaoController.dispose();
    _usdEurController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final admin = context.read<AdminProvider>();
    final newConfig = admin.config.copyWith(
      arabicaRefPrice: double.tryParse(_arabicaController.text) ?? admin.config.arabicaRefPrice,
      cacaoRefPrice: double.tryParse(_cacaoController.text) ?? admin.config.cacaoRefPrice,
      usdEurRate: double.tryParse(_usdEurController.text) ?? admin.config.usdEurRate,
      commissionPercent: double.tryParse(_commissionController.text) ?? admin.config.commissionPercent,
    );

    admin.updateConfig(newConfig).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Configuración guardada exitosamente'),
            backgroundColor: context.colors.surfaceAlt,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DefaultTabController(
      length: 2,
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
                constraints: const BoxConstraints(maxWidth: 500),
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
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Empleados'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tune_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Plataforma'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const AdminEmployeesScreen(),
                _buildPlatformSettings(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformSettings(AppThemeColors colors) {
    return ResponsiveContainer(
      maxWidth: 800,
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Reference prices
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.03),
                    blurRadius: 10,
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
                          color: colors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.analytics_outlined, color: colors.gold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Precios de Referencia del Mercado',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cotizaciones internacionales oficiales (ICE & LME)',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSettingField(
                    label: 'Arabica ICE (USD/MT)',
                    controller: _arabicaController,
                    icon: Icons.coffee_rounded,
                    prefixText: '\$ ',
                    colors: colors,
                  ),
                  const SizedBox(height: 14),
                  _buildSettingField(
                    label: 'Cacao LME (USD/MT)',
                    controller: _cacaoController,
                    icon: Icons.cookie_outlined,
                    prefixText: '\$ ',
                    colors: colors,
                  ),
                  const SizedBox(height: 14),
                  _buildSettingField(
                    label: 'Tasa USD/EUR',
                    controller: _usdEurController,
                    icon: Icons.currency_exchange_rounded,
                    prefixText: '€ ',
                    colors: colors,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Platform fees
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.03),
                    blurRadius: 10,
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
                          color: colors.statusActive.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.percent_rounded, color: colors.statusActive, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comisión de la Plataforma',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tarifa aplicada sobre transacciones internacionales exitosas',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSettingField(
                    label: 'Comisión por transacción',
                    controller: _commissionController,
                    icon: Icons.account_balance_wallet_outlined,
                    suffixText: ' %',
                    colors: colors,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _saveChanges,
                icon: Icon(Icons.save_rounded, color: colors.isDark ? Colors.black : Colors.white, size: 20),
                label: Text(
                  'Guardar Cambios',
                  style: TextStyle(
                    color: colors.isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required AppThemeColors colors,
    String? prefixText,
    String? suffixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colors.textMuted, size: 20),
        prefixText: prefixText,
        prefixStyle: TextStyle(color: colors.gold, fontWeight: FontWeight.w700, fontSize: 15),
        suffixText: suffixText,
        suffixStyle: TextStyle(color: colors.gold, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}
