import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';

/// El selector "Exporter · Colombia / Importer · EU" que aparece en la
/// parte superior del Mercado y permite cambiar dinámicamente el rol en vivo.
class RoleToggle extends StatelessWidget {
  const RoleToggle({super.key, required this.selected});

  final UserRole selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _segment(context, UserRole.exportador, '🇨🇴 Exportador · Colombia', Icons.agriculture_rounded)),
          Expanded(child: _segment(context, UserRole.importador, '🇪🇺 Importador · UE', Icons.public_rounded)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, UserRole role, String label, IconData icon) {
    final colors = context.colors;
    final isSelected = role == selected;

    return InkWell(
      onTap: () {
        context.read<AuthProvider>().setRole(role);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.gold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? (colors.isDark ? Colors.black : Colors.white)
                  : colors.textSecondary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (colors.isDark ? Colors.black : Colors.white)
                      : colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
