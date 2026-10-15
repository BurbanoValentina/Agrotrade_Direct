import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/market_provider.dart';
import 'user_report_dialog.dart';

/// REQ-29: Panel de QA / Testing Specialist (Valentina Burbano).
/// Rediseñado con estética de consola de diagnóstico de lujo:
/// - Cabecera con degradado dorado y badge "MODO TESTING ACTIVO"
/// - Acciones de cambio de rol y perfiles con tarjetas táctiles
/// - Feature Flags con microinteracciones y descripciones claras
/// - Terminal de logs estilo consola con timestamps estilizados
class QaTestingPanelDialog extends StatefulWidget {
  const QaTestingPanelDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const QaTestingPanelDialog(),
    );
  }

  @override
  State<QaTestingPanelDialog> createState() => _QaTestingPanelDialogState();
}

class _QaTestingPanelDialogState extends State<QaTestingPanelDialog> {
  bool _flagCommercialPrivacy = true;
  bool _flagSimulateSlowNetwork = false;
  bool _flagStrictCertifications = true;

  final List<String> _qaLogs = [
    '${DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String().substring(11, 19)} · [QA] Sesión iniciada con éxito.',
    '${DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String().substring(11, 19)} · [QA] Verificando persistencia local ThemeProvider.',
    '${DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String().substring(11, 19)} · [QA] Validación de roles Super Admin vs Gerente (REQ-46).',
    '${DateTime.now().toIso8601String().substring(11, 19)} · [QA] Enmascaramiento de precios activo (REQ-47).',
  ];

  void _addLog(String message) {
    setState(() {
      _qaLogs.insert(
        0,
        '${DateTime.now().toIso8601String().substring(11, 19)} · $message',
      );
    });
  }

  void _regenerateMockData() {
    final market = context.read<MarketProvider>();
    final admin = context.read<AdminProvider>();

    market.loadOffers();
    admin.refreshStats();

    _addLog('[QA] Datos mock regenerados a estado inicial.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Datos mock reiniciados exitosamente.'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: colors.gold.withValues(alpha: 0.35), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con estética de laboratorio de QA
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.gold, colors.goldDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: colors.gold.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.bug_report_rounded,
                      color: colors.isDark ? Colors.black : Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Consola de Testing & QA',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.gold.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.gold.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'Valentina Burbano',
                                style: TextStyle(
                                  color: colors.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Entorno interactivo para validación de requerimientos y auditoría',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: colors.textMuted),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surfaceAlt,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  children: [
                    // Sección 1: Simulación de Sesión y Roles
                    _buildSectionHeader(colors, Icons.switch_account_rounded, 'Simulación de Roles y Permisos'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ROL DE MERCADO ACTUAL',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user?.role == UserRole.exportador
                                        ? '🇨🇴 Exportador Certificado'
                                        : '🇪🇺 Importador Oficial UE',
                                    style: TextStyle(
                                      color: user?.role == UserRole.exportador ? colors.gold : const Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.gold,
                                  foregroundColor: colors.isDark ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                label: const Text('Alternar Rol', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                onPressed: () {
                                  auth.toggleRole();
                                  _addLog('[QA] Conmutación de rol a ${auth.currentUser?.role == UserRole.exportador ? "Exportador" : "Importador"}');
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.purpleAccent,
                                    side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.analytics_outlined, size: 16),
                                  label: const Text('Admin (Gerente)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.of(context).pushNamed('/admin-login');
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.gold,
                                    side: BorderSide(color: colors.gold.withValues(alpha: 0.6)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.workspace_premium_rounded, size: 16),
                                  label: const Text('Admin (Super)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.of(context).pushNamed('/admin-login');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Sección 2: Control de Mock Data
                    _buildSectionHeader(colors, Icons.dataset_rounded, 'Gestión de Datos y Auditoría'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.surfaceAlt,
                              foregroundColor: colors.textPrimary,
                              side: BorderSide(color: colors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.restart_alt_rounded, size: 16),
                            label: const Text('Regenerar Mock Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            onPressed: _regenerateMockData,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.flag_rounded, size: 16),
                            label: const Text('Probar Reporte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            onPressed: () {
                              UserReportDialog.show(
                                context,
                                reportedUserId: 'mock-user-09',
                                reportedUserName: 'Café Andino Export S.A.S.',
                                offerTitle: 'Café Geisha Especial (Tolima)',
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Sección 3: Feature Flags
                    _buildSectionHeader(colors, Icons.tune_rounded, 'Feature Flags de Prueba'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            dense: true,
                            title: const Text('Privacidad Comercial UI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            subtitle: const Text('Enmascara precios individuales en panel admin', style: TextStyle(fontSize: 11)),
                            value: _flagCommercialPrivacy,
                            activeColor: colors.gold,
                            onChanged: (val) {
                              setState(() => _flagCommercialPrivacy = val);
                              _addLog('[Flag] Privacidad Comercial: $val');
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            dense: true,
                            title: const Text('Filtro Estricto de Certificaciones', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            subtitle: const Text('Valida sellos EU Orgánico y Rainforest', style: TextStyle(fontSize: 11)),
                            value: _flagStrictCertifications,
                            activeColor: colors.gold,
                            onChanged: (val) {
                              setState(() => _flagStrictCertifications = val);
                              _addLog('[Flag] Certificaciones estrictas: $val');
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            dense: true,
                            title: const Text('Simular Latencia de Red (Mock Latency)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            subtitle: const Text('Introduce retardo de 800ms en repositorios', style: TextStyle(fontSize: 11)),
                            value: _flagSimulateSlowNetwork,
                            activeColor: colors.gold,
                            onChanged: (val) {
                              setState(() => _flagSimulateSlowNetwork = val);
                              _addLog('[Flag] Latencia de red: $val');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Sección 4: Terminal de Logs
                    _buildSectionHeader(colors, Icons.terminal_rounded, 'Terminal de Auditoría en Tiempo Real'),
                    const SizedBox(height: 8),
                    Container(
                      height: 130,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: colors.isDark ? 0.45 : 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: ListView.builder(
                        itemCount: _qaLogs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '> ',
                                  style: TextStyle(
                                    color: colors.gold,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _qaLogs[index],
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.gold,
                    foregroundColor: colors.isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar Panel QA', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(AppThemeColors colors, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.gold),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
