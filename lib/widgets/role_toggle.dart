import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/user_role.dart';

/// El selector "Exporter · Colombia / Importer · EU" que aparece en la
/// parte superior de todas las pantallas del mockup.
///
/// Hoy es puramente visual/informativo (refleja el rol del usuario logeado).
/// Se deja como widget aparte para que sea fácil de reusar en Deals, Mapa y
/// Perfil cuando el resto del equipo las construya.
class RoleToggle extends StatelessWidget {
  const RoleToggle({super.key, required this.selected});

  final UserRole selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(context, UserRole.exportador)),
          Expanded(child: _segment(context, UserRole.importador)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, UserRole role) {
    final colors = context.colors;
    final isSelected = role == selected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? colors.gold : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          role.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? (colors.isDark ? Colors.black : Colors.white)
                : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
