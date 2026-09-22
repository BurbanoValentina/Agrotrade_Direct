import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_permission.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/theme_toggle_button.dart';
import '../auth/login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_operations_screen.dart';
import 'admin_security_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_users_screen.dart';

class _AdminTabItem {
  final String label;
  final IconData icon;
  final Widget screen;
  final int badgeCount;

  const _AdminTabItem({
    required this.label,
    required this.icon,
    required this.screen,
    this.badgeCount = 0,
  });
}

/// Contenedor principal del Panel de Administración con barra de navegación inferior.
/// Las secciones mostradas en la parte inferior se adaptan dinámicamente según
/// los permisos del empleado autenticado o acceso total para Super Admin.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.watch<AdminProvider>();
    final employee = provider.currentEmployee;

    if (employee == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isSuper = provider.isSuperAdmin;

    // Construir pestañas dinámicas según los permisos asignados
    final tabs = <_AdminTabItem>[];

    // 1. Dashboard
    if (isSuper || provider.hasPermission(AdminPermission.dashboard)) {
      tabs.add(
        const _AdminTabItem(
          label: 'Dashboard',
          icon: Icons.dashboard_rounded,
          screen: AdminDashboardScreen(),
        ),
      );
    }

    // 2. Usuarios
    if (isSuper || provider.hasPermission(AdminPermission.userManagement)) {
      tabs.add(
        const _AdminTabItem(
          label: 'Usuarios',
          icon: Icons.people_alt_rounded,
          screen: AdminUsersScreen(),
        ),
      );
    }

    // 3. Seguridad
    if (isSuper || provider.hasPermission(AdminPermission.security)) {
      tabs.add(
        _AdminTabItem(
          label: 'Seguridad',
          icon: Icons.shield_rounded,
          screen: const AdminSecurityScreen(),
          badgeCount: provider.pendingAlertsCount,
        ),
      );
    }

    // 4. Mercado (Ofertas, Negociaciones, Reportes)
    if (isSuper ||
        provider.hasPermission(AdminPermission.offerManagement) ||
        provider.hasPermission(AdminPermission.negotiationManagement) ||
        provider.hasPermission(AdminPermission.reports)) {
      tabs.add(
        const _AdminTabItem(
          label: 'Mercado',
          icon: Icons.storefront_rounded,
          screen: AdminOperationsScreen(),
        ),
      );
    }

    // 5. Ajustes (Gestión de Empleados con claves autogeneradas + Parámetros)
    if (isSuper ||
        provider.hasPermission(AdminPermission.settings) ||
        provider.hasPermission(AdminPermission.employeeManagement)) {
      tabs.add(
        const _AdminTabItem(
          label: 'Ajustes',
          icon: Icons.settings_rounded,
          screen: AdminSettingsScreen(),
        ),
      );
    }

    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          title: Text('Acceso Restringido', style: TextStyle(color: colors.textPrimary)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () {
                provider.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: Center(
          child: Text(
            'No tienes permisos asignados. Contacta al Administrador.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: employee.isSuperAdmin ? colors.gold : colors.surfaceAlt,
              child: Text(
                employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'A',
                style: TextStyle(
                  color: employee.isSuperAdmin ? (colors.isDark ? Colors.black : Colors.white) : colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          employee.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: employee.isSuperAdmin
                              ? colors.gold.withValues(alpha: 0.16)
                              : colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: employee.isSuperAdmin
                                ? colors.gold.withValues(alpha: 0.4)
                                : colors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              employee.isSuperAdmin
                                  ? Icons.workspace_premium_rounded
                                  : Icons.shield_rounded,
                              size: 11,
                              color: employee.isSuperAdmin ? colors.gold : colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              employee.isSuperAdmin ? 'Super Admin' : 'Empleado',
                              style: TextStyle(
                                color: employee.isSuperAdmin ? colors.gold : colors.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Panel de Control Interno',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(compact: true),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Cerrar Sesión',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
            ),
            onPressed: () {
              provider.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: tabs[_currentIndex].screen,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.6))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: colors.surface,
          selectedItemColor: colors.gold,
          unselectedItemColor: colors.textMuted,
          items: tabs.map((tab) {
            Widget iconWidget = Icon(tab.icon);
            if (tab.badgeCount > 0) {
              iconWidget = Badge(
                backgroundColor: Colors.redAccent,
                label: Text(
                  tab.badgeCount.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
                child: iconWidget,
              );
            }
            return BottomNavigationBarItem(
              icon: iconWidget,
              label: tab.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}
