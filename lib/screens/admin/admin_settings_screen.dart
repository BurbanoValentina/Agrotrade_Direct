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
    final admin = context.watch<AdminProvider>();

    if (admin.isManager) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              border: Border(bottom: BorderSide(color: Colors.purple.withValues(alpha: 0.2))),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.purpleAccent, size: 16),
                SizedBox(width: 8),
                Text(
                  'Modo Consulta (Gerente) - Parámetros de solo lectura. Gestión de empleados restringida a Super Admin.',
                  style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(child: _buildPlatformSettings(colors, isReadOnly: true)),
        ],
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Banner de Gobernanza y Configuración
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: colors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.gold.withValues(alpha: 0.35)),
                      ),
                      child: Icon(Icons.settings_suggest_rounded, color: colors.gold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajustes del Sistema & Equipo Operativo',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Credenciales corporativas autogeneradas y parámetros económicos globales',
                          style: TextStyle(color: colors.textSecondary, fontSize: 11),
                        ),
                      ],
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_person_rounded, size: 14, color: colors.gold),
                      const SizedBox(width: 6),
                      Text(
                        'Acceso Super Admin',
                        style: TextStyle(
                          color: colors.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.gold.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: colors.gold,
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
                _buildPlatformSettings(colors, isReadOnly: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformSettings(AppThemeColors colors, {bool isReadOnly = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        if (!isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPricesCard(colors, isReadOnly),
                const SizedBox(height: 20),
                _buildCommissionCard(colors, isReadOnly),
                const SizedBox(height: 24),
                if (!isReadOnly) _buildSaveButton(colors),
              ],
            ),
          );
        }

        // Split-Layout Panorámico de pantalla completa en Desktop
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 22.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda (360px): Resumen Económico, Tasas en Vivo y Auditoría
              SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.surface,
                              colors.surfaceAlt,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.gold.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
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
                                  child: Icon(Icons.account_balance_rounded, color: colors.gold, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Gobernanza Monetaria',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Los precios de referencia se sincronizan en vivo con los índices de ICE Coffee y LME Cacao para mitigar fraudes o especulación indebida en el mercado.',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
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
                                const SizedBox(width: 8),
                                Text(
                                  'Auditoría Financiera Activa',
                                  style: TextStyle(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tarjeta de Seguridad y Garantía
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shield_outlined, size: 16, color: colors.gold),
                                const SizedBox(width: 8),
                                Text(
                                  'Normativa y Compliance',
                                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Comisiones transparentes para exportadores colombianos e importadores UE. Sin recargos ocultos.',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!isReadOnly) _buildSaveButton(colors),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 26),

              // Columna Derecha: Tarjetas Principales de Configuración en Grid Espacioso
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPricesCard(colors, isReadOnly),
                      const SizedBox(height: 22),
                      _buildCommissionCard(colors, isReadOnly),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPricesCard(AppThemeColors colors, bool isReadOnly) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.gold.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.trending_up_rounded, color: colors.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Precios de Referencia del Mercado',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cotizaciones oficiales internacionales que rigen el cálculo de comisiones e inspección antifraude',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSettingField(
                  label: 'Arabica ICE (USD/MT)',
                  controller: _arabicaController,
                  icon: Icons.coffee_rounded,
                  prefixText: '\$ ',
                  colors: colors,
                  enabled: !isReadOnly,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSettingField(
                  label: 'Cacao LME (USD/MT)',
                  controller: _cacaoController,
                  icon: Icons.cookie_outlined,
                  prefixText: '\$ ',
                  colors: colors,
                  enabled: !isReadOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSettingField(
            label: 'Tasa Oficial de Conversión USD / EUR',
            controller: _usdEurController,
            icon: Icons.currency_exchange_rounded,
            prefixText: '€ ',
            colors: colors,
            enabled: !isReadOnly,
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionCard(AppThemeColors colors, bool isReadOnly) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.statusActive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.statusActive.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.percent_rounded, color: colors.statusActive, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comisión y Tarifas de la Plataforma',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Porcentaje retenido automáticamente tras el cierre exitoso y validación marítima de cada lote',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingField(
            label: 'Comisión por transacción internacional',
            controller: _commissionController,
            icon: Icons.account_balance_wallet_outlined,
            suffixText: ' %',
            colors: colors,
            enabled: !isReadOnly,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(AppThemeColors colors) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.gold,
          foregroundColor: colors.isDark ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
        onPressed: _saveChanges,
        icon: const Icon(Icons.save_rounded, size: 19),
        label: const Text(
          'Guardar Configuración',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
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
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colors.gold, size: 20),
        prefixText: prefixText,
        prefixStyle: TextStyle(color: colors.gold, fontWeight: FontWeight.w800, fontSize: 15),
        suffixText: suffixText,
        suffixStyle: TextStyle(color: colors.gold, fontWeight: FontWeight.w800, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }
}
