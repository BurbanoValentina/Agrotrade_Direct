import 'package:flutter/material.dart';

/// Contenedor de ancho máximo responsivo con márgenes fluidos.
/// En pantallas anchas (Web/Desktop) evita la distorsión horizontal centrando el contenido.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;

    final defaultPadding = EdgeInsets.symmetric(
      horizontal: isCompact ? 16.0 : (screenWidth < 1000 ? 24.0 : 32.0),
      vertical: isCompact ? 12.0 : 20.0,
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? defaultPadding,
          child: child,
        ),
      ),
    );
  }
}
