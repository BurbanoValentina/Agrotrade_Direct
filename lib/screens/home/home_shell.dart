import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../map/trade_map_screen.dart';
import '../market/market_screen.dart';

/// Contenedor principal con la barra de navegación inferior (REQ-18 en la pestaña Trade Map).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  // Lista de vistas principales conectadas
  static const _screens = [
    MarketScreen(),
    _PlaceholderScreen(
      icon: Icons.assignment_outlined,
      title: 'My Deals',
      description:
          'Aquí irá el seguimiento de negociaciones activas y el historial (REQ-14 a REQ-19).',
    ),
    TradeMapScreen(), // REQ-18: Reemplazado placeholder por la pantalla completa del mapa
    _PlaceholderScreen(
      icon: Icons.person_outline,
      title: 'Profile',
      description:
          'Aquí irá el perfil, calificaciones y reportes (REQ-05, REQ-21, REQ-22).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'My Deals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Trade Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Pantalla temporal para módulos en desarrollo asignados a otros integrantes
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Próximamente',
                style: TextStyle(color: AppColors.gold, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
