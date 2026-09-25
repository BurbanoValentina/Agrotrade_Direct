import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/theme_toggle_button.dart';
import '../market/market_screen.dart';

/// Contenedor con la barra de navegación inferior de las 4 secciones:
/// Market, My Deals, Trade Map, Profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final screens = [
      const MarketScreen(),
      const _PlaceholderScreen(
        icon: Icons.assignment_outlined,
        title: 'Mis Negociaciones',
        subtitle: 'Seguimiento de ofertas y contraofertas activas',
        description:
            'Aquí podrás gestionar todas tus propuestas comerciales, contraofertas en tiempo real y el historial de acuerdos cerrados.',
      ),
      const _PlaceholderScreen(
        icon: Icons.map_outlined,
        title: 'Ruta Comercial (Trade Map)',
        subtitle: 'Trazabilidad y logística Colombia → Unión Europea',
        description:
            'Visualiza en tiempo real el transporte marítimo y aduanero de tus cargamentos de café y cacao desde puertos colombianos a Europa.',
      ),
      _ProfileScreen(user: user),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: colors.surface,
          selectedItemColor: colors.gold,
          unselectedItemColor: colors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Mercado',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.handshake_outlined),
              activeIcon: Icon(Icons.handshake_rounded),
              label: 'Mis Tratos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.navigation_outlined),
              activeIcon: Icon(Icons.navigation_rounded),
              label: 'Rutas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen({required this.user});

  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isExporter = user?.role == UserRole.exportador;

    return SafeArea(
      child: ResponsiveContainer(
        maxWidth: 600,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Top action
            const Align(
              alignment: Alignment.topRight,
              child: ThemeToggleButton(compact: true),
            ),
            const SizedBox(height: 12),

            // Profile Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: colors.gold.withValues(alpha: 0.15),
                    child: Text(
                      user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: colors.gold,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Usuario AgroTrade',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isExporter
                          ? colors.gold.withValues(alpha: 0.12)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isExporter
                            ? colors.gold.withValues(alpha: 0.4)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isExporter ? 'Exportador Certificado 🇨🇴' : 'Importador Oficial UE 🇪🇺',
                      style: TextStyle(
                        color: isExporter ? colors.gold : const Color(0xFF3B82F6),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (user?.companyName != null && user.companyName.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_rounded, size: 16, color: colors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          user.companyName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<AuthProvider>().logout();
                  Navigator.of(context).pushReplacementNamed('/');
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: ResponsiveContainer(
        maxWidth: 600,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Stack(
          children: [
            const Align(
              alignment: Alignment.topRight,
              child: ThemeToggleButton(compact: true),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.gold.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.gold.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icon, size: 40, color: colors.gold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_clock_rounded, size: 14, color: colors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Módulo en fase de integración',
                          style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
