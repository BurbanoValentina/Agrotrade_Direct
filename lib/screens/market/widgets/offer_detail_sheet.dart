import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/crop_offer.dart';

final _currencyFmt =
    NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy');

/// REQ-13: Hoja modal con el detalle completo de una oferta de exportación.
Future<void> showOfferDetailSheet(BuildContext context,
    {required CropOffer offer, required VoidCallback onMakeOffer}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _OfferDetailContent(
      offer: offer,
      onMakeOffer: onMakeOffer,
    ),
  );
}

class _OfferDetailContent extends StatelessWidget {
  const _OfferDetailContent({
    required this.offer,
    required this.onMakeOffer,
  });

  final CropOffer offer;
  final VoidCallback onMakeOffer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con ícono de cultivo y botón de cierre
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surfaceAlt,
                  child: Icon(
                    offer.cropType == CropType.cafe ? Icons.coffee : Icons.eco,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.variety,
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text(
                        'Origen: ${offer.originRegion}, ${offer.originCountry}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 32, color: AppColors.border),

            // Métricas financieras y logísticas
            _DetailTile(
              icon: Icons.attach_money,
              title: 'Precio Pedido (Ask Price)',
              value: '${_currencyFmt.format(offer.askPricePerMt)} / MT',
            ),
            _DetailTile(
              icon: Icons.inventory_2_outlined,
              title: 'Volumen Disponible',
              value: '${offer.volumeMt} MT (Ton. Métricas)',
            ),
            _DetailTile(
              icon: Icons.monetization_on_outlined,
              title: 'Valor Est. Total del Lote',
              value: _currencyFmt.format(offer.estimatedTotalUsd),
            ),
            _DetailTile(
              icon: Icons.flight_land,
              title: 'País de Destino Objetivo',
              value: offer.destinationCountry,
            ),
            _DetailTile(
              icon: Icons.calendar_today_outlined,
              title: 'Fecha de Publicación',
              value: _dateFmt.format(offer.postedAt),
            ),
            const SizedBox(height: 16),

            // Certificaciones disponibles
            const Text(
              'Certificaciones de Calidad',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: offer.certifications
                  .map((c) => Chip(
                        label: Text(c),
                        backgroundColor: AppColors.surfaceAlt,
                        side: const BorderSide(color: AppColors.gold),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Perfil e información del vendedor
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.gold,
                    child: Text(
                      offer.sellerName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offer.sellerName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          'Rating: ${offer.sellerRating} ⭐ · ${offer.sellerTrades} transacciones',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botón de acción para negociación
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onMakeOffer();
                },
                child: const Text('Iniciar Negociación / Contraofertar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.gold),
          const SizedBox(width: 12),
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
