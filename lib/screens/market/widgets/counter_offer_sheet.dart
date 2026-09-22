import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/crop_offer.dart';

final _currencyFmt = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

/// Bottom sheet refinado para enviar una contraoferta (REQ-14, REQ-16).
Future<double?> showCounterOfferSheet(
  BuildContext context, {
  required CropOffer offer,
}) {
  final controller = TextEditingController(text: offer.askPricePerMt.toStringAsFixed(0));
  final colors = context.colors;

  return showModalBottomSheet<double>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final modalColors = ctx.colors;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final currentVal = double.tryParse(controller.text) ?? offer.askPricePerMt;
          final diff = currentVal - offer.askPricePerMt;

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: modalColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with variety & origin
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: modalColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.handshake_rounded, color: modalColors.gold, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.variety,
                              style: TextStyle(
                                color: modalColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${offer.originRegion}, ${offer.originCountry} → ${offer.destinationCountry}',
                              style: TextStyle(color: modalColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Asking price summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: modalColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: modalColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRECIO SOLICITADO',
                              style: TextStyle(
                                color: modalColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_currencyFmt.format(offer.askPricePerMt)} / MT',
                              style: TextStyle(
                                color: modalColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'VOLUMEN DISPONIBLE',
                              style: TextStyle(
                                color: modalColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${offer.volumeMt} MT',
                              style: TextStyle(
                                color: modalColors.gold,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Counter-offer input
                  Text(
                    'Tu Propuesta (USD / MT)',
                    style: TextStyle(
                      color: modalColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    style: TextStyle(
                      color: modalColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    onChanged: (val) => setSheetState(() {}),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(
                        color: modalColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                      suffixText: 'USD / MT',
                      suffixStyle: TextStyle(
                        color: modalColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick modifier pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [-200, -100, -50, 50, 100].map((delta) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          label: Text(delta > 0 ? '+\$$delta' : '-\$${delta.abs()}'),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: modalColors.textPrimary,
                          ),
                          backgroundColor: modalColors.surfaceAlt,
                          side: BorderSide(color: modalColors.border),
                          onPressed: () {
                            final curr = double.tryParse(controller.text) ?? offer.askPricePerMt;
                            final next = (curr + delta).clamp(100.0, 50000.0);
                            controller.text = next.toStringAsFixed(0);
                            setSheetState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Delta info
                  if (diff != 0)
                    Center(
                      child: Text(
                        'Diferencia frente al precio pedido: ${diff > 0 ? '+\$' : '-\$'}${diff.abs().toStringAsFixed(0)} USD/MT',
                        style: TextStyle(
                          color: diff < 0 ? modalColors.priceDown : modalColors.priceUp,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: modalColors.gold,
                        foregroundColor: modalColors.isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text(
                        'Enviar contraoferta',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      onPressed: () {
                        final value = double.tryParse(controller.text);
                        Navigator.of(ctx).pop(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
