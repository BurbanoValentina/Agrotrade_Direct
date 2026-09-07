import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Chip de precio de mercado (ej. "Arabica ICE $4,210 +1.2%") como en el
/// ticker superior del mockup de "Live Market".
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.changePercent,
  });

  final String label;
  final String value;
  final double changePercent;

  @override
  Widget build(BuildContext context) {
    final isUp = changePercent >= 0;
    final changeColor = isUp ? AppColors.priceUp : AppColors.priceDown;
    final sign = isUp ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          Text('$sign${changePercent.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 10, color: changeColor)),
        ],
      ),
    );
  }
}
