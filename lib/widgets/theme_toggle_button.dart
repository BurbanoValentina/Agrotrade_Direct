import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/theme_provider.dart';

/// Botón conmutador para alternar entre Modo Claro (pastel) y Modo Oscuro (cálido).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({
    super.key,
    this.compact = false,
    this.showLabel = false,
  });

  /// Si es true, muestra un botón circular/compacto ideal para AppBars o cabeceras estrechas.
  final bool compact;

  /// Si es true, muestra un texto indicador ("Claro" / "Oscuro") junto al ícono.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final colors = context.colors;

    final tooltip = isDark
        ? 'Cambiar a modo claro (pasteles)'
        : 'Cambiar a modo oscuro (cálido)';

    if (compact) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: themeProvider.toggleTheme,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
                size: 20,
                color: colors.gold,
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: themeProvider.toggleTheme,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey(isDark),
                    size: 18,
                    color: colors.gold,
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Text(
                    isDark ? 'Modo Claro' : 'Modo Oscuro',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
