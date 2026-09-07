import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/crop_offer.dart';

/// Bottom sheet simple para enviar una contraoferta (REQ-14, REQ-16).
///
/// Hoy solo llama a `MarketProvider.sendCounterOffer`, que está mockeado.
/// La lógica real de negociación en tiempo real (aceptar/rechazar, historial
/// de propuestas) queda como siguiente paso para el equipo — el modelo y el
/// repositorio ya están listos para that.
Future<double?> showCounterOfferSheet(
  BuildContext context, {
  required CropOffer offer,
}) {
  final controller =
      TextEditingController(text: offer.askPricePerMt.toStringAsFixed(0));

  return showModalBottomSheet<double>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(offer.variety, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Precio pedido: \$${offer.askPricePerMt.toStringAsFixed(0)}/MT',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Tu contraoferta (USD / MT)',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final value = double.tryParse(controller.text);
                  Navigator.of(ctx).pop(value);
                },
                child: const Text('Enviar contraoferta'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
